"use client"

import type React from "react"

import Link from "next/link"
import { useState, useEffect } from "react"
import { Menu, X } from "lucide-react"
import { ApiStatus } from "./api-status"

export default function MainLayout({ children }: { children: React.ReactNode }) {
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const [currentYear, setCurrentYear] = useState("")

  useEffect(() => {
    setCurrentYear(new Date().getFullYear().toString())
  }, [])

  const navLinks = [
    { name: "Home", href: "/" },
    { name: "Check Single", href: "/check-single" },
    { name: "Check Batch", href: "/check-batch" },
    { name: "How It Works", href: "/how-it-works" },
    { name: "API Docs", href: "/api-docs" },
    { name: "FAQ", href: "/faq" },
  ]

  const footerLinks = [
    { name: "Privacy Policy", href: "/privacy-policy" },
    { name: "GitHub Repository", href: "https://github.com/lkeld/leaklens" },
  ]

  return (
    <div className="flex min-h-screen flex-col">
      {/* Navbar */}
      <header className="sticky top-0 z-50 border-b border-gray-800 bg-gray-900/95 backdrop-blur supports-[backdrop-filter]:bg-gray-900/80">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
          {/* Logo */}
          <Link
            href="/"
            className="flex items-center text-xl font-bold text-white transition-colors hover:text-purple-500"
          >
            <span className="bg-gradient-to-r from-purple-500 to-blue-500 bg-clip-text text-transparent">LeakLens</span>
          </Link>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex md:items-center md:space-x-8">
            <ul className="flex space-x-8">
              {navLinks.map((link) => (
                <li key={link.name}>
                  <Link
                    href={link.href}
                    className="text-sm font-medium text-gray-300 transition-colors hover:text-purple-500"
                  >
                    {link.name}
                  </Link>
                </li>
              ))}
            </ul>
            
            {/* API Status in navbar (desktop only) */}
            <div className="ml-4">
              <ApiStatus />
            </div>
          </nav>

          {/* Mobile Menu Button */}
          <button
            type="button"
            className="inline-flex items-center justify-center rounded-md p-2 text-gray-400 hover:bg-gray-800 hover:text-white focus:outline-none focus:ring-2 focus:ring-inset focus:ring-purple-500 md:hidden"
            aria-expanded="false"
            onClick={() => setIsMenuOpen(!isMenuOpen)}
          >
            <span className="sr-only">Open main menu</span>
            {isMenuOpen ? (
              <X className="block h-6 w-6" aria-hidden="true" />
            ) : (
              <Menu className="block h-6 w-6" aria-hidden="true" />
            )}
          </button>
        </div>

        {/* Mobile Navigation */}
        {isMenuOpen && (
          <div className="md:hidden">
            <div className="space-y-1 px-2 pb-3 pt-2">
              {navLinks.map((link) => (
                <Link
                  key={link.name}
                  href={link.href}
                  className="block rounded-md px-3 py-2 text-base font-medium text-gray-300 hover:bg-gray-800 hover:text-white"
                  onClick={() => setIsMenuOpen(false)}
                >
                  {link.name}
                </Link>
              ))}
              
              {/* API Status in mobile menu */}
              <div className="mt-2 px-3 py-2">
                <ApiStatus />
              </div>
            </div>
          </div>
        )}
      </header>

      {/* Main Content */}
      <main className="flex-grow px-4 py-8 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-7xl">{children}</div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-800 bg-gray-900 py-8">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center justify-between space-y-6 md:space-y-4">
            {/* Footer Links */}
            <div className="flex flex-col items-center justify-between space-y-4 md:flex-row md:space-y-0 w-full">
              <p className="text-sm text-gray-500">Copyright © {currentYear} LeakLens. All rights reserved.</p>
              <div className="flex flex-wrap justify-center gap-4">
                {footerLinks.map((link) => (
                  <Link
                    key={link.name}
                    href={link.href}
                    className="text-sm text-gray-500 transition-colors hover:text-purple-500"
                    target={link.href.startsWith("http") ? "_blank" : undefined}
                    rel={link.href.startsWith("http") ? "noopener noreferrer" : undefined}
                  >
                    {link.name}
                  </Link>
                ))}
                <span className="text-sm text-gray-500">Disclaimer: Not affiliated with Google. Use responsibly.</span>
              </div>
            </div>
          </div>
        </div>
      </footer>
    </div>
  )
}
