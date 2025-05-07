"use client"

export default function PrivacyPolicyPage() {
  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <h1 className="text-center text-3xl font-bold tracking-tight text-white sm:text-4xl">Privacy Policy</h1>
        <p className="mt-4 text-center text-gray-400">Last Updated: May 7, 2025</p>

        {/* Introduction */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Introduction</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            Welcome to LeakLens (&apos;we&apos;, &apos;us&apos;, &apos;our&apos;). We are committed to protecting your
            privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you
            visit our website [YourDomain.com] and use our credential checking service (the &apos;Service&apos;). Please
            read this privacy policy carefully. If you do not agree with the terms of this privacy policy, please do not
            access the site or use the Service.
          </p>
        </section>

        {/* Information We Collect */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Information We Collect</h2>

          <div className="mt-6">
            <h3 className="text-xl font-semibold text-gray-100">Credentials for Checking</h3>
            <p className="mt-3 leading-relaxed text-gray-300">
              When you use our Service to check a single credential or upload a file for a batch check, you provide
              usernames/emails and passwords. These credentials are processed as follows:
            </p>
            <ul className="mt-3 list-inside list-disc space-y-2 text-gray-300">
              <li>
                Plaintext passwords are <strong className="font-semibold text-white">never</strong> stored or logged by
                our systems.
              </li>
              <li>
                For the check, your username and password are used to compute a cryptographic hash (e.g., using scrypt).
              </li>
              <li>This hash is then encrypted by our server using Elliptic Curve Commutative Cryptography.</li>
              <li>
                Only this encrypted hash (and a username hash prefix) is sent to Google&apos;s API for the leak check.
              </li>
              <li>
                Uploaded files for batch checks are processed in memory and are deleted immediately after the checking
                process is complete. They are not stored persistently on our servers.
              </li>
            </ul>
          </div>

          <div className="mt-6">
            <h3 className="text-xl font-semibold text-gray-100">Usage Data</h3>
            <p className="mt-3 leading-relaxed text-gray-300">
              We may automatically collect certain information when you access the Site or use the Service, such as your
              IP address (primarily for rate limiting and security purposes, stored temporarily and anonymized where
              possible), browser type, operating system, access times, and the pages you have viewed directly before and
              after accessing the Site. This data is used to maintain the quality of the Service and to provide general
              statistics regarding use of the LeakLens website.
            </p>
          </div>

          <div className="mt-6">
            <h3 className="text-xl font-semibold text-gray-100">Cookies</h3>
            <p className="mt-3 leading-relaxed text-gray-300">
              We may use cookies and similar tracking technologies to help customize the Site and improve your
              experience. We use Plausible Analytics for privacy-respecting website analytics, which does not track
              users across websites or over time. You are free to decline our cookies if your browser permits, but some
              parts of our Site may not work properly for you.
            </p>
          </div>
        </section>

        {/* How We Use Your Information */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">How We Use Your Information</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            Having accurate information permits us to provide you with a smooth, efficient, and customized experience.
            Specifically, we may use information collected about you via the Site or Service to:
          </p>
          <ul className="mt-3 list-inside list-disc space-y-2 text-gray-300">
            <li>Provide and operate the credential checking Service.</li>
            <li>Monitor and analyze usage and trends to improve your experience with the Site and Service.</li>
            <li>
              Prevent fraudulent activity and ensure the security of our Site and Service (e.g., through rate limiting
              based on IP addresses).
            </li>
            <li>Respond to your comments or inquiries (if you contact us).</li>
          </ul>
        </section>

        {/* Disclosure of Your Information */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Disclosure of Your Information</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            We do not sell, trade, rent, or otherwise share your personal information for marketing purposes.
          </p>

          <div className="mt-6">
            <h3 className="text-xl font-semibold text-gray-100">To Google&apos;s API</h3>
            <p className="mt-3 leading-relaxed text-gray-300">
              As described in our &apos;How It Works&apos; section, to perform the leak check, we send a
              cryptographically transformed (encrypted) version of your credential hash and a username hash prefix to
              Google&apos;s Password Check API. Google does not receive your plaintext password or the initial
              unencrypted hash from us.
            </p>
          </div>

          <div className="mt-6">
            <h3 className="text-xl font-semibold text-gray-100">By Law or to Protect Rights</h3>
            <p className="mt-3 leading-relaxed text-gray-300">
              If we believe the release of information about you is necessary to respond to legal process, to
              investigate or remedy potential violations of our policies, or to protect the rights, property, and safety
              of others, we may share your information as permitted or required by any applicable law, rule, or
              regulation.
            </p>
          </div>
        </section>

        {/* Data Security */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Data Security</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            We use administrative, technical, and physical security measures to help protect your information. While we
            have taken reasonable steps to secure the information you provide to us, please be aware that despite our
            efforts, no security measures are perfect or impenetrable, and no method of data transmission can be
            guaranteed against any interception or other type of misuse. All communication with our website is encrypted
            via HTTPS.
          </p>
        </section>

        {/* Data Retention */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Data Retention</h2>
          <p className="mt-4 leading-relaxed text-gray-300">We retain information as follows:</p>
          <ul className="mt-3 list-inside list-disc space-y-2 text-gray-300">
            <li>Credentials submitted for checking and uploaded files: Not retained after processing.</li>
            <li>
              IP Addresses for rate limiting/security: Retained for a short period (e.g., 7 days) and then anonymized or
              deleted.
            </li>
            <li>Anonymized usage statistics: May be retained indefinitely for trend analysis.</li>
          </ul>
        </section>

        {/* Your Rights */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Your Rights</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            Depending on your location, you may have certain rights regarding your personal information, such as the
            right to access, correct, or delete your data. If you are a resident of the European Economic Area (EEA),
            you have rights under the General Data Protection Regulation (GDPR). If you are a California resident, you
            have rights under the California Consumer Privacy Act (CCPA).
          </p>
          <p className="mt-3 leading-relaxed text-gray-300">
            Given the minimal data we collect and our data retention policies, most of these rights are automatically
            fulfilled. If you have specific questions about your data or wish to exercise any of your rights, please
            contact us using the information provided in the &quot;Contact Us&quot; section.
          </p>
        </section>

        {/* Children's Privacy */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Children&apos;s Privacy</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            Our Service is not intended for use by children under the age of 16. We do not knowingly collect personal
            information from children under this age. If you are a parent or guardian and you are aware that your child
            has provided us with personal information, please contact us so that we can take necessary actions.
          </p>
        </section>

        {/* Changes to This Privacy Policy */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Changes to This Privacy Policy</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new
            Privacy Policy on this page and updating the &apos;Last Updated&apos; date. You are advised to review this
            Privacy Policy periodically for any changes.
          </p>
        </section>

        {/* Contact Us */}
        <section className="mt-12">
          <h2 className="text-2xl font-bold text-white">Contact Us</h2>
          <p className="mt-4 leading-relaxed text-gray-300">
            If you have questions or comments about this Privacy Policy, please contact us at:{" "}
            <a
              href="mailto:privacy@yourdomain.com"
              className="text-purple-500 transition-colors hover:text-purple-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
            >
              privacy@yourdomain.com
            </a>{" "}
            or open an issue on our{" "}
            <a
              href="https://github.com/lkeld/leaklens/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="text-purple-500 transition-colors hover:text-purple-400 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
            >
              GitHub repository
            </a>
            .
          </p>
        </section>

        {/* Back to top button */}
        <div className="mt-16 flex justify-center">
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
            className="inline-flex items-center rounded-md border border-gray-700 bg-gray-800 px-4 py-2 text-sm font-medium text-gray-300 shadow-sm transition-colors hover:bg-gray-700 hover:text-white focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
            aria-label="Scroll to top"
          >
            Back to top
          </button>
        </div>
      </div>
    </div>
  )
}
