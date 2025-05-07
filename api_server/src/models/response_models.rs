use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct SingleCheckResponse {
    pub username: String,
    pub is_leaked: bool,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct BatchCheckResponse {
    pub job_id: String,
    pub message: String,
}

#[derive(Debug, Serialize)]
pub struct BatchCheckSummary {
    pub total_processed: usize,
    pub total_leaked: usize,
    pub total_not_leaked: usize,
    pub total_errors: usize,
    pub completed: bool,
    pub progress_percentage: u8, 
}

#[derive(Debug, Serialize)]
pub struct BatchCheckResultsResponse {
    pub summary: BatchCheckSummary,
    pub results: Vec<super::request_models::CredentialCheckResult>,
}

#[derive(Debug, Serialize)]
pub struct ApiStatusResponse {
    pub status: String,
    pub timestamp: String,
    pub google_api_status: String,
}

#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub code: Option<String>,
}