//! API routes for the LeakLens API service

pub mod check_routes;
pub mod docs;
pub mod status_routes;
pub mod health;

use axum::{
    routing::{get, post},
    Router,
};
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};

use crate::services::leak_check_service::LeakCheckService;
use crate::services::token_manager::TokenManager;
use crate::models::request_models::JobStorage;
use crate::utils::config;

pub fn create_router(job_storage: JobStorage) -> Router {
    let token_manager = TokenManager::new();
    let leak_check_service = LeakCheckService::new(token_manager.clone());


    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    let app_state = AppState {
        leak_check_service,
        token_manager,
        job_storage,
    };

    Router::<AppState>::new()
        .route("/health", get(health::health_check))
        .route("/api/v1/status", get(status_routes::get_api_status))
        .route("/api/v1/check/single", post(check_routes::check_single))
        .route("/api/v1/check/batch", post(check_routes::check_batch))
        .route("/api/v1/check/batch/:job_id/status", get(check_routes::get_batch_status))
        .merge(docs::docs_routes())
        .with_state(app_state)
        .layer(cors)
        .layer(TraceLayer::new_for_http())
}

#[derive(Clone)]
pub struct AppState {
    pub leak_check_service: LeakCheckService,
    pub token_manager: TokenManager,
    pub job_storage: JobStorage,
}