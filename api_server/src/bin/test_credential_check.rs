use leaklens_api::services::leak_check_service::LeakCheckService;
use leaklens_api::services::token_manager::TokenManager;
use leaklens_api::utils::config;
use std::error::Error;

#[tokio::main]
async fn main() -> Result<(), Box<dyn Error + Send + Sync>> {
    // Initialize configuration
    config::init()?;
    
    let args: Vec<String> = std::env::args().collect();
    
    if args.len() != 3 {
        eprintln!("Usage: {} <username> <password>", args[0]);
        std::process::exit(1);
    }
    
    let username = &args[1];
    let password = &args[2];
    
    // Create a token manager
    let token_manager = TokenManager::new();
    let leak_check_service = LeakCheckService::new(token_manager);
    
    println!("Checking if credential is leaked: {}:{}", username, "*".repeat(password.len()));
    
    match leak_check_service.check_single_credential(username, password).await {
        Ok(is_leaked) => {
            if is_leaked {
                println!("❌ CREDENTIAL FOUND IN BREACH DATABASE");
            } else {
                println!("✅ Credential not found in breach database");
            }
            Ok(())
        },
        Err(e) => {
            eprintln!("Error checking credential: {}", e);
            Err(e.into())
        }
    }
} 