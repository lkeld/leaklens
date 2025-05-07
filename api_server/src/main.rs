mod api;
mod crypto;
mod models;
mod proto;
mod services;
mod utils;

use std::net::SocketAddr;
use std::str::FromStr;

use tokio::signal;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use crate::models::request_models::create_job_storage;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .finish();
    tracing::subscriber::set_global_default(subscriber)?;
    
    info!("Initializing configuration...");
    utils::config::init()?;
    let config = utils::config::get();
    
    let job_storage = create_job_storage();
    
    let app = api::create_router(job_storage);
    
    let addr = SocketAddr::from_str(&format!("{}:{}", config.server.host, config.server.port))?;
    
    info!("LeakLens API starting on http://{}", addr);
    
    let server = axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .with_graceful_shutdown(shutdown_signal());
        
    server.await?;
    
    info!("Server shutting down");
    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("Failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    info!("Shutdown signal received");
}

#[allow(dead_code)]
fn demo_crypto_operations() -> Result<(), Box<dyn std::error::Error>> {
    println!("LeakLens Cryptography Demo");
    println!("==========================\n");
    
    let username = "user@example.com";
    let password = "password123";
    
    println!("Username: {}", username);
    println!("Password: {}\n", password);
    
    let prefix = crypto::hashing::username_hash_prefix(username);
    println!("Username hash prefix: {:?}", hex::encode(&prefix));
    println!("  This is sent to Google to retrieve potential matches\n");
    
    let lookup_hash = crypto::hashing::scrypt_hash_username_and_password(username, password)?;
    println!("Username+password hash: {}", hex::encode(&lookup_hash[0..10]));
    println!("  This is the sensitive data we need to check securely\n");
    
    let our_cipher = crypto::ecc_cipher::ECCommutativeCipher::new(None);
    println!("Client private key: {}", hex::encode(&our_cipher.get_private_key_bytes()[0..5]));
    println!("  (abbreviated for display)\n");
    
    let encrypted_lookup_hash = our_cipher.encrypt(&lookup_hash)?;
    println!("Encrypted lookup hash: {}", hex::encode(&encrypted_lookup_hash[0..10]));
    println!("  This can be sent to Google without revealing the actual hash\n");
    
    let google_cipher = crypto::ecc_cipher::ECCommutativeCipher::new(None);
    println!("Google private key: {}", hex::encode(&google_cipher.get_private_key_bytes()[0..5]));
    println!("  (abbreviated for display)\n");
    
    let reencrypted_lookup_hash = google_cipher.encrypt(&encrypted_lookup_hash)?;
    println!("Re-encrypted lookup hash: {}", hex::encode(&reencrypted_lookup_hash[0..10]));
    println!("  This is returned to the client\n");
    
    let decrypted_hash = our_cipher.decrypt(&reencrypted_lookup_hash)?;
    println!("Client decrypts to get: {}", hex::encode(&decrypted_hash[0..10]));
    println!("  Now we have the hash encrypted only with Google's key\n");
    
    let _fully_decrypted = google_cipher.decrypt(&decrypted_hash)?;
    
    println!("Verification completed successfully");
    println!("  The commutative property allows secure credential checking\n");
    
    println!("Protocol summary:");
    println!("1. Client generates username hash prefix - sent to Google");
    println!("2. Client encrypts the lookup hash with their key - sent to Google");
    println!("3. Google re-encrypts the hash with their key - sent back to client");
    println!("4. Client decrypts using their key");
    println!("5. Client compares the resulting hash with the breach database");
    println!("   (In the full protocol, Google returns prefix matches for comparison)");
    
    Ok(())
}