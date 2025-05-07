use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use thiserror::Error;

use crate::models::response_models::ErrorResponse;

#[derive(Debug, Error)]
#[allow(dead_code)]
pub enum ApiError {
    #[error("Authentication error: {0}")]
    Authentication(String),

    #[error("Authorization error: {0}")]
    Authorization(String),

    #[error("Invalid input: {0}")]
    InvalidInput(String),

    #[error("Resource not found: {0}")]
    NotFound(String),

    #[error("Rate limit exceeded: {0}")]
    RateLimited(String),

    #[error("External service error: {0}")]
    ExternalService(String),

    #[error("Internal server error: {0}")]
    Internal(String),
}

impl ApiError {
    pub fn error_code(&self) -> &'static str {
        match self {
            ApiError::Authentication(_) => "AUTHENTICATION_ERROR",
            ApiError::Authorization(_) => "AUTHORIZATION_ERROR",
            ApiError::InvalidInput(_) => "INVALID_INPUT",
            ApiError::NotFound(_) => "NOT_FOUND",
            ApiError::RateLimited(_) => "RATE_LIMITED",
            ApiError::ExternalService(_) => "EXTERNAL_SERVICE_ERROR",
            ApiError::Internal(_) => "INTERNAL_SERVER_ERROR",
        }
    }

    pub fn status_code(&self) -> StatusCode {
        match self {
            ApiError::Authentication(_) => StatusCode::UNAUTHORIZED,
            ApiError::Authorization(_) => StatusCode::FORBIDDEN,
            ApiError::InvalidInput(_) => StatusCode::BAD_REQUEST,
            ApiError::NotFound(_) => StatusCode::NOT_FOUND,
            ApiError::RateLimited(_) => StatusCode::TOO_MANY_REQUESTS,
            ApiError::ExternalService(_) => StatusCode::BAD_GATEWAY,
            ApiError::Internal(_) => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let status = self.status_code();
        let error_response = ErrorResponse {
            error: self.to_string(),
            code: Some(self.error_code().to_string()),
        };

        (status, Json(error_response)).into_response()
    }
}

impl From<anyhow::Error> for ApiError {
    fn from(err: anyhow::Error) -> Self {
        ApiError::Internal(err.to_string())
    }
}