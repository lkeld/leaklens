use serde::{Deserialize, Serialize};
use std::{collections::HashMap, sync::Arc};
use tokio::sync::RwLock;
use std::time::Instant;

#[derive(Debug, Deserialize)]
pub struct SingleCheckRequest {
    pub username: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct BatchCheckMetadata {
    pub input_type: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct CredentialCheckResult {
    pub credential: String,      
    pub is_leaked: Option<bool>, 
    pub status: String,          
    pub message: Option<String>, 
}

#[derive(Debug)]
#[allow(dead_code)]  
pub struct BatchProcessingJob {
    pub id: String,
    pub total: usize,
    pub processed: usize,
    pub results: Vec<CredentialCheckResult>,
    pub completed: bool,
    pub error: Option<String>,
    pub last_heartbeat: Instant,  
    pub is_abandoned: bool,      
}

pub type JobStorage = Arc<RwLock<HashMap<String, BatchProcessingJob>>>;

pub fn create_job_storage() -> JobStorage {
    Arc::new(RwLock::new(HashMap::new()))
}