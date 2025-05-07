use anyhow::{anyhow, Result};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::Mutex;
use tracing::{debug, info, warn, error};

use crate::utils::config;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct TokenResponse {
    access_token: String,
    expires_in: u64,
    token_type: String,
}

#[derive(Debug, Clone)]
pub struct TokenManager {
    client: Client,
    token_cache: Arc<Mutex<Option<(String, Instant)>>>,
}

impl TokenManager {
    pub fn new() -> Self {
        TokenManager {
            client: Client::new(),
            token_cache: Arc::new(Mutex::new(None)),
        }
    }

    pub async fn get_token(&self) -> Result<String> {
        {
            let cache = self.token_cache.lock().await;
            if let Some((token, timestamp)) = &*cache {
                let config = config::get();
                if timestamp.elapsed() < Duration::from_secs(config.google_api.token_cache_duration) {
                    debug!("Using cached OAuth token");
                    return Ok(token.clone());
                }
            }
        }

        debug!("Fetching new OAuth token");
        
        let config = config::get();
        
        let client_id = config.google_api.client_id.clone();
        let client_secret = config.google_api.client_secret.clone();
        let refresh_token = config.google_api.refresh_token.clone();
        let scope = config.google_api.scope.clone();
        
        let token_url = config.google_api.token_url.clone();
        
        let form_data = [
            ("client_id", client_id),
            ("client_secret", client_secret),
            ("grant_type", "refresh_token".to_string()),
            ("refresh_token", refresh_token),
            ("scope", scope),
        ];
        
        let response = self.client
            .post(token_url)
            .form(&form_data)
            .header("user-agent", "Mozilla/5.0 (Rust Leak Checker)")
            .send()
            .await
            .map_err(|e| anyhow!("Failed to send token request: {}", e))?;

        let response_status = response.status();

        let response_body_bytes = match response.bytes().await {
            Ok(bytes) => bytes,
            Err(e) => {
                error!("Failed to read token response body (status: {}). Error: {}", response_status, e);
                return Err(anyhow!("Failed to read token response body (status: {}). Error: {}", response_status, e));
            }
        };

        if !response_status.is_success() {
            let body_text = String::from_utf8_lossy(&response_body_bytes);
            error!("Token request failed with status: {}. Response body: {}", response_status, body_text);
            return Err(anyhow!("Token request failed with status: {}. Response body snippet: {}", response_status, body_text.chars().take(500).collect::<String>()));
        }
        
        match serde_json::from_slice::<TokenResponse>(&response_body_bytes) {
            Ok(token_response_val) => {
                if token_response_val.access_token.is_empty() {
                    error!("Received empty access token from Google.");
                    return Err(anyhow!("Received empty access token from Google"));
                }

                {
                    let mut cache = self.token_cache.lock().await;
                    *cache = Some((token_response_val.access_token.clone(), Instant::now()));
                }

                info!("Successfully fetched new OAuth token");
                Ok(token_response_val.access_token)
            }
            Err(e) => {
                let body_text = String::from_utf8_lossy(&response_body_bytes);
                error!(
                    "Failed to parse TokenResponse JSON from Google (Status: {}). Body: '{}', Error: {}",
                    response_status, body_text, e
                );
                Err(anyhow!(
                    "Failed to parse token data from Google: {}. Response body snippet: '{}'", e, body_text.chars().take(500).collect::<String>()
                ))
            }
        }
    }

    pub async fn check_connection(&self) -> Result<bool> {
        match self.get_token().await {
            Ok(_) => Ok(true),
            Err(e) => {
                warn!("Failed to obtain token during connection check: {}", e);
                Ok(false)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_token_manager_cache() {
        let manager = TokenManager::new();
        
        {
            let mut cache = manager.token_cache.lock().await;
            *cache = Some(("test_token".to_string(), Instant::now()));
        }
        
        let token = manager.get_token().await;
        assert!(token.is_ok());
        assert_eq!(token.unwrap(), "test_token");
    }
    
    #[tokio::test]
    #[ignore] 
    async fn test_token_acquisition() -> Result<()> {
        println!("Initializing config...");
        crate::utils::config::init()?;
        println!("Configuration initialized");
        
        println!("Creating token manager...");
        let token_manager = TokenManager::new();
        println!("Token manager created");
        
        println!("Attempting to get a token from Google API...");
        match token_manager.get_token().await {
            Ok(token) => {
                println!("SUCCESS! Token received: {}...", &token[..10]);
                Ok(())
            },
            Err(e) => {
                println!("FAILURE! Error getting token: {}", e);
                Err(e)
            }
        }
    }
}