import { useQuery, useMutation, UseQueryOptions, UseMutationOptions } from '@tanstack/react-query';
import { 
  checkSingleCredential, 
  uploadBatchCredentials, 
  getBatchJobStatus, 
  getApiStatus,
  SingleCheckResponse,
  BatchCheckResponse,
  BatchCheckResultsResponse,
  ApiStatusResponse,
  ErrorResponse,
  API_URL
} from '../lib/api';
import { useEffect } from 'react';

// Custom type guard to check if response is an error
function isErrorResponse(response: any): response is ErrorResponse {
  return response && 'error' in response && 'code' in response;
}

/**
 * Hook for checking a single credential
 */
export function useCheckSingleCredential(
  options?: Omit<UseMutationOptions<
    SingleCheckResponse | ErrorResponse, 
    unknown, 
    { username: string; password: string }
  >, 'mutationFn'>
) {
  return useMutation({
    mutationFn: ({ username, password }: { username: string; password: string }) => 
      checkSingleCredential(username, password),
    ...options
  });
}

/**
 * Hook for uploading batch credentials
 */
export function useUploadBatchCredentials(
  options?: Omit<UseMutationOptions<
    BatchCheckResponse | ErrorResponse, 
    unknown, 
    { file: File; inputType?: 'email_pass' }
  >, 'mutationFn'>
) {
  return useMutation({
    mutationFn: ({ file, inputType = 'email_pass' }: { file: File; inputType?: 'email_pass' }) => 
      uploadBatchCredentials(file, inputType),
    ...options
  });
}

/**
 * Hook for getting batch job status
 */
export function useBatchJobStatus(
  jobId: string | null,
  options?: Omit<UseQueryOptions<
    BatchCheckResultsResponse | ErrorResponse
  >, 'queryKey' | 'queryFn'>
) {
  const queryResult = useQuery({
    queryKey: ['batchJob', jobId],
    queryFn: () => {
      if (!jobId) {
        throw new Error('Job ID is required');
      }
      return getBatchJobStatus(jobId);
    },
    enabled: !!jobId,
    // Poll every second to keep job active and get updates
    refetchInterval: 1000,
    refetchIntervalInBackground: true,
    // Only refetch if the job is not completed
    refetchOnMount: true,
    // Continue refetching until job is completed
    ...options
  });

  // When job is completed, stop polling
  useEffect(() => {
    if (queryResult.data && 
        !isErrorResponse(queryResult.data) && 
        queryResult.data.summary.completed) {
      // If we have job data and it's completed, stop polling
      if (options?.refetchInterval) {
        queryResult.refetch();  // Fetch one last time to make sure we have the latest
        // The caller can still stop polling by setting enabled: false
      }
    }
  }, [queryResult.data, options?.refetchInterval]);

  return queryResult;
}

/**
 * Hook for getting API status
 */
export function useApiStatus(
  options?: Omit<UseQueryOptions<
    ApiStatusResponse | ErrorResponse
  >, 'queryKey' | 'queryFn'>
) {
  return useQuery({
    queryKey: ['apiStatus'],
    queryFn: () => getApiStatus(),
    // Default cache time of 5 minutes
    staleTime: 5 * 60 * 1000,
    ...options
  });
} 