"use client"

import { useState } from "react"
import { ChevronDown, ChevronUp, Github, ExternalLink } from "lucide-react"

export default function HowItWorksPage() {
  const [mathDetailsOpen, setMathDetailsOpen] = useState(false)

  return (
    <div className="py-12 md:py-16 lg:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
        <h1 className="bg-gradient-to-r from-purple-400 to-blue-500 bg-clip-text text-center text-3xl font-bold tracking-tight text-transparent sm:text-4xl lg:text-5xl">
          The Technology Behind Our Secure Password Checker
        </h1>

        {/* Introduction Section */}
        <section className="mt-8">
          <p className="text-lg leading-relaxed text-gray-300">
            Understanding how we check your passwords without compromising your privacy is key. This page details the
            cryptographic principles and the process involved, inspired by Google&apos;s own privacy-preserving password
            check technology.
          </p>
        </section>

        {/* Core Concepts Section */}
        <section className="mt-12 space-y-12">
          {/* Concept 1: Initial Hashing */}
          <div>
            <h2 className="text-2xl font-bold text-white">Concept 1: Initial Hashing</h2>
            <div className="mt-4 space-y-4">
              <p className="leading-relaxed text-gray-300">
                The first step in our process involves creating a{" "}
                <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">lookup_hash</code> using the{" "}
                <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">scrypt</code> function. This function
                takes your username and password as inputs and produces a cryptographic hash. We use{" "}
                <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">scrypt</code> because it&apos;s
                designed to be computationally intensive, making it resistant to brute-force attacks. The username
                serves as a &quot;salt&quot; to ensure that identical passwords for different users produce different
                hashes.
              </p>
              <p className="leading-relaxed text-gray-300">
                Additionally, we compute a{" "}
                <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">username_hash_prefix</code> by taking
                the first few bytes of the username&apos;s hash. This prefix helps in efficiently querying the database
                of leaked credentials without revealing the complete username.
              </p>
            </div>
          </div>

          {/* Concept 2: Elliptic Curve Cryptography (ECC) Basics */}
          <div>
            <h2 className="text-2xl font-bold text-white">Concept 2: Elliptic Curve Cryptography (ECC) Basics</h2>
            <div className="mt-4 space-y-4">
              <p className="leading-relaxed text-gray-300">
                ECC is a powerful public-key cryptography approach based on the algebraic structure of elliptic curves
                over finite fields. It provides the same level of security as traditional methods like RSA but with
                smaller key sizes, making it more efficient for our purposes.
              </p>
              <div className="space-y-2">
                <h3 className="text-xl font-semibold text-gray-200">Points on a Curve</h3>
                <p className="leading-relaxed text-gray-300">
                  An elliptic curve is a set of points satisfying an equation of the form y² = x³ + ax + b. In
                  cryptography, we use curves defined over finite fields, which means the coordinates are integers
                  within a specific range. The security of ECC relies on the difficulty of the &quot;elliptic curve
                  discrete logarithm problem&quot; — given points P and Q, finding the number k such that Q = kP is
                  computationally hard.
                </p>
              </div>
              <div className="space-y-2">
                <h3 className="text-xl font-semibold text-gray-200">Scalar Multiplication</h3>
                <p className="leading-relaxed text-gray-300">
                  The fundamental operation in ECC is scalar multiplication: multiplying a point on the curve by an
                  integer. This operation is relatively easy to compute in one direction but extremely difficult to
                  reverse, forming the basis of the security in our protocol.
                </p>
              </div>
            </div>
          </div>

          {/* Concept 3: Hashing to the Curve */}
          <div>
            <h2 className="text-2xl font-bold text-white">Concept 3: Hashing to the Curve</h2>
            <div className="mt-4 space-y-4">
              <p className="leading-relaxed text-gray-300">
                The <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">lookup_hash</code> (a string of
                bytes) needs to be transformed into a point on the specific elliptic curve (NIST P-256) used by the
                protocol. This process, called &quot;hashing to the curve,&quot; ensures that the hash value can be used
                in elliptic curve operations.
              </p>
              <p className="leading-relaxed text-gray-300">
                We use a technique known as the &quot;random oracle&quot; model, where the hash function is treated as a
                black box that maps inputs to random-looking outputs on the curve. This mapping must be deterministic
                (same input always gives same output) and uniform (outputs are evenly distributed across the curve).
              </p>
            </div>
          </div>

          {/* Concept 4: Commutative Encryption - The Core Idea */}
          <div>
            <h2 className="text-2xl font-bold text-white">Concept 4: Commutative Encryption - The Core Idea</h2>
            <div className="mt-4 space-y-4">
              <p className="leading-relaxed text-gray-300">
                The heart of our privacy-preserving protocol is commutative encryption. In simple terms, if we encrypt a
                message M with key A, then key B, we get the same result as if we encrypted M with key B, then key A.
                Mathematically, this is expressed as E<sub>A</sub>(E<sub>B</sub>(M)) = E<sub>B</sub>(E<sub>A</sub>(M)).
              </p>
              <div className="space-y-2">
                <h3 className="text-xl font-semibold text-gray-200">The Flow</h3>
                <ol className="ml-5 list-decimal space-y-3 text-gray-300">
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">You enter your username and password.</span> This happens
                    locally in your browser, and the plaintext is never sent over the network.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Your browser computes the{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">lookup_hash</code>.
                    </span>{" "}
                    This is derived from your username and password using the scrypt function.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Our server encrypts this{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">lookup_hash</code> using its
                      secret key (k<sub>S</sub>).
                    </span>{" "}
                    This is done via ECC scalar multiplication, resulting in{" "}
                    <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">encrypted_lookup_hash</code>.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      This{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">encrypted_lookup_hash</code> and
                      the <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">username_hash_prefix</code>{" "}
                      are sent to Google&apos;s API.
                    </span>{" "}
                    Note that what&apos;s sent looks like random data and doesn&apos;t reveal your actual credentials.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Google&apos;s server re-encrypts what it received using its own secret key (k<sub>G</sub>).
                    </span>{" "}
                    This produces E
                    <sub>
                      k<sub>G</sub>
                    </sub>
                    (E
                    <sub>
                      k<sub>S</sub>
                    </sub>
                    (lookup_hash)), which is the{" "}
                    <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">reencrypted_lookup_hash</code>.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Google also returns a list of{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">
                        encrypted_leak_match_prefix
                      </code>{" "}
                      values.
                    </span>{" "}
                    These are prefixes of known leaked credentials, also encrypted with Google&apos;s key (E
                    <sub>
                      k<sub>G</sub>
                    </sub>
                    (leaked_data)).
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Our server receives{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">reencrypted_lookup_hash</code>{" "}
                      and the list of prefixes.
                    </span>
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Our server uses its secret key (k<sub>S</sub>) to &apos;decrypt&apos; one layer of encryption.
                    </span>{" "}
                    Due to commutativity, this results in E
                    <sub>
                      k<sub>G</sub>
                    </sub>
                    (lookup_hash) – your hash, but encrypted with Google&apos;s key.
                  </li>
                  <li className="leading-relaxed">
                    <span className="font-medium text-white">
                      Finally, our server compares this against the{" "}
                      <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">
                        encrypted_leak_match_prefix
                      </code>{" "}
                      values from Google.
                    </span>{" "}
                    A match indicates a leak, but the comparison happens on data that is still encrypted with
                    Google&apos;s key.
                  </li>
                </ol>
              </div>
            </div>
          </div>

          {/* Concept 5: Why This is Secure */}
          <div>
            <h2 className="text-2xl font-bold text-white">Concept 5: Why This is Secure</h2>
            <div className="mt-4 space-y-4">
              <p className="leading-relaxed text-gray-300">
                Google never sees your plaintext password or the initial{" "}
                <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">lookup_hash</code>. It only receives
                data already encrypted by our server. This means Google cannot determine your actual credentials from
                what it receives.
              </p>
              <p className="leading-relaxed text-gray-300">
                Our server never sends your plaintext password to Google. The encryption happens locally in your browser
                or on our server before any data is transmitted to Google&apos;s API.
              </p>
              <p className="leading-relaxed text-gray-300">
                The comparison happens on data that is still encrypted with Google&apos;s secret key. This means that
                even our server cannot see the actual leaked credentials in Google&apos;s database. We only know if
                there&apos;s a match or not.
              </p>
              <p className="leading-relaxed text-gray-300">
                This multi-layered approach ensures that your credentials remain private throughout the entire checking
                process, while still allowing us to verify if they&apos;ve been compromised in known data breaches.
              </p>
            </div>
          </div>
        </section>

        {/* Mathematical Details (Collapsible Section) */}
        <section className="mt-12">
          <button
            onClick={() => setMathDetailsOpen(!mathDetailsOpen)}
            className="flex w-full items-center justify-between rounded-lg bg-gray-800 p-4 text-left text-xl font-bold text-white transition-colors hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
            aria-expanded={mathDetailsOpen}
          >
            <span>Dive Deeper: The Math (Optional)</span>
            {mathDetailsOpen ? <ChevronUp className="h-6 w-6" /> : <ChevronDown className="h-6 w-6" />}
          </button>

          {mathDetailsOpen && (
            <div className="mt-4 rounded-lg bg-gray-800/50 p-6 backdrop-blur-sm">
              <div className="space-y-6">
                <div>
                  <h3 className="text-xl font-semibold text-gray-200">NIST P-256 Curve Parameters</h3>
                  <pre className="mt-2 overflow-x-auto rounded-md bg-gray-900 p-4 text-sm text-gray-300">
                    <code>
                      {`p = 115792089210356248762697446949407573530086143415290314195533631308867097853951
a = 115792089210356248762697446949407573530086143415290314195533631308867097853948
b = 41058363725152142129326129780047268409114441015993725554835256314039467401291
order = 115792089210356248762697446949407573529996955224135760342422259061068512044369
Gx = 48439561293906451759052585252797914202762949526041747007087301480381597091370
Gy = 36134250956634384922349775266865771730475132282434352790334702468324435774573`}
                    </code>
                  </pre>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-gray-200">ECCommutativeCipher</h3>
                  <p className="mt-2 leading-relaxed text-gray-300">
                    <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">encrypt(plaintext_hash)</code>{" "}
                    involves <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">hashToTheCurve</code>{" "}
                    then scalar multiplication (C = key · P). The plaintext hash is first mapped to a point on the
                    curve, then multiplied by the secret key to produce the encrypted point.
                  </p>
                  <p className="mt-2 leading-relaxed text-gray-300">
                    <code className="rounded bg-gray-800 px-1 py-0.5 text-purple-400">decrypt(ciphertext_point)</code>{" "}
                    involves modular inverse of the key (P = inverse(key, order) · ciphertext_point). To decrypt, we
                    multiply the encrypted point by the modular inverse of the key with respect to the curve&apos;s
                    order.
                  </p>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-gray-200">Point Serialization</h3>
                  <p className="mt-2 leading-relaxed text-gray-300">
                    Points on the elliptic curve are serialized in compressed format: 0x02/0x03 + x-coordinate. The
                    leading byte (0x02 or 0x03) indicates whether the y-coordinate is even or odd, allowing the full
                    point to be reconstructed from just the x-coordinate.
                  </p>
                </div>

                <div>
                  <h3 className="text-xl font-semibold text-gray-200">SHA256 Comparison Logic</h3>
                  <p className="mt-2 leading-relaxed text-gray-300">
                    The final comparison between the user&apos;s encrypted hash and Google&apos;s database of leaked
                    credentials involves an additional SHA256 hashing step. This is done to standardize the format for
                    comparison and to further protect the encrypted data.
                  </p>
                  <p className="mt-2 leading-relaxed text-gray-300">
                    The comparison checks if the SHA256 hash of the user&apos;s encrypted credential (after our server
                    removes its layer of encryption) matches any of the prefix hashes in Google&apos;s response. A match
                    indicates that the credential has been found in a known data breach.
                  </p>
                </div>
              </div>
            </div>
          )}
        </section>

        {/* Diagram Placeholder */}
        <section className="mt-12">
          <div className="overflow-hidden rounded-lg border-2 border-dashed border-gray-700 bg-gray-800/30 p-8 text-center">
            <div className="space-y-4">
              <div className="mx-auto max-w-2xl">
                <img 
                  src="/diagram.png" 
                  alt="Data flow and encryption process diagram" 
                  className="w-full rounded-lg shadow-lg"
                />
              </div>
              <p className="text-lg font-medium text-gray-300">
                A visual diagram illustrating the data flow and encryption steps.
              </p>
              <p className="text-sm text-gray-400">
                The diagram shows the complete process from user input to result, highlighting the encryption and
                decryption steps.
              </p>
            </div>
          </div>
        </section>

        {/* Link to GitHub */}
        <section className="mt-12 flex justify-center">
          <a
            href="https://github.com/lkeld/leaklens"
            target="_blank"
            rel="noopener noreferrer"
            className="group inline-flex items-center rounded-md bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-3 text-base font-medium text-white shadow-lg transition-all duration-200 hover:from-purple-700 hover:to-blue-700 hover:shadow-xl focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2 focus:ring-offset-gray-900"
          >
            <Github className="mr-2 h-5 w-5" />
            View Complete Implementation on GitHub
            <ExternalLink className="ml-2 h-4 w-4 opacity-70 transition-opacity group-hover:opacity-100" />
          </a>
        </section>
      </div>
    </div>
  )
}
