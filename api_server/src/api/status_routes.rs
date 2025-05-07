
use axum::{extract::State, Json};
use chrono::Utc;
use tracing::{info, error};

use crate::models::response_models::ApiStatusResponse;
use crate::utils::error::ApiError;


pub async fn get_api_status(State(state): State<crate::api::AppState>) -> Result<Json<ApiStatusResponse>, ApiError> {
    info!("Status endpoint called");
    
    let google_api_status = match state.token_manager.check_connection().await {
        Ok(true) => "connected".to_string(),
        Ok(false) => "disconnected".to_string(),
        Err(e) => {
            error!("Error checking Google API connection: {}", e);
            "error".to_string()
        }
    };
    
    let timestamp = Utc::now().to_rfc3339();
    
    info!("API status: healthy, Google API: {}", google_api_status);
    
    Ok(Json(ApiStatusResponse {
        status: "healthy".to_string(),
        timestamp,
        google_api_status,
    }))
}