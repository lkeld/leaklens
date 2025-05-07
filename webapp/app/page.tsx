import type React from "react"
import Link from "next/link"
import { Shield, Lock, FileCode, Users, ArrowRight, Github } from "lucide-react"

export default function HomePage() {
  return (
    <div className="space-y-24 py-12 md:py-16 lg:py-24">
      {/* Hero Section */}
      <section className="mx-auto max-w-5xl text-center">
        <h1 className="bg-gradient-to-r from-purple-400 to-blue-500 bg-clip-text text-4xl font-bold tracking-tight text-transparent sm:text-5xl lg:text-6xl">
          Securely Check if Your Credentials Have Been Leaked
        </h1>
        <p className="mt-6 text-lg text-gray-300 md:text-xl">
          Leveraging Google&apos;s password check technology, re-engineered for transparency and broader use. Your
          password is never sent to us or Google in plain text.
        </p>
        <div className="mt-10 flex flex-col items-center justify-center space-y-4 sm:flex-row sm:space-x-6 sm:space-y-0">
          <Link
            href="/check-single"
            className="inline-flex items-center justify-center rounded-md bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:from-purple-700 hover:to-blue-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            Check a Single Credential
          </Link>
          <Link
            href="/check-batch"
            className="inline-flex items-center justify-center rounded-md border border-gray-700 bg-gray-800/50 px-6 py-3 text-base font-medium text-gray-200 shadow-lg transition-all duration-200 hover:bg-gray-800 hover:text-white hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            Check a File (Batch)
          </Link>
        </div>
      </section>

      {/* Key Features Section */}
      <section className="mx-auto max-w-6xl">
        <h2 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">Why Choose LeakLens?</h2>
        <div className="mt-12 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <FeatureCard
            icon={<Shield className="h-8 w-8 text-purple-500" />}
            title="Privacy-Preserving Checks"
            description="Your passwords never leave your device in plain text. We use advanced cryptography to ensure your credentials remain secure."
          />
          <FeatureCard
            icon={<Lock className="h-8 w-8 text-purple-500" />}
            title="Advanced ECC Encryption"
            description="We implement Elliptic Curve Cryptography to provide state-of-the-art security for all credential checks."
          />
          <FeatureCard
            icon={<FileCode className="h-8 w-8 text-purple-500" />}
            title="Batch & Single Checks"
            description="Check individual credentials or upload a file to verify multiple entries at once, saving you time and effort."
          />
          <FeatureCard
            icon={<Users className="h-8 w-8 text-purple-500" />}
            title="Open Source & Transparent"
            description="Our entire codebase is open source. Review it yourself to ensure we're handling your data responsibly."
          />
        </div>
      </section>

      {/* How It Works Section */}
      <section className="mx-auto max-w-5xl">
        <h2 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">
          How It Works (Simplified)
        </h2>
        <div className="mt-12 grid gap-8 md:grid-cols-2 lg:grid-cols-4">
          <StepCard
            number="1"
            title="Local Encryption"
            description="You provide credentials that are encrypted locally on your device."
          />
          <StepCard
            number="2"
            title="Secure Communication"
            description="We use advanced cryptography to talk to Google's API."
          />
          <StepCard
            number="3"
            title="Database Check"
            description="Google re-encrypts and checks against its database of leaked credentials."
          />
          <StepCard
            number="4"
            title="Safe Results"
            description="We decrypt the result and show you if it's leaked, all without exposing your password."
          />
        </div>
        <div className="mt-10 text-center">
          <Link
            href="/how-it-works"
            className="inline-flex items-center text-lg font-medium text-purple-500 transition-colors hover:text-purple-400"
          >
            Learn more in detail
            <ArrowRight className="ml-2 h-5 w-5" />
          </Link>
        </div>
      </section>

      {/* Security Pledge Section */}
      <section className="mx-auto max-w-4xl rounded-2xl bg-gray-800/30 p-8 backdrop-blur-sm md:p-12">
        <h2 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">
          Our Commitment to Your Security
        </h2>
        <p className="mt-6 text-center text-lg text-gray-300">
          We are deeply committed to your privacy and security. This tool is built with transparency and robust
          cryptographic principles at its core. Your plaintext passwords are never stored, logged, or transmitted to our
          servers or Google. Explore our code on GitHub to see for yourself.
        </p>
        <div className="mt-8 flex justify-center">
          <a
            href="https://github.com/lkeld/leaklens"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center rounded-md bg-gray-800 px-6 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:bg-gray-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            <Github className="mr-2 h-5 w-5" />
            View on GitHub
          </a>
        </div>
      </section>
    </div>
  )
}

function FeatureCard({ icon, title, description }: { icon: React.ReactNode; title: string; description: string }) {
  return (
    <div className="flex flex-col rounded-xl bg-gray-800/30 p-6 backdrop-blur-sm transition-all duration-300 hover:bg-gray-800/50 hover:shadow-lg">
      <div className="mb-4 rounded-full bg-gray-800 p-3 w-fit">{icon}</div>
      <h3 className="mb-2 text-xl font-semibold text-white">{title}</h3>
      <p className="text-gray-400">{description}</p>
    </div>
  )
}

function StepCard({ number, title, description }: { number: string; title: string; description: string }) {
  return (
    <div className="relative flex flex-col items-center rounded-xl bg-gray-800/30 p-6 text-center backdrop-blur-sm transition-all duration-300 hover:bg-gray-800/50 hover:shadow-lg">
      <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-gradient-to-r from-purple-600 to-blue-600 text-xl font-bold text-white">
        {number}
      </div>
      <h3 className="mb-2 text-xl font-semibold text-white">{title}</h3>
      <p className="text-gray-400">{description}</p>
    </div>
  )
}
