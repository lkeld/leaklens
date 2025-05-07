"use client"

import type React from "react"

import { useState } from "react"
import { Eye, EyeOff, Info, Loader2, AlertTriangle, CheckCircle } from "lucide-react"
import { useCheckSingleCredential } from "../../hooks/use-api-queries"
import { ErrorResponse } from "../../lib/api"

export default function CheckSinglePage() {
  const [username, setUsername] = useState("")
  const [password, setPassword] = useState("")
  const [showPassword, setShowPassword] = useState(false)

  const { 
    mutate: checkCredential, 
    isPending: isLoading, 
    data, 
    error: mutationError,
    isError 
  } = useCheckSingleCredential({
    onError: (error) => {
      console.error('Error checking credential:', error);
    }
  });

  // Check if data is an error response
  const isErrorResponse = (data?: any): data is ErrorResponse => {
    return data && 'error' in data && 'code' in data;
  };

  // Handle form submission
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    // Form validation
    if (!username.trim() || !password.trim()) {
      return;
    }

    // Make the API call to check the credential
    checkCredential({ username, password });
  }

  // Determine result state for UI
  let result: "leaked" | "not-leaked" | "error" | null = null;
  let errorMessage = "";

  if (isError) {
    result = "error";
    errorMessage = "An unexpected error occurred. Please try again later.";
  } else if (data) {
    if (isErrorResponse(data)) {
      result = "error";
      errorMessage = data.error || "An error occurred while checking the credentials. Please try again.";
    } else {
      result = data.is_leaked ? "leaked" : "not-leaked";
    }
  }

  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-xl px-4 sm:px-6 lg:px-8">
        <h1 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">
          Check a Single Credential
        </h1>

        <form onSubmit={handleSubmit} className="mt-8 space-y-6">
          <div>
            <label htmlFor="username" className="block text-sm font-medium text-gray-200">
              Username or Email
            </label>
            <div className="mt-1">
              <input
                id="username"
                name="username"
                type="text"
                autoComplete="username"
                required
                placeholder="e.g., user@example.com or myusername"
                className="block w-full rounded-md border-gray-700 bg-gray-800 px-4 py-3 text-white placeholder-gray-500 shadow-sm transition-colors focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                disabled={isLoading}
              />
            </div>
          </div>

          <div>
            <label htmlFor="password" className="block text-sm font-medium text-gray-200">
              Password
            </label>
            <div className="relative mt-1">
              <input
                id="password"
                name="password"
                type={showPassword ? "text" : "password"}
                autoComplete="current-password"
                required
                placeholder="Enter password"
                className="block w-full rounded-md border-gray-700 bg-gray-800 px-4 py-3 text-white placeholder-gray-500 shadow-sm transition-colors focus:border-purple-500 focus:outline-none focus:ring-2 focus:ring-purple-500"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                disabled={isLoading}
              />
              <button
                type="button"
                className="absolute inset-y-0 right-0 flex items-center px-3 text-gray-400 hover:text-gray-200"
                onClick={() => setShowPassword(!showPassword)}
                aria-label={showPassword ? "Hide password" : "Show password"}
              >
                {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="flex w-full items-center justify-center rounded-md bg-gradient-to-r from-purple-600 to-blue-600 px-4 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:from-purple-700 hover:to-blue-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900 disabled:opacity-70"
          >
            {isLoading ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                Checking...
              </>
            ) : (
              "Check Now"
            )}
          </button>

          <div className="flex items-start space-x-2 text-sm text-gray-400">
            <Info className="mt-0.5 h-4 w-4 flex-shrink-0" />
            <p>
              Your password is encrypted in your browser using commutative elliptic curve cryptography before any check
              is performed. We never see or store your plaintext password.
            </p>
          </div>
        </form>

        {/* Results Area */}
        {(isLoading || result) && (
          <div className="mt-8 overflow-hidden rounded-lg shadow-lg transition-all duration-300">
            {/* Loading State */}
            {isLoading && (
              <div className="flex flex-col items-center justify-center space-y-4 bg-gray-800 p-6 text-center">
                <Loader2 className="h-8 w-8 animate-spin text-purple-500" />
                <p className="text-lg font-medium text-gray-200">Checking your credentials...</p>
                <p className="text-sm text-gray-400">This may take a few moments</p>
              </div>
            )}

            {/* Error State */}
            {result === "error" && (
              <div className="border-l-4 border-red-500 bg-gray-800 p-6">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <AlertTriangle className="h-6 w-6 text-red-500" />
                  </div>
                  <div className="ml-3">
                    <h3 className="text-lg font-medium text-red-400">Error</h3>
                    <p className="mt-2 text-gray-300">{errorMessage}</p>
                    <p className="mt-3 text-sm text-gray-400">
                      Please check your input and try again. If the problem persists, contact support.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Success State (Leaked) */}
            {result === "leaked" && (
              <div className="border-l-4 border-red-500 bg-gray-800 p-6">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <AlertTriangle className="h-6 w-6 text-red-500" />
                  </div>
                  <div className="ml-3">
                    <h3 className="text-lg font-medium text-red-400">Status: Leaked</h3>
                    <p className="mt-2 text-gray-300">
                      This credential (Username: <span className="font-medium">{username}</span>, Password: ••••••••)
                      was found in a known data breach. We strongly recommend changing your password immediately on all
                      services where it was used and enabling Two-Factor Authentication (2FA).
                    </p>
                    <div className="mt-4 rounded-md bg-gray-900/50 p-4">
                      <h4 className="font-medium text-gray-200">Recommended Actions:</h4>
                      <ul className="mt-2 list-inside list-disc space-y-1 text-gray-400">
                        <li>Change your password on all services where it was used</li>
                        <li>Enable Two-Factor Authentication (2FA) where available</li>
                        <li>Use a password manager to generate unique passwords</li>
                        <li>Check other credentials you commonly use</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Success State (Not Leaked) */}
            {result === "not-leaked" && (
              <div className="border-l-4 border-green-500 bg-gray-800 p-6">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <CheckCircle className="h-6 w-6 text-green-500" />
                  </div>
                  <div className="ml-3">
                    <h3 className="text-lg font-medium text-green-400">Status: Not Found in Leaks</h3>
                    <p className="mt-2 text-gray-300">
                      This credential (Username: <span className="font-medium">{username}</span>, Password: ••••••••)
                      was not found in the checked breach datasets. Continue to practice good password hygiene.
                    </p>
                    <div className="mt-4 rounded-md bg-gray-900/50 p-4">
                      <h4 className="font-medium text-gray-200">Password Best Practices:</h4>
                      <ul className="mt-2 list-inside list-disc space-y-1 text-gray-400">
                        <li>Use unique passwords for each service</li>
                        <li>Enable Two-Factor Authentication (2FA) where available</li>
                        <li>Regularly update your passwords</li>
                        <li>Consider using a password manager</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
