import Link from "next/link"

export default function NotFoundPage() {
  return (
    <div className="flex min-h-[calc(100vh-80px)] flex-col items-center justify-center px-4 py-16 text-center">
      <div className="max-w-md">
        <h1 className="bg-gradient-to-r from-purple-400 to-blue-500 bg-clip-text text-8xl font-bold text-transparent">
          404
        </h1>
        <h2 className="mt-6 text-3xl font-semibold tracking-tight text-white">Page Not Found</h2>
        <p className="mt-4 text-gray-400">
          Oops! The page you&apos;re looking for doesn&apos;t seem to exist. Maybe it was moved, or you mistyped the
          URL.
        </p>
        <div className="mt-8">
          <Link
            href="/"
            className="inline-flex items-center justify-center rounded-md bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:from-purple-700 hover:to-blue-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            Go to Homepage
          </Link>
        </div>
        <div className="relative mt-12">
          <div className="absolute inset-0 flex items-center" aria-hidden="true">
            <div className="w-full border-t border-gray-800"></div>
          </div>
          <div className="relative flex justify-center">
            <span className="bg-gray-900 px-4 text-sm text-gray-500">or try another page</span>
          </div>
        </div>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <Link
            href="/check-single"
            className="rounded-md border border-gray-700 bg-gray-800/50 px-4 py-2 text-sm font-medium text-gray-300 transition-colors hover:bg-gray-800 hover:text-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            Check Single Credential
          </Link>
          <Link
            href="/check-batch"
            className="rounded-md border border-gray-700 bg-gray-800/50 px-4 py-2 text-sm font-medium text-gray-300 transition-colors hover:bg-gray-800 hover:text-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            Check Batch Credentials
          </Link>
          <Link
            href="/how-it-works"
            className="rounded-md border border-gray-700 bg-gray-800/50 px-4 py-2 text-sm font-medium text-gray-300 transition-colors hover:bg-gray-800 hover:text-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            How It Works
          </Link>
        </div>
      </div>
    </div>
  )
}
