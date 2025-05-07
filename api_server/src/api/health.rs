use axum::{http::StatusCode, response::IntoResponse};
use tracing::debug;

pub async fn health_check() -> impl IntoResponse {
    debug!("Health check endpoint called");
    StatusCode::OK
} 