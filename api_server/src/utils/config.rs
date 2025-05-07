use once_cell::sync::OnceCell;
use serde::Deserialize;
use anyhow::{Context, Result};
use std::env;

static CONFIG: OnceCell<AppConfig> = OnceCell::new();

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct AppConfig {
    pub server: ServerConfig,
    pub google_api: GoogleApiConfig,
    pub rate_limits: RateLimitConfig,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub cors_allowed_origins: Vec<String>,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct GoogleApiConfig {
    pub client_id: String,
    pub client_secret: String,
    pub refresh_token: String,
    pub api_url: String,
    pub token_url: String,
    pub scope: String,
    pub token_cache_duration: u64,
}

#[derive(Debug, Clone, Deserialize)]
#[allow(dead_code)]
pub struct RateLimitConfig {
    pub single_credential_rpm: u32,
    pub batch_credential_rpm: u32,
    pub max_batch_size: usize,
}

pub fn init() -> Result<()> {
    dotenvy::dotenv().ok();
    
    let config = AppConfig {
        server: ServerConfig {
            host: env::var("SERVER_HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            port: env::var("SERVER_PORT")
                .unwrap_or_else(|_| "3000".to_string())
                .parse()
                .context("Failed to parse SERVER_PORT")?,
            cors_allowed_origins: env::var("CORS_ALLOWED_ORIGINS")
                .unwrap_or_else(|_| "*".to_string())
                .split(',')
                .map(|s| s.trim().to_string())
                .collect(),
        },
        google_api: GoogleApiConfig {
            client_id: env::var("GOOGLE_CLIENT_ID")
                .context("GOOGLE_CLIENT_ID environment variable not set")?,
            client_secret: env::var("GOOGLE_CLIENT_SECRET")
                .context("GOOGLE_CLIENT_SECRET environment variable not set")?,
            refresh_token: env::var("GOOGLE_REFRESH_TOKEN")
                .context("GOOGLE_REFRESH_TOKEN environment variable not set")?,
            api_url: env::var("GOOGLE_API_URL")
                .unwrap_or_else(|_| "https://passwordsleakcheck-pa.googleapis.com/v1/leaks:lookupSingle".to_string()),
            token_url: env::var("GOOGLE_TOKEN_URL")
                .unwrap_or_else(|_| "https://www.googleapis.com/oauth2/v4/token".to_string()),
            scope: env::var("GOOGLE_API_SCOPE")
                .unwrap_or_else(|_| "https://www.googleapis.com/auth/identity.passwords.leak.check".to_string()),
            token_cache_duration: env::var("TOKEN_CACHE_DURATION")
                .unwrap_or_else(|_| "3000".to_string()) // 50 minutes
                .parse()
                .context("Failed to parse TOKEN_CACHE_DURATION")?,
        },
        rate_limits: RateLimitConfig {
            single_credential_rpm: env::var("RATE_LIMIT_SINGLE_RPM")
                .unwrap_or_else(|_| "60".to_string()) // 60 requests per minute
                .parse()
                .context("Failed to parse RATE_LIMIT_SINGLE_RPM")?,
            batch_credential_rpm: env::var("RATE_LIMIT_BATCH_RPM")
                .unwrap_or_else(|_| "10".to_string()) // 10 requests per minute
                .parse()
                .context("Failed to parse RATE_LIMIT_BATCH_RPM")?,
            max_batch_size: env::var("MAX_BATCH_SIZE")
                .unwrap_or_else(|_| "10000".to_string()) // max 10k credentials per batch
                .parse()
                .context("Failed to parse MAX_BATCH_SIZE")?,
        },
    };
    
    CONFIG.set(config).expect("Failed to set global config");
    
    Ok(())
}

pub fn get() -> &'static AppConfig {
    CONFIG.get().expect("Config not initialized. Call init() first")
}

/// example .env file
#[allow(dead_code)]
const ENV_EXAMPLE: &str = r#"
# Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=3000
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://example.com

# Google API Configuration
GOOGLE_CLIENT_ID=your-client-id
GOOGLE_CLIENT_SECRET=your-client-secret
GOOGLE_REFRESH_TOKEN=your-refresh-token
GOOGLE_API_URL=https://passwordsleakcheck-pa.googleapis.com/v1/leaks:lookupSingle
GOOGLE_TOKEN_URL=https://www.googleapis.com/oauth2/v4/token
GOOGLE_API_SCOPE=https://www.googleapis.com/auth/identity.passwords.leak.check
TOKEN_CACHE_DURATION=3000

# Rate Limiting
RATE_LIMIT_SINGLE_RPM=60
RATE_LIMIT_BATCH_RPM=10
MAX_BATCH_SIZE=10000
"#;