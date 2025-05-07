//! Health check route for monitoring and deployment platforms

use axum::{http::StatusCode, response::IntoResponse};
use tracing::debug;

/// Simple health check endpoint that returns a 200 OK status
/// Used by Render.com and other deployment platforms to verify the service is running
pub async fn health_check() -> impl IntoResponse {
    debug!("Health check endpoint called");
    StatusCode::OK
} 