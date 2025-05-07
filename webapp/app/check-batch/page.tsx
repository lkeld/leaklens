"use client"

import type React from "react"

import { useState, useRef, useEffect } from "react"
import { Upload, FileText, AlertTriangle, CheckCircle, X, Loader2, Download, Info } from "lucide-react"
import { useUploadBatchCredentials, useBatchJobStatus } from "../../hooks/use-api-queries"
import { ErrorResponse } from "../../lib/api"
import { Progress } from "../../components/ui/progress"

type CredentialStatus = "checked" | "error" | "pending"

interface Credential {
  credential: string;
  is_leaked: boolean;
  status: CredentialStatus;
  message: string | null;
}

export default function CheckBatchPage() {
  const [file, setFile] = useState<File | null>(null)
  const [dragActive, setDragActive] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [jobId, setJobId] = useState<string | null>(null)
  const [currentPage, setCurrentPage] = useState(1)
  const [itemsPerPage, setItemsPerPage] = useState(10)
  const [estimatedTotal, setEstimatedTotal] = useState(0)
  const [processingStartTime, setProcessingStartTime] = useState<number | null>(null)
  const [initialProcessing, setInitialProcessing] = useState(false)
  const [showProgressFeedback, setShowProgressFeedback] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  const resultsRef = useRef<HTMLDivElement>(null)
  const progressCheckCountRef = useRef(0)

  // Reset state when file changes
  useEffect(() => {
    if (file) {
      setError(null)
      setCurrentPage(1)
      setJobId(null)
      setProcessingStartTime(null)
      setInitialProcessing(false)
      
      // Estimate the number of lines in the file
      estimateFileLines(file).then(count => {
        setEstimatedTotal(count)
      })
    }
  }, [file])
  
  // Function to estimate the number of lines in a file
  const estimateFileLines = async (file: File): Promise<number> => {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const text = e.target?.result as string;
        if (text) {
          const lines = text.split('\n').filter(line => line.trim().length > 0);
          resolve(lines.length);
        } else {
          resolve(0);
        }
      };
      // Read first 100KB to estimate
      const blob = file.slice(0, 100 * 1024);
      reader.readAsText(blob);
    });
  };

  // Upload batch mutation
  const { 
    mutate: uploadBatch, 
    isPending: isUploading,
  } = useUploadBatchCredentials({
    onSuccess: (data) => {
      if ('error' in data) {
        setError(data.error);
      } else {
        // Set the job ID to start polling for results
        setJobId(data.job_id);
        setProcessingStartTime(Date.now());
        setInitialProcessing(true);
        // Enable immediate progress feedback
        setShowProgressFeedback(true);
        // Scroll to results section once upload is complete
        setTimeout(() => {
          resultsRef.current?.scrollIntoView({ behavior: 'smooth' });
        }, 500);
      }
    },
    onError: (error) => {
      setError("An error occurred during the upload. Please try again.");
      console.error("Upload error:", error);
    }
  });

  // Job status query with higher frequency updates for large files
  const {
    data: jobData,
    isLoading: isProcessing,
    error: jobError
  } = useBatchJobStatus(jobId, {
    enabled: !!jobId,
    refetchInterval: 1000, // Poll every second for more responsive updates
    refetchOnMount: true,
    refetchIntervalInBackground: true
  });
  
  // Effect to check for initial data loading completion
  useEffect(() => {
    if (jobData && !isErrorResponse(jobData) && jobData.summary.total_processed > 0) {
      setInitialProcessing(false);
    }
  }, [jobData]);

  // Check if response is an error
  const isErrorResponse = (data?: any): data is ErrorResponse => {
    return data && 'error' in data && 'code' in data;
  };

  // Process credentials from job data
  const credentials: Credential[] = jobData && !isErrorResponse(jobData) 
    ? jobData.results 
    : [];

  // Calculate statistics
  const summary = jobData && !isErrorResponse(jobData) 
    ? jobData.summary 
    : { 
        total_processed: 0, 
        total_leaked: 0, 
        total_not_leaked: 0, 
        total_errors: 0,
        completed: false,
        progress_percentage: 0
      };
  
  // Auto-adjust items per page based on total items
  useEffect(() => {
    if (credentials.length > 1000) {
      setItemsPerPage(50);
    } else if (credentials.length > 500) {
      setItemsPerPage(25);
    } else if (credentials.length > 100) {
      setItemsPerPage(15);
    } else {
      setItemsPerPage(10);
    }
  }, [credentials.length]);

  // Add beforeunload event handler to warn when closing during processing
  useEffect(() => {
    const handleBeforeUnload = (e: BeforeUnloadEvent) => {
      if (isUploading || isProcessing) {
        // Standard way of showing confirmation dialog before page unload
        e.preventDefault()
        e.returnValue = 'You have an active credential check in progress. Are you sure you want to leave?'
        return e.returnValue
      }
    }

    window.addEventListener('beforeunload', handleBeforeUnload)
    return () => {
      window.removeEventListener('beforeunload', handleBeforeUnload)
    }
  }, [isUploading, isProcessing])

  // Track the first successful response manually
  useEffect(() => {
    if (jobData && !isErrorResponse(jobData) && progressCheckCountRef.current === 0) {
      progressCheckCountRef.current++;
    }
  }, [jobData]);

  // Effect to handle job errors or abandonment
  useEffect(() => {
    if (jobData && isErrorResponse(jobData)) {
      setError(jobData.error);
      setJobId(null); // Reset job ID to stop polling
      setShowProgressFeedback(false);
    } else if (jobData && !isErrorResponse(jobData) && jobData.summary.completed) {
      // Job is completed
      setShowProgressFeedback(false);
      
      // Check if job was abandoned
      if (credentials.length === 0 && jobData.summary.total_processed === 0) {
        setError("The job was abandoned due to inactivity. Please try again.");
        setJobId(null);
      }
    }
  }, [jobData, credentials.length]);

  // Reset progress check count when job changes
  useEffect(() => {
    if (jobId) {
      progressCheckCountRef.current = 0;
    } else {
      // If job ID is cleared and we still have the feedback UI, hide it
      setShowProgressFeedback(false);
    }
  }, [jobId]);

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()

    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true)
    } else if (e.type === "dragleave") {
      setDragActive(false)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFileChange(e.dataTransfer.files[0])
    }
  }

  const handleFileChange = (selectedFile: File) => {
    // Check file type
    if (!selectedFile.name.endsWith(".txt")) {
      setError("Please upload a .txt file.")
      setFile(null)
      return
    }

    // Check file size (10MB max)
    if (selectedFile.size > 10 * 1024 * 1024) {
      setError("File size exceeds 10MB limit.")
      setFile(null)
      return
    }

    setFile(selectedFile)
  }

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      handleFileChange(e.target.files[0])
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!file) {
      setError("Please select a file to upload.")
      return
    }

    setError(null)

    // Upload the file using the mutation - always use email_pass format
    uploadBatch({ file, inputType: "email_pass" });
  }

  const resetForm = () => {
    setFile(null)
    setError(null)
    setJobId(null)
    setCurrentPage(1)
    setEstimatedTotal(0)
    setProcessingStartTime(null)
    setInitialProcessing(false)
    if (fileInputRef.current) {
      fileInputRef.current.value = ""
    }
  }

  // Pagination
  const totalPages = Math.ceil(credentials.length / itemsPerPage)
  const paginatedCredentials = credentials.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage)

  // Download results as CSV
  const downloadResults = () => {
    if (!credentials.length) return;

    const csvContent = [
      ["Credential", "Status", "Is Leaked", "Message"].join(","),
      ...credentials.map((cred) => [
        cred.credential, 
        cred.status, 
        cred.is_leaked ? "Yes" : "No", 
        cred.message || ""
      ].join(",")),
    ].join("\n")

    const blob = new Blob([csvContent], { type: "text/csv" })
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.setAttribute("href", url)
    a.setAttribute("download", "credential-check-results.csv")
    a.click()
    URL.revokeObjectURL(url)
  }

  // Calculate the estimated time remaining based on current progress
  const calculateETA = () => {
    if (!summary.progress_percentage || summary.progress_percentage < 1 || !processingStartTime) {
      return "Calculating...";
    }
    
    const processed = summary.total_processed;
    if (processed === 0) return "Calculating...";
    
    const elapsed = Date.now() - processingStartTime;
    const estimatedTotalTime = (elapsed / summary.progress_percentage) * 100;
    const remaining = estimatedTotalTime - elapsed;
    
    if (remaining < 60000) {
      return `about ${Math.ceil(remaining / 1000)} seconds`;
    } else {
      return `about ${Math.ceil(remaining / 60000)} minutes`;
    }
  };

  // Check if we should show the loading animation for progress
  const showProgressAnimation = initialProcessing || (isProcessing && (progressCheckCountRef.current === 0 || summary.total_processed === 0));

  // Determine if we should show the indeterminate progress state
  const showIndeterminateProgress = isUploading || showProgressAnimation;
  
  // Add a pulsing effect to indicate activity even when no progress data yet
  const progressClasses = `h-4 w-full rounded-xl ${showIndeterminateProgress ? 'animate-pulse' : ''} bg-gray-700`;

  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8">
        <h1 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">
          Batch Check Credentials from File
        </h1>

        {/* Instructions Section */}
        <section className="mt-8 rounded-xl bg-gray-800/50 p-6 backdrop-blur-sm shadow-md">
          <h3 className="text-xl font-semibold text-white">How to Prepare Your File</h3>
          <ul className="mt-4 space-y-2 text-gray-300">
            <li className="flex items-start">
              <span className="mr-2 mt-1 text-purple-500">•</span>
              <span>Upload a <code className="rounded-md bg-gray-700 px-1 py-0.5 text-xs">txt</code> file with one credential per line</span>
            </li>
            <li className="flex items-start">
              <span className="mr-2 mt-1 text-purple-500">•</span>
              <span>
                Format each line as <code className="rounded-md bg-gray-700 px-1 py-0.5 text-xs">username:password</code> or <code className="rounded-md bg-gray-700 px-1 py-0.5 text-xs">email:password</code>
              </span>
            </li>
            <li className="flex items-start">
              <span className="mr-2 mt-1 text-purple-500">•</span>
              <span>Up to 10,000 credentials supported per file</span>
            </li>
            <li className="flex items-start">
              <span className="mr-2 mt-1 text-purple-500">•</span>
              <span>Maximum file size: 10MB</span>
            </li>
          </ul>
        </section>

        {/* File Upload Section */}
        <form onSubmit={handleSubmit} className="mt-8">
          <div className="space-y-6">
            <div
              className={`flex flex-col items-center justify-center rounded-xl border-2 border-dashed p-6 transition-colors duration-200 ${
                dragActive
                  ? "border-purple-500 bg-gray-800/70"
                  : "border-gray-700 bg-gray-800/30 hover:border-gray-500 hover:bg-gray-800/50"
              } shadow-sm`}
              onDragEnter={handleDrag}
              onDragOver={handleDrag}
              onDragLeave={handleDrag}
              onDrop={handleDrop}
            >
              <div className="flex flex-col items-center justify-center pb-6 pt-5">
                <FileText className="mb-3 h-10 w-10 text-gray-400" />
                <p className="mb-2 text-sm text-gray-400">
                  <span className="font-semibold">Click to upload</span> or drag and drop
                </p>
                <p className="text-xs text-gray-500">TXT file up to 10MB (max 10,000 entries)</p>
              </div>
              <input
                ref={fileInputRef}
                id="file-upload"
                type="file"
                accept=".txt"
                className="hidden"
                onChange={handleFileInputChange}
                disabled={isUploading || isProcessing}
              />
              <button
                type="button"
                onClick={() => fileInputRef.current?.click()}
                disabled={isUploading || isProcessing}
                className="inline-flex items-center rounded-xl bg-gray-700 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:cursor-not-allowed disabled:opacity-50"
              >
                <Upload className="mr-2 h-4 w-4" />
                Select File
              </button>
            </div>

            {file && (
              <div className="flex items-center justify-between rounded-xl bg-gray-800 p-3 shadow-sm">
                <div className="flex items-center space-x-3">
                  <FileText className="h-5 w-5 text-purple-500" />
                  <div>
                    <p className="text-sm font-medium text-gray-200">{file.name}</p>
                    <p className="text-xs text-gray-400">
                      {(file.size / 1024).toFixed(2)} KB 
                      {estimatedTotal > 0 && ` • ~${estimatedTotal} entries`}
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={resetForm}
                  disabled={isUploading || isProcessing}
                  className="rounded-full p-1 text-gray-400 hover:bg-gray-700 hover:text-gray-200"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            )}

            {error && (
              <div className="rounded-xl bg-red-900/30 p-4 text-sm text-red-300 shadow-sm">
                <div className="flex">
                  <AlertTriangle className="mr-2 h-5 w-5 flex-shrink-0 text-red-500" />
                  <span>{error}</span>
                </div>
              </div>
            )}

            <div className="flex space-x-3">
              <button
                type="submit"
                disabled={!file || isUploading || isProcessing}
                className="flex-1 rounded-xl bg-gradient-to-r from-purple-600 to-blue-600 px-4 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:from-purple-700 hover:to-blue-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-70"
              >
                {isUploading ? (
                  <div className="flex items-center justify-center">
                    <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                    Uploading...
                  </div>
                ) : isProcessing ? (
                  <div className="flex items-center justify-center">
                    <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                    Processing...
                  </div>
                ) : (
                  "Upload & Check"
                )}
              </button>
              <button
                type="button"
                onClick={resetForm}
                disabled={isUploading || isProcessing}
                className="rounded-xl border border-gray-700 bg-gray-800 px-4 py-3 text-base font-medium text-gray-300 transition-colors hover:border-gray-600 hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-70"
              >
                Reset
              </button>
            </div>
          </div>
        </form>

        {/* Progress Section */}
        {(isUploading || isProcessing || showProgressFeedback) && (
          <div className="mt-8 rounded-xl bg-gray-800 p-6 shadow-md" ref={resultsRef}>
            <h3 className="text-lg font-medium text-white">
              {isUploading ? "Uploading File..." : initialProcessing ? "Preparing Batch Job..." : "Processing Credentials..."}
            </h3>
            <div className="mt-4">
              <Progress 
                value={showIndeterminateProgress ? undefined : summary.progress_percentage} 
                className={progressClasses}
              />
              <div className="mt-2 flex justify-between text-sm text-gray-400">
                <span>
                  {isUploading 
                    ? "Uploading file..." 
                    : initialProcessing || showProgressAnimation
                      ? "Starting to process, please wait (this may take a few seconds)..."
                      : `Processed: ${summary.total_processed} / ${estimatedTotal || '?'}`}
                </span>
                <span>
                  {isUploading 
                    ? "Please wait..." 
                    : initialProcessing || showProgressAnimation
                      ? "Initializing..."
                      : `${summary.progress_percentage.toFixed(1)}%`}
                </span>
              </div>

              {(isProcessing || showProgressFeedback) && !showProgressAnimation && (
                <>
                  <div className="mt-4 grid grid-cols-3 gap-2 text-center text-xs">
                    <div className="rounded-xl bg-gray-700/50 p-2 shadow-inner">
                      <p className="text-gray-400">ETA</p>
                      <p className="font-medium text-white">{calculateETA()}</p>
                    </div>
                    <div className="rounded-xl bg-red-900/20 p-2 shadow-inner">
                      <p className="text-red-300">Leaked</p>
                      <p className="font-medium text-red-500">{summary.total_leaked}</p>
                    </div>
                    <div className="rounded-xl bg-green-900/20 p-2 shadow-inner">
                      <p className="text-green-300">Safe</p>
                      <p className="font-medium text-green-500">{summary.total_not_leaked}</p>
                    </div>
                  </div>
                </>
              )}
            </div>
            
            {/* Processing note */}
            {isProcessing && (
              <div className="mt-4 rounded-xl bg-blue-900/20 p-3 text-sm text-blue-300">
                <div className="flex items-start">
                  <Info className="mr-2 mt-0.5 h-4 w-4 flex-shrink-0" />
                  <p>
                    <strong>Note:</strong> You can safely navigate away from this page - your check will continue to run in
                    the background. When you return, the results will be waiting for you.
                  </p>
                </div>
              </div>
            )}
          </div>
        )}

        {/* Real-time Results Section - Show even while processing */}
        {(isProcessing || (!isUploading && credentials.length > 0)) && (
          <div className="mt-8 rounded-xl bg-gray-800 p-6 shadow-md">
            <div className="flex flex-col items-start justify-between sm:flex-row sm:items-center">
              <h3 className="text-lg font-medium text-white">
                Check Results
                {!summary.completed && isProcessing && (
                  <span className="ml-2 text-sm text-gray-400">(Updating live)</span>
                )}
              </h3>
              {credentials.length > 0 && (
                <button
                  onClick={downloadResults}
                  className="mt-3 inline-flex items-center rounded-xl bg-gray-700 px-3 py-1.5 text-sm text-white transition-colors hover:bg-gray-600 sm:mt-0"
                >
                  <Download className="mr-1.5 h-4 w-4" />
                  Download CSV
                </button>
              )}
            </div>

            {/* Stats Cards */}
            <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div className="rounded-xl bg-gray-700/50 p-4 text-center shadow-inner">
                <p className="text-sm font-medium text-gray-400">Total Processed</p>
                <p className="mt-1 text-2xl font-bold text-white">{summary.total_processed}</p>
                {summary.total_processed > 0 && estimatedTotal > 0 && (
                  <p className="text-xs text-gray-400">of {estimatedTotal} ({Math.floor((summary.total_processed / estimatedTotal) * 100)}%)</p>
                )}
              </div>
              <div className="rounded-xl bg-red-900/20 p-4 text-center shadow-inner">
                <p className="text-sm font-medium text-red-300">Leaked</p>
                <p className="mt-1 text-2xl font-bold text-red-500">{summary.total_leaked}</p>
                {summary.total_processed > 0 && (
                  <p className="text-xs text-red-300">
                    {((summary.total_leaked / summary.total_processed) * 100).toFixed(1)}% of processed
                  </p>
                )}
              </div>
              <div className="rounded-xl bg-green-900/20 p-4 text-center shadow-inner">
                <p className="text-sm font-medium text-green-300">Not Leaked</p>
                <p className="mt-1 text-2xl font-bold text-green-500">{summary.total_not_leaked}</p>
                {summary.total_processed > 0 && (
                  <p className="text-xs text-green-300">
                    {((summary.total_not_leaked / summary.total_processed) * 100).toFixed(1)}% of processed
                  </p>
                )}
              </div>
            </div>

            {/* Results Table */}
            {credentials.length > 0 && (
              <div className="mt-6 overflow-hidden rounded-xl border border-gray-700">
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-700">
                    <thead className="bg-gray-800/50">
                      <tr>
                        <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-300">Credential</th>
                        <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-300">Status</th>
                        <th className="px-3 py-3.5 text-left text-sm font-semibold text-gray-300">Message</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-700">
                      {paginatedCredentials.map((cred, idx) => (
                        <tr key={idx} className="bg-gray-800/30 hover:bg-gray-800/60">
                          <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-300">{cred.credential}</td>
                          <td className="whitespace-nowrap px-3 py-4 text-sm">
                            {cred.status === "error" ? (
                              <span className="flex items-center text-amber-400">
                                <AlertTriangle className="mr-1 h-4 w-4" />
                                Error
                              </span>
                            ) : cred.status === "pending" ? (
                              <span className="flex items-center text-blue-400">
                                <Loader2 className="mr-1 h-4 w-4 animate-spin" />
                                Pending
                              </span>
                            ) : cred.is_leaked ? (
                              <span className="flex items-center text-red-400">
                                <AlertTriangle className="mr-1 h-4 w-4" />
                                Leaked
                              </span>
                            ) : (
                              <span className="flex items-center text-green-400">
                                <CheckCircle className="mr-1 h-4 w-4" />
                                Not Leaked
                              </span>
                            )}
                          </td>
                          <td className="whitespace-nowrap px-3 py-4 text-sm text-gray-400">{cred.message || '-'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Pagination */}
            {totalPages > 1 && (
              <div className="mt-6 flex items-center justify-between">
                <div className="flex items-center space-x-2 text-sm text-gray-400">
                  <span>Page</span>
                  <span className="font-medium text-white">{currentPage}</span>
                  <span>of</span>
                  <span className="font-medium text-white">{totalPages}</span>
                  <span className="ml-2">({credentials.length} total results)</span>
                </div>
                <div className="flex space-x-2">
                  <button
                    disabled={currentPage === 1}
                    onClick={() => setCurrentPage((prev) => Math.max(prev - 1, 1))}
                    className="rounded-xl border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-gray-300 transition-colors hover:border-gray-600 hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-50"
                  >
                    Previous
                  </button>
                  <button
                    disabled={currentPage === totalPages}
                    onClick={() => setCurrentPage((prev) => Math.min(prev + 1, totalPages))}
                    className="rounded-xl border border-gray-700 bg-gray-800 px-3 py-1.5 text-sm text-gray-300 transition-colors hover:border-gray-600 hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}

            {/* Help Text */}
            <div className="mt-6 flex items-start space-x-2 rounded-xl bg-gray-700/30 p-4 text-sm text-gray-400">
              <Info className="mt-0.5 h-4 w-4 flex-shrink-0" />
              <div>
                <p className="mb-1">
                  <strong className="font-medium text-gray-300">Understanding the results:</strong>
                </p>
                <ul className="list-inside list-disc space-y-1">
                  <li>
                    <strong className="text-red-400">Leaked</strong>: Credential found in at least one known data breach.
                  </li>
                  <li>
                    <strong className="text-green-400">Not Leaked</strong>: No matches found in the checked datasets.
                  </li>
                  <li>
                    <strong className="text-amber-400">Error</strong>: Could not verify this credential.
                  </li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
