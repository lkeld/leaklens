export default function APIDocsPage() {
  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
        <h1 className="bg-gradient-to-r from-purple-400 to-blue-500 bg-clip-text text-center text-3xl font-bold tracking-tight text-transparent sm:text-4xl lg:text-5xl">
          Developer API Documentation
        </h1>

        {/* Introduction Section */}
        <section className="mt-8">
          <p className="text-lg leading-relaxed text-gray-300">
            Integrate LeakLens credential leak checking capabilities into your own applications or services using our
            simple REST API.
          </p>

          <div className="mt-6 space-y-6">
            <div>
              <h3 className="text-xl font-semibold text-white">Base URL</h3>
              <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                <code>https://yourdomain.com/api/v1</code>
              </pre>
            </div>

            <div>
              <h3 className="text-xl font-semibold text-white">Authentication</h3>
              <p className="mt-2 text-gray-300">
                Currently, the API is open for use with rate limiting. Future versions may require API key
                authentication. Please use responsibly.
              </p>
            </div>

            <div>
              <h3 className="text-xl font-semibold text-white">Rate Limiting</h3>
              <p className="mt-2 text-gray-300">
                Default rate limits: 60 requests/minute for single checks, 100 requests/hour for batch checks (per IP).
                Contact us for higher limits.
              </p>
            </div>

            <div>
              <h3 className="text-xl font-semibold text-white">Data Formats</h3>
              <p className="mt-2 text-gray-300">
                All request and response bodies are JSON, except for batch file uploads which use{" "}
                <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">multipart/form-data</code>.
              </p>
            </div>
          </div>
        </section>

        {/* Endpoints Section */}
        <section className="mt-12">
          {/* Endpoint 1: Check Single Credential */}
          <div>
            <h2 className="text-2xl font-bold text-white">Check Single Credential</h2>
            <div className="mt-4 space-y-4">
              <div className="flex items-center">
                <h3 className="text-xl font-semibold text-white">Path & Method</h3>
                <span className="ml-3 rounded-full bg-green-600/20 px-2.5 py-0.5 text-xs font-medium text-green-400">
                  POST
                </span>
              </div>
              <pre className="overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                <code>/check/single</code>
              </pre>
              <p className="text-gray-300">Checks a single username/password credential against known leaks.</p>

              <div>
                <h3 className="text-xl font-semibold text-white">Request Body</h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`{
  "username": "user@example.com",
  "password": "password123"
}`}</code>
                </pre>
              </div>

              <div>
                <h3 className="text-xl font-semibold text-white">Response (Success 200 OK)</h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`{
  "username": "user@example.com",
  "is_leaked": true,
  "message": "Credential found in a known data breach."
}`}</code>
                </pre>
              </div>

              <div>
                <h3 className="text-xl font-semibold text-white">
                  Example <code className="text-purple-400">curl</code> Request
                </h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`curl -X POST https://yourdomain.com/api/v1/check/single \\
     -H "Content-Type: application/json" \\
     -d '{"username": "user@example.com", "password": "password123"}'`}</code>
                </pre>
              </div>
            </div>
          </div>

          {/* Endpoint 2: Check Batch Credentials */}
          <div className="mt-12">
            <h2 className="text-2xl font-bold text-white">Check Batch Credentials</h2>
            <div className="mt-4 space-y-4">
              <div className="flex items-center">
                <h3 className="text-xl font-semibold text-white">Path & Method</h3>
                <span className="ml-3 rounded-full bg-green-600/20 px-2.5 py-0.5 text-xs font-medium text-green-400">
                  POST
                </span>
              </div>
              <pre className="overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                <code>/check/batch</code>
              </pre>
              <p className="text-gray-300">
                Checks multiple credentials from an uploaded{" "}
                <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">.txt</code> file.
              </p>

              <div>
                <h3 className="text-xl font-semibold text-white">Request Body</h3>
                <p className="mt-2 text-gray-300">
                  <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">multipart/form-data</code>
                </p>
                <ul className="mt-2 list-inside list-disc space-y-2 text-gray-300">
                  <li>
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">file</code>: The{" "}
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">.txt</code> file containing
                    credentials (e.g.,{" "}
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">username:password</code> per
                    line).
                  </li>
                  <li>
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">inputType</code> (optional form
                    field, string): Specifies format. E.g.,{" "}
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">email_pass</code> (default) or{" "}
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">email_only</code>.
                  </li>
                </ul>
              </div>

              <div>
                <h3 className="text-xl font-semibold text-white">Response (Success 200 OK)</h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`{
  "summary": {
    "total_processed": 100,
    "total_leaked": 5,
    "total_not_leaked": 90,
    "total_errors": 5
  },
  "results": [
    { "credential": "user1:pass1", "is_leaked": true, "status": "checked" },
    // ... more results or only leaked items
  ]
}`}</code>
                </pre>
              </div>

              <div>
                <h3 className="text-xl font-semibold text-white">
                  Example <code className="text-purple-400">curl</code> Request
                </h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`curl -X POST https://yourdomain.com/api/v1/check/batch \\
     -F "file=@/path/to/your/credentials.txt" \\
     -F "inputType=email_pass"`}</code>
                </pre>
              </div>
            </div>
          </div>

          {/* Endpoint 3: API Status */}
          <div className="mt-12">
            <h2 className="text-2xl font-bold text-white">API Status</h2>
            <div className="mt-4 space-y-4">
              <div className="flex items-center">
                <h3 className="text-xl font-semibold text-white">Path & Method</h3>
                <span className="ml-3 rounded-full bg-blue-600/20 px-2.5 py-0.5 text-xs font-medium text-blue-400">
                  GET
                </span>
              </div>
              <pre className="overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                <code>/status</code>
              </pre>
              <p className="text-gray-300">Returns the current health status of the API.</p>

              <div>
                <h3 className="text-xl font-semibold text-white">Response (Success 200 OK)</h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>{`{
  "status": "healthy",
  "timestamp": "2025-05-07T16:11:06Z",
  "google_api_status": "connected"
}`}</code>
                </pre>
              </div>

              <div>
                <h3 className="text-xl font-semibold text-white">
                  Example <code className="text-purple-400">curl</code> Request
                </h3>
                <pre className="mt-2 overflow-x-auto rounded-md bg-gray-800 p-4 text-sm text-gray-300">
                  <code>curl https://yourdomain.com/api/v1/status</code>
                </pre>
              </div>
            </div>
          </div>
        </section>

        {/* Error Codes Section */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Error Handling</h2>
          <p className="mt-4 text-gray-300">The API uses standard HTTP status codes to indicate success or failure.</p>

          <div className="mt-6 overflow-hidden rounded-lg border border-gray-700">
            <table className="min-w-full divide-y divide-gray-700">
              <thead className="bg-gray-800">
                <tr>
                  <th
                    scope="col"
                    className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-400"
                  >
                    Status Code
                  </th>
                  <th
                    scope="col"
                    className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-400"
                  >
                    Description
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-700 bg-gray-900">
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-green-500">200 OK</td>
                  <td className="px-6 py-4 text-sm text-gray-300">Request successful.</td>
                </tr>
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-yellow-500">400 Bad Request</td>
                  <td className="px-6 py-4 text-sm text-gray-300">
                    Invalid request payload, missing parameters, or validation error. Response body will contain an{" "}
                    <code className="rounded bg-gray-700 px-1 py-0.5 text-purple-400">error</code> field.
                  </td>
                </tr>
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-yellow-500">401 Unauthorized</td>
                  <td className="px-6 py-4 text-sm text-gray-300">
                    (If API keys are implemented) Invalid or missing API key.
                  </td>
                </tr>
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-yellow-500">
                    429 Too Many Requests
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-300">Rate limit exceeded.</td>
                </tr>
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-red-500">
                    500 Internal Server Error
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-300">An unexpected error occurred on the server.</td>
                </tr>
                <tr>
                  <td className="whitespace-nowrap px-6 py-4 text-sm font-medium text-red-500">
                    503 Service Unavailable
                  </td>
                  <td className="px-6 py-4 text-sm text-gray-300">
                    The service is temporarily down or unable to connect to upstream services (e.g., Google's API).
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        {/* Self-Hosting Note */}
        <section className="mt-12 rounded-lg bg-gray-800/50 p-6 backdrop-blur-sm">
          <h3 className="text-xl font-semibold text-white">Self-Hosting the API</h3>
          <p className="mt-2 text-gray-300">
            If you choose to self-host LeakLens, ensure your backend is correctly configured with the necessary Google
            API tokens. Refer to the main project README on GitHub for detailed setup instructions, especially regarding
            OAuth token management for the Google Password Check API.
          </p>
          <div className="mt-4">
            <a
              href="https://github.com/lkeld/leaklens#setup-guide"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center text-purple-500 transition-colors hover:text-purple-400"
            >
              View Setup Guide on GitHub
              <svg
                xmlns="http://www.w3.org/2000/svg"
                className="ml-1 h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
                />
              </svg>
            </a>
          </div>
        </section>
      </div>
    </div>
  )
}
