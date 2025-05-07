# LeakLens: Secure Credential Leak Checker

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/yourusername/leaklens)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0-blue)](https://github.com/yourusername/leaklens)

**LeakLens** is a powerful tool that allows users to securely check if their credentials (username/password pairs) have been compromised in known data breaches. It achieves this by interacting with a Google API endpoint (used by Chrome's password checkup feature) that was reverse-engineered for this project. The core principle is privacy: your plaintext password is never sent to LeakLens's server (if self-hosting) or to Google. All checks are performed using advanced cryptographic techniques, specifically Elliptic Curve Commutative Encryption.

**[Link to Live Demo (if you deploy one)]**

## Features

*   **Privacy-Preserving Checks:** Utilizes Elliptic Curve Commutative Encryption to ensure your plaintext password is never exposed to Google or the LeakLens server during the check.
*   **Reverse-Engineered Protocol:** Implements the client-side logic for Google's internal password leak detection API.
*   **Single Credential Check:** Quickly check an individual username/password pair.
*   **Batch Credential Check:** Upload a file (`.txt`) containing multiple credentials (e.g., `username:password` per line) for bulk checking.
*   **Open Source:** Fully transparent codebase available for audit and contribution.
*   **Rust Backend:** High-performance and secure API built in Rust.
*   **React Frontend:** Modern and user-friendly web interface.
*   **Detailed Documentation:** Comprehensive explanation of the underlying cryptography and protocol.

## ⚠️ Warning & Disclaimer

*   **Reverse-Engineered API:** This project interacts with an API that was reverse-engineered from Google Chrome's source code and network traffic. Google may change or disable this API endpoint at any time without notice, which could render this tool non-functional.
*   **Not Affiliated with Google:** LeakLens is an independent project and is not endorsed by, affiliated with, or supported by Google LLC.
*   **Use Responsibly:** This tool is intended for legitimate security auditing purposes only. Ensure you have authorization to check any credentials.
*   **Token Acquisition:** The method for acquiring Google API tokens for the backend (especially the refresh token) can be complex and may involve techniques (like MITM proxying for initial token capture) that should be understood thoroughly. For a self-hosted public service, robust and legitimate token management is crucial and may require adherence to Google's OAuth policies for server-to-server applications if permissible for this specific API.

## How It Works (Technical Overview)

LeakLens leverages a sophisticated cryptographic protocol to check for leaked credentials without compromising user privacy. Here's a simplified flow:

1.  **User Input:** You provide a username and password (or a file of them).
2.  **Initial Hashing (Client-Side or LeakLens Server):**
    *   The `username` is hashed to produce a `username_hash_prefix` (a 26-bit prefix of a salted SHA256 hash).
    *   The `username` and `password` are combined and hashed using `scrypt` (a memory-hard, salted key derivation function) to produce a `lookup_hash`.
3.  **Hashing to Elliptic Curve:** The `lookup_hash` is deterministically mapped to a point \(P\) on the NIST P-256 elliptic curve.
4.  **First Encryption (LeakLens Server):** The LeakLens server, holding its own private ECC key (\(k_S\)), encrypts the point \(P\) by performing scalar multiplication: \(E_S = k_S \cdot P\).
5.  **Request to Google:** The `username_hash_prefix` and the encrypted point \(E_S\) (`encrypted_lookup_hash`) are sent to Google's API.
6.  **Second Encryption (Google's Server):** Google's server, holding its private ECC key (\(k_G\)), further encrypts the point it receives: \(E_{GS} = k_G \cdot E_S = k_G \cdot k_S \cdot P\). This is returned as `reencrypted_lookup_hash`. Google also returns `encrypted_leak_match_prefix` values, which are prefixes of SHA256 hashes of known leaked credentials, also encrypted with Google's key (e.g., prefixes of \(\text{SHA256}(\text{serialize}(k_G \cdot L_j))\) where \(L_j\) is a point representing a leaked credential).
7.  **Decryption & Comparison (LeakLens Server):**
    *   The LeakLens server uses its private key \(k_S\) to "decrypt" (undo its layer of encryption) the `reencrypted_lookup_hash`: \(D_S(E_{GS}) = k_S^{-1} \cdot (k_G \cdot k_S \cdot P)\). Due to the commutative property of the ECC operations over a common base point, this simplifies to \(k_G \cdot P\). Let this resulting point be \(P_G\).
    *   The server then serializes \(P_G\) (accounting for both possible y-coordinate parities) and computes their SHA256 hashes.
    *   These computed SHA256 hash prefixes are compared against the `encrypted_leak_match_prefix` values received from Google. A match indicates that the original credential is part of a known leak dataset accessible to Google.

This commutative encryption scheme ensures that Google never sees the user's `lookup_hash` (and thus, nothing directly derivable from the password without \(k_S\)), and the LeakLens server never sees Google's private key \(k_G\).

## Technology Stack

*   **Backend:** Rust (using [Actix Web/Axum/Rocket - *specify your choice*])
*   **Frontend:** React, JavaScript/TypeScript
*   **Cryptography:**
    *   Elliptic Curve Cryptography: NIST P-256
    *   Hashing: SHA256, scrypt
    *   Protocol Buffers (for Google API interaction)
*   **Build Tools:** Cargo (Rust), Node.js/npm (or yarn)

## Project Structure

The project is organized into two main parts:

*   `api_server/`: The Rust backend providing the API endpoints.
    *   `src/main.rs`: Server entry point.
    *   `src/api/`: Route handlers.
    *   `src/services/`: Core logic for leak checking and Google API interaction.
    *   `src/crypto/`: Implementation of `ECCommutativeCipher` and hashing utilities.
    *   `proto/`: Protocol Buffer definitions for Google's API.
*   `webapp/`: The React frontend for user interaction.
    *   `src/App.js`: Main application component and routing.
    *   `src/pages/`: Page components (Home, Check Single, Check Batch, etc.).
    *   `src/components/`: Reusable UI elements.
    *   `src/services/apiService.js`: Functions for calling the backend API.

## Getting Started / Installation (for Self-Hosting)

To run LeakLens locally or on your own server:

**Prerequisites:**

*   Rust and Cargo: [https://www.rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)
*   Node.js and npm (or yarn): [https://nodejs.org/](https://nodejs.org/)
*   Protobuf compiler (`protoc`): (if you need to regenerate protobuf code)

**1. Backend (`api_server/`)**

```bash
git clone https://github.com/yourusername/leaklens.git
cd leaklens/api_server

# 1.1. Environment Configuration (CRITICAL)
# Copy the example environment file
cp .env.example .env

# Edit .env and provide the necessary Google API credentials.
# Specifically, you need a valid Google OAuth REFRESH_TOKEN that has
# the "https://www.googleapis.com/auth/identity.passwords.leak.check" scope.
#
# Obtaining this refresh_token for server-side use can be complex.
# The provided `proxy.py` (in the original Python exploration code)
# demonstrates one method to intercept this token from a browser session
# using a MITM proxy. This method is suitable for development/personal use.
#
# For a production server intended for public use, you would ideally
# register an OAuth client with Google and follow a server-to-server
# OAuth flow if Google's terms for this specific API permit it.
# This aspect requires careful consideration of Google's API ToS.
#
# Set the following in .env:
# GOOGLE_CLIENT_ID="77185425430.apps.googleusercontent.com" (This is Chrome's public client ID)
# GOOGLE_CLIENT_SECRET="OTJgUOQcT7lO7GsGZq2G4IlT" (Chrome's public client secret)
# GOOGLE_REFRESH_TOKEN="your_captured_refresh_token"

# 1.2. (Optional) Generate Protobuf Rust code (if .proto changes)
# You'll need protoc and the Rust protobuf plugin.
# cargo build --features=generate_protobuf # (Example, adapt to your build script)

# 1.3. Build and Run
cargo build --release
cargo run --release
```

The API server should now be running (typically on `http://localhost:8000` or as configured).

**2. Frontend (`webapp/`)**

```bash
cd ../webapp # From the api_server directory, or cd leaklens/webapp from root

# Install dependencies
npm install
# or
# yarn install

# Configure API endpoint (if not default)
# Create a .env.local file in the webapp directory and set:
# REACT_APP_API_BASE_URL=http://localhost:8000/api/v1

# Start the development server
npm start
# or
# yarn start
```

The React application should now be accessible (typically on `http://localhost:3000`).

## API Reference

The LeakLens backend exposes a RESTful API for checking credentials.

*   **Base URL:** `/api/v1` (configurable)

**Endpoints:**

1.  **`POST /api/v1/check/single`**: Checks a single username/password.
    *   **Request Body:** `{"username": "user@example.com", "password": "password123"}`
    *   **Response:** `{"username": "user@example.com", "is_leaked": true/false, "message": "..."}`
2.  **`POST /api/v1/check/batch`**: Checks credentials from an uploaded `.txt` file.
    *   **Request:** `multipart/form-data` with a `file` field.
    *   **Response:** Summary and list of results.
3.  **`GET /api/v1/status`**: Health check for the API.

For detailed API documentation, including request/response schemas and examples, please see the [API Documentation Page on the hosted webapp](#) or [API_DOCS.md](API_DOCS.md) (if you create one).

## The Math & Cryptography (In-Depth)

This section details the cryptographic operations underpinning LeakLens, based on the reverse-engineered protocol.

**1. The Privacy Challenge in Password Checking**
The goal is to check if a user's password (or a hash derived from it) exists in a database of leaked credentials without revealing the password itself to the database holder (Google, in this case).

**2. Elliptic Curve Cryptography (ECC) Fundamentals**
*   **Curve:** NIST P-256 (also known as `secp256r1`). Defined by the equation \(y^2 \equiv x^3 + ax + b \pmod p\).
    *   `p = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff`
    *   `a = 0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc`
    *   `b = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b`
*   **Operations:** Points on the curve form a group under an addition operation. Scalar multiplication (\(k \cdot P\)) involves adding a point \(P\) to itself \(k\) times. This is a one-way function: easy to compute \(k \cdot P\) given \(k\) and \(P\), but hard to find \(k\) given \(P\) and \(k \cdot P\) (the Elliptic Curve Discrete Logarithm Problem - ECDLP).
*   **Order:** The number of points in the group, denoted `order`. For NIST P-256:
    *   `order = 0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551`

**3. Initial Credential Processing**
*   **`username_hash_prefix(username)`:**
    1.  A fixed salt (`username_salt`) is appended to the username.
    2.  The result is hashed with SHA256.
    3.  The first 4 bytes of this SHA256 hash are taken.
    4.  The last 6 bits of the 4th byte are masked out, resulting in a 26-bit prefix (`3 bytes + 2 bits`). This is likely used by Google for sharding or indexing.
*   **`scrypt_hash_username_and_password(username, password)` -> `lookup_hash`:**
    1.  A `password_salt` is appended to the `username` to form the scrypt salt.
    2.  The `password` is appended to the `username` to form the scrypt input.
    3.  `scrypt` is applied with parameters `N=4096, r=8, p=1`, producing a 32-byte hash. This `lookup_hash` is the input for the ECC operations.

**4. Hashing to the Curve (`hashToTheCurve(lookup_hash)`)**
The 32-byte `lookup_hash` needs to be converted into a valid point \((x, y)\) on the NIST P-256 curve.
1.  The `lookup_hash` (after stripping any null bytes) is processed by a `random_oracle` function.
2.  **`random_oracle(data, max_value)`:**
    *   This function iteratively hashes the input `data` (prefixed with an iteration counter `i`) using SHA256.
    *   The outputs of SHA256 are concatenated and truncated to produce an integer `x_candidate` modulo `max_value` (which is `p`, the curve's prime field).
3.  The `x_candidate` is used as the x-coordinate. The curve equation \(y^2 = x^3 + ax + b \pmod p\) is solved for \(y\).
    *   If \(x^3 + ax + b\) is a quadratic residue modulo \(p\), two square roots for \(y\) exist (\(y_0\) and \(-y_0 \pmod p\)).
    *   A specific root is chosen based on its parity (e.g., the even root, or the odd root if the even one doesn't meet a condition, as seen in the Python code `if (sqrt & 1 == 1): return Point(mod_x, (-sqrt) % p, self.cv)`).
    *   If no square root exists (i.e., \(x^3 + ax + b\) is not a quadratic residue), the `x_candidate` is re-hashed using `random_oracle` (with `x_candidate` itself as input) and the process repeats until a valid point is found.
4.  The result is a point \(P = (x, y)\) on the curve.

**5. The Commutative Cipher (`ECCommutativeCipher`)**
This cipher relies on the property that for scalar multiplications on an elliptic curve, the order does not matter if the operations are done sequentially by different parties using the same base point that results from the previous operation: \(k_A \cdot (k_B \cdot P) = k_B \cdot (k_A \cdot P)\) is not what's used. Rather, it's \(k_A \cdot (k_B \cdot P) = (k_A k_B) \cdot P\). The "commutative" aspect here refers to the overall protocol where Google can re-encrypt what you encrypted, and you can then decrypt your layer, effectively leaving Google's encryption.

*   **Key:** A random integer `key` ( \(k_S\) for LeakLens server) between 1 and `order-1`.
*   **Encryption (`encrypt(lookup_hash)`):**
    1.  `P = hashToTheCurve(lookup_hash)`
    2.  `EncryptedPoint = key * P` (scalar multiplication).
    3.  The `EncryptedPoint` is serialized into bytes: a prefix byte (`0x02` or `0x03` indicating y-parity for point compression) followed by the 32-byte x-coordinate. This is `encrypted_lookup_hash`.
*   **Decryption (`decrypt(serialized_encrypted_point)`):**
    1.  The point is deserialized from the byte string (recovering `y` from `x` and the parity byte). Let this be `C_point`.
    2.  The decryption key is `dec_key = inverse(key, order)` (modular multiplicative inverse of the private key).
    3.  `DecryptedOriginalPoint = dec_key * C_point`.
    4.  This `DecryptedOriginalPoint` is then serialized.

**6. The Google API Protocol Flow (Revisited with Keys):**
*   Client (LeakLens Server) has private key \(k_S\). Google has private key \(k_G\).
*   User provides `username, password`.
*   LeakLens computes `lookup_hash = scrypt(username, password)`.
*   LeakLens computes point \(P = \text{hashToTheCurve(lookup_hash)}\).
*   LeakLens encrypts: \(E_S = k_S \cdot P\). This serialized point is sent to Google as `encrypted_lookup_hash`.
*   Google receives \(E_S\). It computes \(E_{GS} = k_G \cdot E_S = k_G \cdot (k_S \cdot P)\). This is returned as `reencrypted_lookup_hash`.
*   Google also has its database of leaked credential points \(L_j\). It returns prefixes of \(\text{SHA256}(\text{serialize}(k_G \cdot L_j))\) as `encrypted_leak_match_prefix`.
*   LeakLens receives \(E_{GS}\) and the prefixes.
*   LeakLens "decrypts" its layer from \(E_{GS}\) using \(k_S^{-1}\) (the modular inverse of \(k_S\)):
    \(P_G = k_S^{-1} \cdot E_{GS} = k_S^{-1} \cdot (k_G \cdot k_S \cdot P)\).
    Since scalar multiplication is associative and commutative with respect to the scalars:
    \(P_G = (k_S^{-1} \cdot k_S) \cdot k_G \cdot P = 1 \cdot k_G \cdot P = k_G \cdot P\).
*   LeakLens now has \(P_G\), which is the original `lookup_hash` point \(P\) as if it had been encrypted *only* by Google's key \(k_G\).
*   LeakLens serializes \(P_G\) (trying both y-parities, `0x02` and `0x03`, as Google might use either for its internal \(L_j\) representations or the prefixes might cover both). It then computes `sha256(serialize(P_G))` for both serializations.
*   These SHA256 hash prefixes are compared against the `encrypted_leak_match_prefix` values from Google. A match signifies a leak.

**7. Security & Privacy Implications**
*   **Google:** Never sees the plaintext password, the `lookup_hash`, or the LeakLens server's private key \(k_S\). It only sees \(E_S = k_S \cdot P\) and the `username_hash_prefix`.
*   **LeakLens Server:** Never sees Google's private key \(k_G\). It handles the user's plaintext password only transiently if the check is initiated via the webapp (it's immediately hashed and processed). If the user runs the tool locally, the password doesn't leave their machine before being hashed.
*   The strength relies on the ECDLP and the security of SHA256/scrypt.

## Contributing

Contributions are welcome! Please feel free to submit pull requests, create issues for bugs or feature requests.

1.  Fork the repository.
2.  Create your feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

---

*This README was generated based on the provided project information and code snippets. Remember to replace placeholders like `yourusername`, links, and specific framework choices with your actual project details.*
