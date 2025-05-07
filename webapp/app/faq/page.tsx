"use client"

import type React from "react"

import { useState } from "react"
import Link from "next/link"
import { ChevronDown } from "lucide-react"

interface FAQItem {
  id: string
  question: string
  answer: React.ReactNode
}

export default function FAQPage() {
  const [openItems, setOpenItems] = useState<Record<string, boolean>>({
    q1: true, // Open the first question by default
  })

  const toggleItem = (id: string) => {
    setOpenItems((prev) => ({
      ...prev,
      [id]: !prev[id],
    }))
  }

  const faqItems: FAQItem[] = [
    {
      id: "q1",
      question: "Is this service free to use?",
      answer: (
        <p>
          Yes, LeakLens is currently free for individual use. For extensive API use or commercial applications, please
          refer to our{" "}
          <Link href="/api-docs" className="text-purple-500 hover:text-purple-400 focus:outline-none focus:underline">
            API documentation
          </Link>{" "}
          or contact us.
        </p>
      ),
    },
    {
      id: "q2",
      question: "How is this secure? Is my password sent anywhere?",
      answer: (
        <div className="space-y-4">
          <p>
            Your security is our top priority. Your plaintext password is{" "}
            <strong className="font-semibold text-white">never</strong> sent to our servers or to Google. The check
            involves multiple layers of encryption:
          </p>
          <ol className="ml-5 list-decimal space-y-2">
            <li>Your password (combined with username) is first hashed locally (e.g., using scrypt).</li>
            <li>
              This hash is then encrypted by our server using Elliptic Curve Commutative Cryptography before being sent
              to Google&apos;s API.
            </li>
            <li>Google re-encrypts this data and performs its checks.</li>
            <li>
              The result is returned to our server, which then decrypts its layer of encryption to determine the leak
              status.
            </li>
          </ol>
          <p>
            Read our{" "}
            <Link
              href="/how-it-works"
              className="text-purple-500 hover:text-purple-400 focus:outline-none focus:underline"
            >
              How It Works
            </Link>{" "}
            page for a detailed explanation.
          </p>
        </div>
      ),
    },
    {
      id: "q3",
      question: "What data do you log or store?",
      answer: (
        <div className="space-y-4">
          <p>
            We are committed to minimizing data collection. We{" "}
            <strong className="font-semibold text-white">do not</strong> log or store the usernames or passwords you
            check. Uploaded files for batch checks are processed in memory and discarded immediately after the check is
            complete.
          </p>
          <p>
            We may log anonymized IP addresses for rate limiting and to prevent abuse. For more details, please see our{" "}
            <Link
              href="/privacy-policy"
              className="text-purple-500 hover:text-purple-400 focus:outline-none focus:underline"
            >
              Privacy Policy
            </Link>
            .
          </p>
        </div>
      ),
    },
    {
      id: "q4",
      question: "Is LeakLens affiliated with Google?",
      answer: (
        <p>
          No, LeakLens is an independent, open-source project. It utilizes a publicly accessible API endpoint that
          Google Chrome uses for its password check feature, which we have reverse-engineered for this tool. It is not
          endorsed by, affiliated with, or supported by Google.
        </p>
      ),
    },
    {
      id: "q5",
      question: "What should I do if my credentials are found to be leaked?",
      answer: (
        <div className="space-y-4">
          <p>If LeakLens indicates your credentials have been leaked, you should:</p>
          <ol className="ml-5 list-decimal space-y-2">
            <li>Immediately change your password on the affected account.</li>
            <li>
              Change the password on <strong className="font-semibold text-white">any other accounts</strong> where you
              might have used the same or a similar password.
            </li>
            <li>Use a strong, unique password for every account. Consider using a password manager.</li>
            <li>Enable Two-Factor Authentication (2FA) or Multi-Factor Authentication (MFA) wherever available.</li>
          </ol>
        </div>
      ),
    },
    {
      id: "q6",
      question: "How does the 'email only' batch check work?",
      answer: (
        <p>
          The core cryptographic check with Google&apos;s API, as reverse-engineered, requires both a username and a
          password to generate the necessary encrypted hashes. If you upload a file with &apos;email only&apos; lines
          for a batch check, these lines will be skipped. We recommend providing username:password pairs for the most
          accurate results based on this specific API.
        </p>
      ),
    },
    {
      id: "q7",
      question: "What are the limitations of this service?",
      answer: (
        <div className="space-y-4">
          <p>While we strive for accuracy, LeakLens has limitations:</p>
          <ol className="ml-5 list-decimal space-y-2">
            <li>
              It relies on Google&apos;s Password Check API endpoint and its dataset of known breaches. This dataset is
              extensive but not exhaustive of all breaches ever.
            </li>
            <li>
              The availability and behavior of the underlying Google API could change without notice, potentially
              affecting this service.
            </li>
            <li>There are rate limits in place for API usage to ensure fair access and prevent abuse.</li>
          </ol>
        </div>
      ),
    },
    {
      id: "q8",
      question: "Can I run this LeakLens service myself?",
      answer: (
        <p>
          LeakLens is an open-source project. You can find the complete source code for both the frontend and backend on
          our{" "}
          <a
            href="https://github.com/lkeld/leaklens"
            target="_blank"
            rel="noopener noreferrer"
            className="text-purple-500 hover:text-purple-400 focus:outline-none focus:underline"
          >
            GitHub repository
          </a>
          , along with instructions for self-hosting.
        </p>
      ),
    },
    {
      id: "q9",
      question: "Where can I find the source code?",
      answer: (
        <p>
          The entire project is open source. You can view the code, contribute, or raise issues on our{" "}
          <a
            href="https://github.com/lkeld/leaklens"
            target="_blank"
            rel="noopener noreferrer"
            className="text-purple-500 hover:text-purple-400 focus:outline-none focus:underline"
          >
            GitHub repository
          </a>
          .
        </p>
      ),
    },
  ]

  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <h1 className="bg-gradient-to-r from-purple-400 to-blue-500 bg-clip-text text-center text-3xl font-bold tracking-tight text-transparent sm:text-4xl lg:text-5xl">
          Frequently Asked Questions
        </h1>

        <div className="mt-8 space-y-4">
          {faqItems.map((item) => (
            <div
              key={item.id}
              className="overflow-hidden rounded-lg border border-gray-800 bg-gray-900 shadow-sm transition-all duration-200 hover:border-gray-700"
            >
              <button
                onClick={() => toggleItem(item.id)}
                className="flex w-full items-center justify-between px-6 py-4 text-left focus:outline-none focus:ring-2 focus:ring-inset focus:ring-purple-500"
                aria-expanded={openItems[item.id] || false}
                aria-controls={`faq-answer-${item.id}`}
              >
                <h2 className="text-lg font-medium text-white">{item.question}</h2>
                <ChevronDown
                  className={`h-5 w-5 text-gray-400 transition-transform duration-200 ${
                    openItems[item.id] ? "rotate-180 transform" : ""
                  }`}
                />
              </button>
              <div
                id={`faq-answer-${item.id}`}
                className={`overflow-hidden transition-all duration-300 ${
                  openItems[item.id] ? "max-h-[1000px] opacity-100" : "max-h-0 opacity-0"
                }`}
                aria-hidden={!openItems[item.id]}
              >
                <div className="border-t border-gray-800 bg-gray-800/50 px-6 py-4 text-gray-300">{item.answer}</div>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-12 rounded-lg bg-gray-800/30 p-6 text-center backdrop-blur-sm">
          <h2 className="text-xl font-semibold text-white">Still have questions?</h2>
          <p className="mt-2 text-gray-300">
            If you couldn&apos;t find the answer to your question, feel free to reach out to us.
          </p>
          <div className="mt-4">
            <a
              href="https://github.com/lkeld/leaklens/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center justify-center rounded-md bg-gradient-to-r from-purple-600 to-blue-600 px-4 py-2 text-sm font-medium text-white shadow-sm transition-all hover:from-purple-700 hover:to-blue-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
            >
              Open an Issue on GitHub
            </a>
          </div>
        </div>
      </div>
    </div>
  )
}
