/**
 * API client for interacting with the LeakLens backend
 */
import { z } from 'zod';

// API base URL - This can be overridden by environment variables in production
export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

// Type definitions
export interface SingleCheckRequest {
  username: string;
  password: string;
}

export interface SingleCheckResponse {
  username: string;
  is_leaked: boolean;
  message?: string;
}

export interface BatchCheckResponse {
  job_id: string;
  message: string;
}

export interface BatchCheckResultsResponse {
  summary: {
    total_processed: number;
    total_leaked: number;
    total_not_leaked: number;
    total_errors: number;
    completed: boolean;
    progress_percentage: number;
  };
  results: Array<{
    credential: string;
    is_leaked: boolean;
    status: 'checked' | 'error' | 'pending';
    message: string | null;
  }>;
}

export interface ApiStatusResponse {
  status: 'ok' | 'error';
  timestamp: string;
  google_api_status: {
    status: 'ok' | 'error';
    message: string;
  };
  version: string;
}

export interface ErrorResponse {
  error: string;
  code: string;
}

/**
 * Check a single credential (email/username + password) for leaks
 * @param username - The email or username to check
 * @param password - The password to check
 * @returns Promise resolving to the check result
 */
export async function checkSingleCredential(
  username: string, 
  password: string
): Promise<SingleCheckResponse | ErrorResponse> {
  try {
    const response = await fetch(`${API_URL}/api/v1/check/single`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ username, password }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      return data as ErrorResponse;
    }

    return data as SingleCheckResponse;
  } catch (error) {
    console.error('API call failed:', error);
    return { 
      error: 'Network error occurred while checking credential',
      code: 'NETWORK_ERROR'
    };
  }
}

/**
 * Upload a batch of credentials for leak checking
 * @param file - File containing credentials (one per line, username:password format)
 * @returns Promise resolving to the batch job information
 */
export async function uploadBatchCredentials(
  file: File,
  inputType: 'email_pass' = 'email_pass'  // Keep parameter for backward compatibility but only allow email_pass
): Promise<BatchCheckResponse | ErrorResponse> {
  try {
    // Validate file size (10MB limit)
    if (file.size > 10 * 1024 * 1024) {
      return {
        error: 'File size exceeds 10MB limit',
        code: 'FILE_TOO_LARGE'
      };
    }

    // Prepare form data
    const formData = new FormData();
    formData.append('file', file);
    formData.append('inputType', 'email_pass');  // Always use email_pass
    formData.append('maxEntries', '10000');  // Support up to 10,000 entries per batch

    const response = await fetch(`${API_URL}/api/v1/check/batch`, {
      method: 'POST',
      body: formData,
    });

    const data = await response.json();
    
    if (!response.ok) {
      return data as ErrorResponse;
    }

    return data as BatchCheckResponse;
  } catch (error) {
    console.error('API call failed:', error);
    return { 
      error: 'Network error occurred while uploading credentials',
      code: 'NETWORK_ERROR'
    };
  }
}

/**
 * Get batch job status and results
 * @param jobId - ID of the batch job to check
 * @returns Promise resolving to the job status and results
 */
export async function getBatchJobStatus(
  jobId: string
): Promise<BatchCheckResultsResponse | ErrorResponse> {
  try {
    const response = await fetch(`${API_URL}/api/v1/check/batch/${jobId}/status`);
    
    const data = await response.json();
    
    if (!response.ok) {
      return data as ErrorResponse;
    }

    return data as BatchCheckResultsResponse;
  } catch (error) {
    console.error('API call failed:', error);
    return { 
      error: 'Network error occurred while checking job status',
      code: 'NETWORK_ERROR'
    };
  }
}

/**
 * Get API status information
 * @returns Promise resolving to API status data
 */
export async function getApiStatus(): Promise<ApiStatusResponse | ErrorResponse> {
  try {
    const response = await fetch(`${API_URL}/api/v1/status`);
    
    const data = await response.json();
    
    if (!response.ok) {
      return data as ErrorResponse;
    }

    return data as ApiStatusResponse;
  } catch (error) {
    console.error('API status check failed:', error);
    return { 
      error: 'Network error occurred while checking API status',
      code: 'NETWORK_ERROR'
    };
  }
}