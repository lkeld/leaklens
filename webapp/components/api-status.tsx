import { AlertTriangle, CheckCircle, Loader2 } from "lucide-react";
import { useApiStatus } from "../hooks/use-api-queries";

export function ApiStatus() {
  const { data, isLoading, isError, error } = useApiStatus();
  
  // Error state
  if (isError) {
    return (
      <div className="flex items-center rounded-md bg-red-900/30 px-2 py-1 text-xs text-red-300">
        <AlertTriangle className="mr-1 h-3 w-3 text-red-500" />
        <span>API: Error</span>
      </div>
    );
  }
  
  // Loading state
  if (isLoading) {
    return (
      <div className="flex items-center rounded-md bg-gray-800/70 px-2 py-1 text-xs text-gray-300">
        <Loader2 className="mr-1 h-3 w-3 animate-spin text-purple-500" />
        <span>API: Checking</span>
      </div>
    );
  }
  
  // Error response
  if (data && 'error' in data) {
    return (
      <div className="flex items-center rounded-md bg-red-900/30 px-2 py-1 text-xs text-red-300">
        <AlertTriangle className="mr-1 h-3 w-3 text-red-500" />
        <span>API: Error</span>
      </div>
    );
  }
  
  // Google API error
  if (data && data.google_api_status.status === 'error') {
    return (
      <div className="flex items-center rounded-md bg-amber-900/30 px-2 py-1 text-xs text-amber-300">
        <AlertTriangle className="mr-1 h-3 w-3 text-amber-500" />
        <span>Google API: Error</span>
      </div>
    );
  }
  
  // Success state
  return (
    <div className="flex items-center rounded-md bg-green-900/30 px-2 py-1 text-xs text-green-300">
      <CheckCircle className="mr-1 h-3 w-3 text-green-500" />
      <span>API: Online {data?.version ? `(v${data.version})` : ''}</span>
    </div>
  );
} 