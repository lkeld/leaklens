use axum::{
    extract::{Multipart, Path, State},
    Json,
};
use std::io::{BufReader, Cursor, BufRead};
use tokio::spawn;
use uuid::Uuid;
use std::time::Instant;

use crate::api::AppState;
use crate::models::{
    request_models::{BatchCheckMetadata, BatchProcessingJob, CredentialCheckResult, SingleCheckRequest},
    response_models::{BatchCheckResponse, BatchCheckResultsResponse, BatchCheckSummary, SingleCheckResponse},
};
use crate::utils::{
    error::ApiError,
    rate_limiter::get_rate_limiter,
};


pub async fn check_single(
    State(state): State<AppState>, 
    Json(request): Json<SingleCheckRequest>
) -> Result<Json<SingleCheckResponse>, ApiError> {
    if !get_rate_limiter().check_single_credential_limit().await {
        return Err(ApiError::RateLimited("Rate limit exceeded for single credential checks".to_string()));
    }

    if request.username.trim().is_empty() || request.password.trim().is_empty() {
        return Err(ApiError::InvalidInput("Username and password are required".to_string()));
    }

    let is_leaked = state.leak_check_service
        .check_single_credential(&request.username, &request.password)
        .await
        .map_err(|e| ApiError::Internal(format!("Credential check failed: {}", e)))?;

    let message = if is_leaked {
        "Credential found in a known data breach"
    } else {
        "Credential not found in our breach database"
    };

    Ok(Json(SingleCheckResponse {
        username: request.username,
        is_leaked,
        message: message.to_string(),
    }))
}


pub async fn check_batch(
    State(state): State<AppState>,
    mut multipart: Multipart,
) -> Result<Json<BatchCheckResponse>, ApiError> {
    if !get_rate_limiter().check_batch_credentials_limit().await {
        return Err(ApiError::RateLimited("Rate limit exceeded for batch credential checks".to_string()));
    }

    let mut file_bytes = None;
    let mut metadata = BatchCheckMetadata { input_type: None };

    while let Some(field) = multipart.next_field().await
        .map_err(|e| ApiError::InvalidInput(format!("Error reading multipart form: {}", e)))? {
        
        let name = field.name().unwrap_or("").to_string();

        if name == "file" {
            file_bytes = Some(field.bytes().await
                .map_err(|e| ApiError::InvalidInput(format!("Failed to read file: {}", e)))?);
        } else if name == "input_type" {
            let input_type = field.text().await
                .map_err(|e| ApiError::InvalidInput(format!("Invalid input type: {}", e)))?;
            metadata.input_type = Some(input_type);
        }
    }

    let file_bytes = file_bytes.ok_or_else(|| {
        ApiError::InvalidInput("No file provided".to_string())
    })?;

    let cursor = Cursor::new(&file_bytes);
    let reader = BufReader::new(cursor);
    let lines: Vec<String> = reader.lines()
        .filter_map(|line| line.ok())
        .filter(|line| !line.trim().is_empty())
        .collect();

    if lines.is_empty() {
        return Err(ApiError::InvalidInput("File is empty".to_string()));
    }

    if lines.len() > 10000 {
        return Err(ApiError::InvalidInput("File contains more than 10,000 lines".to_string()));
    }

    let job_id = Uuid::new_v4().to_string();

    let job = BatchProcessingJob {
        id: job_id.clone(),
        total: lines.len(),
        processed: 0,
        results: Vec::new(),
        completed: false,
        error: None,
        last_heartbeat: Instant::now(),
        is_abandoned: false,
    };

    {
        let mut jobs = state.job_storage.write().await;
        jobs.insert(job_id.clone(), job);
    }

    let leak_check_service = state.leak_check_service.clone();
    let job_storage = state.job_storage.clone();
    
    let job_id_clone = job_id.clone();
    
    spawn(async move {
        process_batch_job(job_id_clone, lines, leak_check_service, job_storage, metadata.input_type).await;
    });

    Ok(Json(BatchCheckResponse {
        job_id,
        message: "Batch job started successfully".to_string(),
    }))
}


pub async fn get_batch_status(
    State(state): State<AppState>,
    Path(job_id): Path<String>,
) -> Result<Json<BatchCheckResultsResponse>, ApiError> {
    let mut jobs = state.job_storage.write().await; // Change to write lock to update heartbeat
    
    let job = jobs.get_mut(&job_id).ok_or_else(|| {
        ApiError::NotFound(format!("Job ID {} not found", job_id))
    })?;

    job.last_heartbeat = std::time::Instant::now();
    if job.is_abandoned {
        job.is_abandoned = false;
    }

    let total_leaked = job.results.iter().filter(|r| r.is_leaked == Some(true)).count();
    let total_not_leaked = job.results.iter().filter(|r| r.is_leaked == Some(false)).count();
    let total_errors = job.results.iter().filter(|r| r.status == "error" || r.is_leaked.is_none()).count();

    let progress_percentage = if job.total == 0 {
        100
    } else {
        ((job.processed as f32 / job.total as f32) * 100.0) as u8
    };

    let summary = BatchCheckSummary {
        total_processed: job.processed,
        total_leaked,
        total_not_leaked,
        total_errors,
        completed: job.completed,
        progress_percentage,
    };

    let results = job.results.clone();

    drop(jobs); // Release the write lock

    Ok(Json(BatchCheckResultsResponse {
        summary,
        results,
    }))
}


