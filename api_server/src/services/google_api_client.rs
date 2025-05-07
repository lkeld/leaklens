use anyhow::{anyhow, Context, Result};
use bytes::Bytes;
use reqwest::Client;
use tracing::{debug, error, info, trace};

use crate::crypto::check_google_api;
use crate::crypto::ecc_cipher::ECCommutativeCipher;
use crate::crypto::hashing::{username_hash_prefix, extract_username_from_email};
use crate::proto::{LookupSingleLeakRequest, LookupSingleLeakResponse};
use crate::services::token_manager::TokenManager;
use crate::utils::config;

#[derive(Debug, Clone)]
pub struct GoogleApiClient {
    client: Client,
    token_manager: TokenManager,
    debug_mode: bool,
}

impl GoogleApiClient {
    pub fn new(token_manager: TokenManager) -> Self {
        let debug_mode = std::env::var("DEBUG_GOOGLE_API")
            .unwrap_or_else(|_| "false".to_string())
            .to_lowercase() == "true";
            
        if debug_mode {
            info!("Google API client running in DEBUG mode");
        }
            
        GoogleApiClient {
            client: Client::new(),
            token_manager,
            debug_mode,
        }
    }


    pub async fn check_credential(
        &self,
        username: &str,
        encrypted_lookup_hash: &[u8],
        cipher: &ECCommutativeCipher,
    ) -> Result<bool> {
        let username_to_check = extract_username_from_email(username);
        debug!("Extracted username '{}' from '{}'", username_to_check, username);

        let prefix = username_hash_prefix(&username_to_check);
        debug!("Username hash prefix calculated: {}", hex::encode(&prefix));

        let mut request = LookupSingleLeakRequest::default();
        request.username_hash_prefix = prefix;
        request.username_hash_prefix_length = 26; // Fixed value based on the protocol
        request.encrypted_lookup_hash = encrypted_lookup_hash.to_vec();

        let request_bytes = prost::Message::encode_to_vec(&request);
        trace!("Serialized request size: {} bytes", request_bytes.len());

        let token = self.token_manager.get_token().await?;
        debug!("Obtained valid OAuth token");

        let config = config::get();
        debug!("Sending request to Google API: {}", config.google_api.api_url);
        let response = self
            .client
            .post(&config.google_api.api_url)
            .header("authorization", format!("Bearer {}", token))
            .header("content-type", "application/x-protobuf")
            .header("user-agent", "Mozilla/5.0 (Rust Leak Checker)")
            .body(request_bytes)
            .send()
            .await
            .map_err(|e| anyhow!("API request failed: {}", e))?;

        let status = response.status();
        let content_type = response.headers().get("content-type").map(|v| v.to_str().unwrap_or("")).unwrap_or("").to_string();
        let response_bytes = response.bytes().await?;
        debug!("Received response: {} bytes, status: {}, content-type: {}", response_bytes.len(), status, content_type);
        if !status.is_success() {
            let body_text = String::from_utf8_lossy(&response_bytes);
            error!("API request failed: {} - {}", status, body_text);
            return Err(anyhow!("API request failed: {} - {}", status, body_text));
        }

        let response = match self.parse_response(&response_bytes) {
            Ok(r) => r,
            Err(e) => {
                let body_text = String::from_utf8_lossy(&response_bytes);
                error!("Failed to decode API protobuf response: {}. Raw body: {}", e, body_text);
                return Err(anyhow!("Failed to decode API response: {}. Raw body: {}", e, body_text));
            }
        };

        let decrypted_hash = cipher
            .decrypt(&response.reencrypted_lookup_hash)
            .context("Failed to decrypt reencrypted lookup hash")?;
        debug!("Successfully decrypted re-encrypted hash");

        let is_leaked = if self.debug_mode {
            check_google_api::debug_response_check(&response, &decrypted_hash)?
        } else {
            check_google_api::check_credential_leaked(&response, &decrypted_hash)?
        };

        info!(
            "Credential check complete - is leaked: {} (with {} potential matches)",
            is_leaked,
            response.encrypted_leak_match_prefix.len()
        );

        Ok(is_leaked)
    }


    fn parse_response(&self, bytes: &Bytes) -> Result<LookupSingleLeakResponse> {
        prost::Message::decode(&bytes[..])
            .map_err(|e| anyhow!("Failed to decode API response: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crypto::hashing::scrypt_hash_username_and_password;

    #[tokio::test]
    #[ignore]
    async fn test_check_credential_integration() -> Result<()> {
        crate::utils::config::init()?;

        let token_manager = TokenManager::new();

        let api_client = GoogleApiClient::new(token_manager);

        let cipher = ECCommutativeCipher::new(None);

        let username = "test@example.com";
        let password = "password123";

        let lookup_hash = scrypt_hash_username_and_password(username, password)?;
        let encrypted_lookup_hash = cipher.encrypt(&lookup_hash)?;

        let is_leaked = api_client
            .check_credential(username, &encrypted_lookup_hash, &cipher)
            .await?;

        assert!(is_leaked, "Test credential should be reported as leaked");

        Ok(())
    }
}