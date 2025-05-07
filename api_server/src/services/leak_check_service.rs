use anyhow::{Context, Result};
use std::sync::Arc;
use tokio::sync::Mutex;
use tracing::{debug, info, error};
use hex;
use futures::future;

use crate::crypto::ecc_cipher::ECCommutativeCipher;
use crate::crypto::hashing::scrypt_hash_username_and_password;
use crate::services::google_api_client::GoogleApiClient;
use crate::services::token_manager::TokenManager;

#[derive(Clone)]
pub struct LeakCheckService {
    #[cfg_attr(test, allow(dead_code))]
    pub(crate) cipher: Arc<Mutex<ECCommutativeCipher>>,
    #[cfg_attr(test, allow(dead_code))]
    pub(crate) api_client: GoogleApiClient,
}

impl LeakCheckService {
    pub fn new(token_manager: TokenManager) -> Self {
        let fixed_key = [1u8; 32];
        let cipher = ECCommutativeCipher::new(Some(&fixed_key));
        let api_client = GoogleApiClient::new(token_manager);
        
        LeakCheckService {
            cipher: Arc::new(Mutex::new(cipher)),
            api_client,
        }
    }
    
    pub async fn check_single_credential(&self, username: &str, password: &str) -> Result<bool> {
        debug!("Checking credential for {}", username);
        
        let lookup_hash = scrypt_hash_username_and_password(username, password)
            .context("Failed to hash username and password")?;
        debug!("Scrypt hash: {}", hex::encode(&lookup_hash));
        
        let lookup_hash = match lookup_hash.iter().position(|&b| b == 0) {
            Some(pos) => &lookup_hash[..pos],
            None => &lookup_hash[..],
        };
        debug!("Lookup hash after null strip: {}", hex::encode(lookup_hash));
        
        let encrypted_lookup_hash = {
            let cipher = self.cipher.lock().await;
            cipher.encrypt(lookup_hash)
                .context("Failed to encrypt lookup hash")?
        };
        debug!("Encrypted lookup hash: {}", hex::encode(&encrypted_lookup_hash));
        
        let cipher_clone = {
            let cipher = self.cipher.lock().await;
            cipher.clone()
        };
        
        info!("Sending credential check request to Google API for {}", username);
        self.api_client.check_credential(username, &encrypted_lookup_hash, &cipher_clone).await
    }
    
    pub async fn check_batch_credentials(&self, credentials: Vec<(String, String)>)
        -> Result<Vec<(String, String, bool, Option<String>)>> {
        
        let mut results = Vec::with_capacity(credentials.len());
        
        let concurrency_limit = 5;
        
        let chunks: Vec<_> = credentials.chunks(concurrency_limit).collect();
        
        for chunk in chunks {
            let futures = chunk.iter().map(|(username, password)| {
                let username = username.clone();
                let password = password.clone();
                let service = self.clone();
                
                async move {
                    match service.check_single_credential(&username, &password).await {
                        Ok(is_leaked) => {
                            (
                                username,
                                "••••••••".to_string(),
                                is_leaked,
                                None
                            )
                        },
                        Err(e) => {
                            error!("Error checking credential: {}", e);
                            (
                                username,
                                "••••••••".to_string(),
                                false,
                                Some(format!("Error: {}", e))
                            )
                        }
                    }
                }
            });
            
            let chunk_results = future::join_all(futures).await;
            results.extend(chunk_results);
            
            tokio::time::sleep(tokio::time::Duration::from_millis(50)).await;
        }
        
        Ok(results)
    }
}