async fn process_batch_job(
    job_id: String,
    lines: Vec<String>,
    leak_check_service: crate::services::leak_check_service::LeakCheckService,
    job_storage: crate::models::request_models::JobStorage,
    input_type: Option<String>,
) {
    let is_email_only = input_type.as_deref() == Some("email_only");
    let mut credentials = Vec::new();
    let mut invalid_lines = Vec::new();

    for line in lines.iter() {
        let line = line.trim();
        
        if is_email_only {
            let result = CredentialCheckResult {
                credential: line.to_string(),
                is_leaked: None,
                status: "skipped".to_string(),
                message: Some("Email-only format not supported yet".to_string()),
            };
            
            invalid_lines.push(result);
        } else {
            let parts: Vec<&str> = line.split(':').collect();
            
            if parts.len() == 2 {
                let username = parts[0].trim();
                let password = parts[1].trim();
                
                if !username.is_empty() && !password.is_empty() {
                    credentials.push((username.to_string(), password.to_string()));
                    continue;
                }
            }
            
            let result = CredentialCheckResult {
                credential: line.to_string(),
                is_leaked: None,
                status: "error".to_string(),
                message: Some("Invalid format. Expected username:password".to_string()),
            };
            
            invalid_lines.push(result);
        }
    }

    if !invalid_lines.is_empty() {
        let invalid_count = invalid_lines.len();
        
        let mut jobs = job_storage.write().await;
        if let Some(job) = jobs.get_mut(&job_id) {
            job.results.extend(invalid_lines);
            job.processed += invalid_count;
        }
    }

    let mut batch_size = 10; 
    let mut processed_count = 0;
    let abandon_timeout = std::time::Duration::from_secs(15); 
    
    for (chunk_index, chunk) in credentials.chunks(batch_size).enumerate() {
        if chunk_index == 1 && batch_size < 25 {
            batch_size = 25;
        } else if chunk_index == 5 && batch_size < 50 {
            batch_size = 50;
        }
        
        let is_abandoned = {
            let jobs = job_storage.read().await;
            if let Some(job) = jobs.get(&job_id) {
                if job.completed {
                    return;
                }
                
                let elapsed = job.last_heartbeat.elapsed();
                if elapsed > abandon_timeout {
                    tracing::warn!("Job {} has no heartbeat for {:?}, marking as abandoned", job_id, elapsed);
                    true
                } else {
                    false
                }
            } else {
                true
            }
        };
        
        if is_abandoned {
            let mut jobs = job_storage.write().await;
            if let Some(job) = jobs.get_mut(&job_id) {
                job.is_abandoned = true;
                job.error = Some("Job abandoned - client stopped requesting updates".to_string());
                job.completed = true;
                
                tracing::warn!("Job {} abandoned after processing {} credentials. Stopping.", job_id, processed_count);
            }
            return;
        }
        
        match leak_check_service.check_batch_credentials(chunk.to_vec()).await {
            Ok(results) => {
                let formatted_results: Vec<CredentialCheckResult> = results
                    .into_iter()
                    .map(|(username, _, is_leaked, error)| {
                        let status = if error.is_some() { "error" } else { "checked" };
                        CredentialCheckResult {
                            credential: format!("{}:••••••••", username),
                            is_leaked: if error.is_some() { None } else { Some(is_leaked) },
                            status: status.to_string(),
                            message: error,
                        }
                    })
                    .collect();

                let mut jobs = job_storage.write().await;
                if let Some(job) = jobs.get_mut(&job_id) {
                    job.results.extend(formatted_results);
                    job.processed += chunk.len();
                    processed_count += chunk.len();
                }
            }
            Err(e) => {
                let error_msg = format!("Error checking batch: {}", e);
                
                let mut jobs = job_storage.write().await;
                if let Some(job) = jobs.get_mut(&job_id) {
                    job.error = Some(error_msg);
                    job.completed = true;
                }
                
                return;
            }
        }
        
        let delay = if batch_size <= 10 { 25 } else { 50 };
        tokio::time::sleep(tokio::time::Duration::from_millis(delay)).await;
    }

    {
        let mut jobs = job_storage.write().await;
        if let Some(job) = jobs.get_mut(&job_id) {
            job.completed = true;
            job.is_abandoned = false; // Clear abandoned flag on completion
            tracing::info!("Completed job {} with {} credentials processed", job_id, processed_count);
        }
    }

    let job_storage_clone = job_storage.clone();
    spawn(async move {
        tokio::time::sleep(tokio::time::Duration::from_secs(3600)).await;
        let mut jobs = job_storage_clone.write().await;
        if let Some(_job) = jobs.remove(&job_id) {
            tracing::info!("Cleaned up job {} after 1 hour", job_id);
        }
    });
}

pub async fn delete_batch_job(
    State(state): State<AppState>,
    Path(job_id): Path<String>,
) -> Result<Json<BatchCheckResponse>, ApiError> {
    let mut jobs = state.job_storage.write().await;
    
    if let Some(_job) = jobs.remove(&job_id) {
        tracing::info!("Job {} manually deleted", job_id);
        
        Ok(Json(BatchCheckResponse {
            job_id,
            message: "Job successfully deleted".to_string(),
        }))
    } else {
        Err(ApiError::NotFound(format!("Job ID {} not found", job_id)))
    }
}