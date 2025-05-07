# LeakLens: Secure Credential Leak Checker

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](https://github.com/yourusername/leaklens)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.1.0-blue)](https://github.com/yourusername/leaklens)

**LeakLens** is a robust tool designed for users to securely ascertain if their credentials (username/password combinations) have been compromised in publicly known data breaches. This is achieved through interaction with a Google API endpoint, originally utilized by Chrome's password checkup feature, which has been reverse-engineered for this project. The paramount design principle is **user privacy**: plaintext passwords are never transmitted to the LeakLens server (in self-hosted scenarios) or to Google. All verification processes employ advanced cryptographic methodologies, primarily **Elliptic Curve Commutative Encryption**.

**[Link to Live Demo (if deployed)]**

---

## Table of Contents

1.  [Features](#features)
2.  [Warning & Disclaimer](#️-warning--disclaimer)
3.  [Technical Overview: How It Works](#technical-overview-how-it-works)
    *   [Process Flow Diagram](#process-flow-diagram)
    *   [Step-by-Step Explanation](#step-by-step-explanation)
4.  [Technology Stack](#technology-stack)
5.  [Project Structure](#project-structure)
6.  [Getting Started / Installation (Self-Hosting)](#getting-started--installation-self-hosting)
7.  [API Reference](#api-reference)
8.  [In-Depth Cryptography & Protocol Details](#in-depth-cryptography--protocol-details)
9.  [Contributing](#contributing)
10. [License](#license)

---

## Features

*   **Privacy-Preserving Checks:** Leverages Elliptic Curve Commutative Encryption, ensuring plaintext passwords are never exposed to Google or the LeakLens server during verification.
*   **Reverse-Engineered Protocol:** Implements the client-side cryptographic logic for Google's internal password leak detection API.
*   **Single Credential Check:** Facilitates rapid verification of individual username/password pairs.
*   **Batch Credential Check:** Supports uploading a `.txt` file containing multiple credentials (e.g., `username:password` per line) for bulk processing.
*   **Open Source:** The complete codebase is transparent and available for public audit and contribution.
*   **Rust Backend:** The API is built with Rust, offering high performance and memory safety.
*   **React Frontend:** A modern, intuitive, and user-friendly web interface developed with React.
*   **Comprehensive Documentation:** Detailed explanations of the underlying cryptographic mechanisms and the reverse-engineered protocol.

---

## ⚠️ Warning & Disclaimer

> *   **Reverse-Engineered API:** This project interacts with an API that was reverse-engineered from Google Chrome's source code and observed network traffic. Google LLC may alter or disable this API endpoint at any time without prior notice, potentially rendering this tool non-functional.
> *   **No Affiliation with Google:** LeakLens is an independent, community-driven project. It is not endorsed by, affiliated with, or supported by Google LLC in any way.
> *   **Responsible Use:** This tool is intended solely for legitimate security auditing purposes. Users must ensure they have explicit authorization to check any credentials. Unauthorized use is strictly discouraged.
> *   **Token Acquisition:** The methodology for acquiring Google API tokens for the backend (particularly the `refresh_token`) can be intricate. It may involve techniques such as Man-in-the-Middle (MITM) proxying for initial token capture, which should be thoroughly understood. For a self-hosted public service, a robust and legitimate token management strategy is paramount and may necessitate adherence to Google's OAuth 2.0 policies for server-to-server applications, if permissible for this specific API endpoint.

---

## Technical Overview: How It Works

LeakLens employs a sophisticated cryptographic protocol to verify credentials against known leaks without compromising user privacy.

### Process Flow Diagram

```mermaid
graph LR
    A[User: Enters Username/Password] --> B(LeakLens Client/Server);
    B --> C{1. Initial Hashing};
    C --> C1["lookup_hash = scrypt(username, password)"];
    C --> C2["username_hash_prefix"];
    C1 --> D{2. Hash to Curve};
    D --> D1["Point P = hashToTheCurve(lookup_hash)"];
    D1 --> E(LeakLens Server);
    E --> F{3. First Encryption (key kS)};
    F --> F1["E_S = kS * P"];
    F1 --> G(Google API);
    C2 --> G;
    G --> H{4. Second Encryption (key kG)};
    H --> H1["E_GS = kG * E_S <br> (reencrypted_lookup_hash)"];
    H --> H2["Encrypted Leak Prefixes <br> (kG * L_j)"];
    H1 --> I(LeakLens Server);
    H2 --> I;
    I --> J{5. Decryption & Comparison};
    J --> J1["P_G = kS_inv * E_GS = kG * P"];
    J1 --> K{Compare SHA256(serialize(P_G)) <br> with Encrypted Leak Prefixes};
    K --> L[Result: Leaked / Not Leaked];

    subgraph LeakLens System
        B
        C
        D
        E
        F
        I
        J
        K
        L
    end

    style G fill:#f9f,stroke:#333,stroke-width:2px
    style A fill:#bbf,stroke:#333,stroke-width:2px
```

### Step-by-Step Explanation

1.  **User Input:** The user provides a username and password, or a file containing multiple such pairs.
2.  **Initial Hashing (Client-Side or LeakLens Server):**
    *   The `username` is processed to generate a `username_hash_prefix` (a 26-bit prefix derived from a salted SHA256 hash).
    *   The `username` and `password` are combined and subjected to the `scrypt` key derivation function (a memory-hard, salted algorithm) to produce a `lookup_hash`.
3.  **Hashing to Elliptic Curve:** The `lookup_hash` is deterministically mapped to a point $`P`$ on the NIST P-256 elliptic curve.
4.  **First Encryption (LeakLens Server):** The LeakLens server, possessing its private ECC key $`k_S`$, encrypts the point $`P`$ via scalar multiplication: $`E_S = k_S \cdot P`$.
5.  **Request to Google:** The `username_hash_prefix` and the encrypted point $`E_S`$ (termed `encrypted_lookup_hash`) are transmitted to Google's API.
6.  **Second Encryption (Google's Server):** Google's server, holding its own private ECC key $`k_G`$, further encrypts the received point: $`E_{GS} = k_G \cdot E_S = k_G \cdot k_S \cdot P`$. This doubly-encrypted point is returned as `reencrypted_lookup_hash`. Google also returns `encrypted_leak_match_prefix` values, which are prefixes of SHA256 hashes of known leaked credentials, also encrypted with Google's key (e.g., prefixes of $`\text{SHA256}(\text{serialize}(k_G \cdot L_j))`$, where $`L_j`$ is a point representing a leaked credential).
7.  **Decryption & Comparison (LeakLens Server):**
    *   The LeakLens server utilizes its private key $`k_S`$ (specifically, its modular inverse $`k_S^{-1}`$) to "remove" its layer of encryption from the `reencrypted_lookup_hash`: $`D_S(E_{GS}) = k_S^{-1} \cdot (k_G \cdot k_S \cdot P)`$. Due to the properties of scalar multiplication, this simplifies to $`k_G \cdot P`$. Let this resulting point be $`P_G`$.
    *   The server then serializes $`P_G`$ (accounting for both possible y-coordinate parities) and computes their SHA256 hashes.
    *   These computed SHA256 hash prefixes are compared against the `encrypted_leak_match_prefix` values received from Google. A match indicates that the original credential is part of a known leak dataset accessible to Google.

This commutative encryption scheme ensures that Google never observes the user's `lookup_hash` (and thus, nothing directly derivable from the password without $`k_S`$), and the LeakLens server never gains access to Google's private key $`k_G`$.

---

## Technology Stack

*   **Backend:** Rust (using [Actix Web/Axum/Rocket - *specify your choice here*])
*   **Frontend:** React, JavaScript/TypeScript
*   **Cryptography:**
    *   Elliptic Curve Cryptography: NIST P-256 (`secp256r1`)
    *   Hashing Algorithms: SHA256, `scrypt`
    *   Data Serialization: Protocol Buffers (for Google API interaction)
*   **Build & Development Tools:** Cargo (Rust), Node.js & npm (or yarn)

---
<details>
<summary><strong>Project Structure (Click to expand)</strong></summary>

The project is logically divided into two primary components:

*   **`api_server/`**: The Rust-based backend application that exposes the core API endpoints.
    *   `src/main.rs`: Server entry point and initialization.
    *   `src/api/`: Handlers for defined API routes.
    *   `src/services/`: Core business logic, including leak checking mechanisms and interaction with Google's API.
    *   `src/crypto/`: Implementation of the `ECCommutativeCipher` and associated hashing utilities.
    *   `proto/`: Protocol Buffer definition files (`.proto`) for Google's API.
*   **`webapp/`**: The React-based frontend application providing the user interface.
    *   `src/App.js`: Main application component, including routing configuration.
    *   `src/pages/`: Components representing distinct pages of the application (e.g., Home, Check Single, Check Batch).
    *   `src/components/`: Reusable UI elements utilized across various pages.
    *   `src/services/apiService.js`: Functions dedicated to making calls to the backend API.

</details>

---

<details>
<summary><strong>Getting Started / Installation (Self-Hosting) (Click to expand)</strong></summary>

To deploy and run LeakLens locally or on a private server, follow these instructions:

### Prerequisites

*   **Rust and Cargo:** Install from [https://www.rust-lang.org/tools/install](https://www.rust-lang.org/tools/install)
*   **Node.js and npm (or yarn):** Install from [https://nodejs.org/](https://nodejs.org/)
*   **Protocol Buffer Compiler (`protoc`):** Required if you intend to regenerate Rust code from `.proto` files.

### 1. Backend (`api_server/`)

```bash
# Clone the repository
git clone https://github.com/yourusername/leaklens.git
cd leaklens/api_server

# 1.1. Environment Configuration (CRITICAL)
# Copy the example environment file to create your local configuration
cp .env.example .env

# IMPORTANT: Edit the .env file to provide the necessary Google API credentials.
# You must obtain a valid Google OAuth REFRESH_TOKEN with the scope:
# "https://www.googleapis.com/auth/identity.passwords.leak.check"
#
# The method for acquiring this refresh_token for server-side use is non-trivial.
# The `proxy.py` script (from the original Python exploration code) illustrates
# one technique to intercept this token from a browser session using a MITM proxy.
# This approach is generally suitable for development or personal use only.
#
# For a production server intended for public access, a more robust and
# legitimate OAuth flow (e.g., server-to-server) should be implemented,
# contingent upon Google's API Terms of Service for this specific endpoint.
#
# Populate the following variables in your .env file:
# GOOGLE_CLIENT_ID="77185425430.apps.googleusercontent.com" # Chrome's public client ID
# GOOGLE_CLIENT_SECRET="OTJgUOQcT7lO7GsGZq2G4IlT" # Chrome's public client secret
# GOOGLE_REFRESH_TOKEN="your_captured_refresh_token_here"

# 1.2. (Optional) Generate Protobuf Rust Code
# This step is only necessary if you modify the .proto files.
# Ensure `protoc` and the Rust protobuf plugin are installed.
# Example (adapt to your specific build script or Makefile):
# cargo build --features=generate_protobuf

# 1.3. Build and Run the Server
cargo build --release
cargo run --release
```

The API server should now be operational, typically listening on `http://localhost:8000` (or as configured).

### 2. Frontend (`webapp/`)

```bash
# Navigate to the webapp directory from the project root
cd ../webapp # Or: cd leaklens/webapp

# Install project dependencies
npm install
# or, if using yarn:
# yarn install

# Configure the API endpoint (if different from the default)
# Create a .env.local file in the `webapp/` directory and set:
# REACT_APP_API_BASE_URL=http://localhost:8000/api/v1

# Start the React development server
npm start
# or, if using yarn:
# yarn start
```

The React application should now be accessible in your browser, typically at `http://localhost:3000`.

</details>

---

## API Reference

The LeakLens backend provides a RESTful API for credential leak checking.

*   **Base URL:** `/api/v1` (This is configurable via environment variables).

**Endpoints:**

1.  **`POST /api/v1/check/single`**
    *   **Description:** Checks a single username/password pair.
    *   **Request Body (JSON):** `{"username": "user@example.com", "password": "password123"}`
    *   **Response (JSON):** `{"username": "user@example.com", "is_leaked": true/false, "message": "Descriptive status message"}`
2.  **`POST /api/v1/check/batch`**
    *   **Description:** Checks multiple credentials from an uploaded `.txt` file.
    *   **Request:** `multipart/form-data` with a `file` field containing the text file. Each line in the file should be `username:password`.
    *   **Response (JSON):** A summary of results (total processed, leaked, not leaked) and potentially a list of leaked credentials.
3.  **`GET /api/v1/status`**
    *   **Description:** A health check endpoint for the API.
    *   **Response (JSON):** `{"status": "healthy", "timestamp": "...", "google_api_status": "..."}`

For comprehensive API documentation, including detailed request/response schemas, error codes, and usage examples, please refer to the **[API Documentation Page on the hosted webapp](#)** or a dedicated `API_DOCS.md` file within this repository (if created).

---

<details open>
<summary><strong>In-Depth Cryptography & Protocol Details (Click to expand/collapse)</strong></summary>

This section provides a detailed exposition of the cryptographic primitives and the protocol flow reverse-engineered from Google's password checkup service.

### 1. The Privacy Challenge in Password Checking

The fundamental challenge is to enable a user to check if their password (or a derivative thereof) exists in a remote database of leaked credentials without revealing the password itself to the database holder (in this context, Google). This necessitates privacy-preserving cryptographic techniques.

### 2. Elliptic Curve Cryptography (ECC) Fundamentals

*   **Curve Specification:** The protocol utilizes the **NIST P-256** elliptic curve (also known as `secp256r1`). It is defined by the Weierstrass equation:
    $$
    y^2 \equiv x^3 + ax + b \pmod p
    $$
    Where the parameters for NIST P-256 are:
    *   Prime Modulus $`p`$:
        ```
        0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff
        ```
    *   Coefficient $`a`$:
        ```
        0xffffffff00000001000000000000000000000000fffffffffffffffffffffffc
        ```
    *   Coefficient $`b`$:
        ```
        0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b
        ```
*   **Group Operations:** Points on this curve, along with a "point at infinity," form an additive abelian group. The primary operation is **scalar multiplication**, denoted $`k \cdot P`$, which involves adding a point $`P`$ to itself $`k`$ times. This operation is computationally easy to perform but difficult to reverse (i.e., finding $`k`$ given $`P`$ and $`k \cdot P`$). This is known as the Elliptic Curve Discrete Logarithm Problem (ECDLP), which underpins the security of ECC.
*   **Group Order:** The number of points in the cyclic subgroup generated by a base point $`G`$. For NIST P-256, the order $`n`$ is:
    ```
    0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551
    ```

### 3. Initial Credential Processing

Before ECC operations, the user's credentials undergo specific hashing steps:

*   **`username_hash_prefix(username)`:**
    1.  A predefined, fixed salt (`username_salt`) is appended to the `username`.
    2.  The concatenated result is hashed using SHA256.
    3.  The first 4 bytes of the resulting SHA256 digest are extracted.
    4.  The last 6 bits of the 4th byte are masked (set to zero), effectively yielding a 26-bit prefix (3 full bytes + the first 2 bits of the 4th byte). This prefix is likely employed by Google for database sharding or indexing purposes.
*   **`scrypt_hash_username_and_password(username, password)` $\rightarrow$ `lookup_hash`:**
    1.  A salt for `scrypt` is formed by appending a predefined `password_salt` to the `username`.
    2.  The input to `scrypt` is formed by concatenating the `username` and `password`.
    3.  The `scrypt` key derivation function is applied with parameters $`N=4096, r=8, p=1`$. This produces a 32-byte hash, referred to as the `lookup_hash`. This `lookup_hash` serves as the input for subsequent ECC operations.

### 4. Hashing to the Elliptic Curve (`hashToTheCurve(lookup_hash)`)

The 32-byte `lookup_hash` must be transformed into a valid point $`(x, y)`$ on the NIST P-256 curve. This is achieved as follows:

1.  The `lookup_hash` (after stripping any trailing null bytes, as observed in the Python implementation) is processed by a `random_oracle` function.
2.  **`random_oracle(data, max_value)`:**
    *   This function iteratively computes SHA256 hashes. In each iteration $`i`$ (starting from 1), it hashes the concatenation of $`i`$ (as bytes) and the input `data`.
    *   The resulting SHA256 digests from multiple iterations (if needed) are concatenated and truncated to produce an integer $`x_{\text{candidate}}`$ modulo `max_value` (where `max_value` is the curve's prime modulus $`p`$).
3.  The derived $`x_{\text{candidate}}`$ is treated as the x-coordinate of a potential curve point. The curve equation $`y^2 \equiv x_{\text{candidate}}^3 + ax_{\text{candidate}} + b \pmod p`$ is then solved for $`y`$.
    *   If $`x_{\text{candidate}}^3 + ax_{\text{candidate}} + b`$ is a quadratic residue modulo $`p`$, two square roots for $`y`$ exist: $`y_0`$ and $`-y_0 \pmod p`$.
    *   A specific root is selected based on its parity (e.g., the Python code prefers the even root, or the negative of the odd root if the initial root is odd: `if (sqrt & 1 == 1): return Point(mod_x, (-sqrt) % p, self.cv)`).
    *   If no square root exists (i.e., $`x_{\text{candidate}}^3 + ax_{\text{candidate}} + b`$ is not a quadratic residue modulo $`p`$), the $`x_{\text{candidate}}`$ is re-hashed using the `random_oracle` (with $`x_{\text{candidate}}`$ itself as the new input `data`), and the process repeats until a valid point is found.
4.  The outcome is a valid elliptic curve point $`P = (x, y)`$.

### 5. The Commutative Cipher (`ECCommutativeCipher`)

This cipher leverages the properties of ECC scalar multiplication. The "commutative" nature refers to the overall protocol's effect where sequential encryptions by different parties (LeakLens server and Google) can be "peeled" back by the initial encryptor to isolate the other party's encryption.

*   **Private Key:** Each party (LeakLens server, Google) possesses a secret private key, which is a random integer $`k`$ such that $`1 \le k < n`$ (where $`n`$ is the group order). Let LeakLens server's key be $`k_S`$.
*   **Encryption (`encrypt(lookup_hash)` by LeakLens Server):**
    1.  Map the input to a curve point: $`P = \text{hashToTheCurve}(\text{lookup\_hash})`$.
    2.  Perform scalar multiplication: $`E_S = k_S \cdot P`$. This $`E_S`$ is the encrypted point.
    3.  The point $`E_S`$ is serialized into a byte string for transmission. This typically involves a prefix byte (`0x02` or `0x03`) indicating the parity of the y-coordinate (for point compression), followed by the 32-byte x-coordinate. This serialized form is the `encrypted_lookup_hash`.
*   **Decryption (`decrypt(serialized_encrypted_point_C)`) by LeakLens Server:**
    1.  The received point $`C_{\text{point}}`$ is deserialized from its byte string representation.
    2.  The decryption key is the modular multiplicative inverse of the private encryption key: $`k_S^{-1} \pmod n`$.
    3.  Perform scalar multiplication: $`P_{\text{original}} = k_S^{-1} \cdot C_{\text{point}}`$.
    4.  This $`P_{\text{original}}`$ is then serialized for comparison or further processing.

### 6. The Google API Protocol Flow (Detailed)

Let $`k_S`$ be the private key of the LeakLens server and $`k_G`$ be Google's private key.

1.  **User Input:** User provides `username` and `password`.
2.  **LeakLens Server Processing:**
    *   Computes $`\text{lookup\_hash} = \text{scrypt}(\text{username}, \text{password})`$.
    *   Maps to curve point: $`P = \text{hashToTheCurve}(\text{lookup\_hash})`$.
    *   Encrypts with its key: $`E_S = k_S \cdot P`$.
    *   Sends `username_hash_prefix` and the serialized $`E_S`$ (as `encrypted_lookup_hash`) to Google.
3.  **Google Server Processing:**
    *   Receives $`E_S`$.
    *   Re-encrypts with its key: $`E_{GS} = k_G \cdot E_S = k_G \cdot (k_S \cdot P)`$. This is returned as `reencrypted_lookup_hash`.
    *   Google also maintains a database of known leaked credential points, say $`L_j`$. It returns prefixes of $`\text{SHA256}(\text{serialize}(k_G \cdot L_j))`$ as `encrypted_leak_match_prefix`.
4.  **LeakLens Server Final Processing:**
    *   Receives $`E_{GS}`$ and the list of `encrypted_leak_match_prefix`.
    *   "Removes" its encryption layer from $`E_{GS}`$ using its decryption key $`k_S^{-1}`$:
        $$
        P_G = k_S^{-1} \cdot E_{GS} = k_S^{-1} \cdot (k_G \cdot k_S \cdot P)
        $$
        Due to the associativity and commutativity of scalars in scalar multiplication:
        $$
        P_G = (k_S^{-1} \cdot k_S) \cdot k_G \cdot P = 1 \cdot k_G \cdot P = k_G \cdot P
        $$
    *   The server now possesses $`P_G`$, which is the original point $`P`$ as if it had been encrypted *only* by Google's key $`k_G`$.
    *   The server serializes $`P_G`$. As the exact y-coordinate parity used by Google for its internal $`L_j`$ representations might not be known, or the prefixes might cover both, the server typically checks both possible serializations (corresponding to `0x02` and `0x03` prefixes). For each serialization, it computes $`\text{SHA256}(\text{serialize}(P_G))`$.
    *   The prefixes of these computed SHA256 hashes are then compared against the `encrypted_leak_match_prefix` values received from Google. A match indicates a leak.

### 7. Security & Privacy Implications

*   **Google's Perspective:** Google never observes the plaintext password, the `lookup_hash`, or the LeakLens server's private key $`k_S`$. It only receives the `username_hash_prefix` and $`E_S = k_S \cdot P`$ (an ECC point encrypted with a key unknown to Google).
*   **LeakLens Server's Perspective:** The LeakLens server never learns Google's private key $`k_G`$. If the check is initiated via the web application, it handles the user's plaintext password only transiently for immediate hashing and processing. If a user runs the tool entirely locally (e.g., a CLI version directly implementing this logic), the password does not leave their machine before being transformed into $`E_S`$.
*   The overall security of the protocol relies on the hardness of the Elliptic Curve Discrete Logarithm Problem (ECDLP) and the collision resistance of the hash functions SHA256 and `scrypt`.

</details>

---

## Contributing

Contributions are highly encouraged and welcome! If you wish to contribute, please follow these general guidelines:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix: `git checkout -b feature/YourAmazingFeature` or `git checkout -b bugfix/IssueDescription`.
3.  Make your changes and commit them with clear, descriptive messages: `git commit -m 'Add YourAmazingFeature'`.
4.  Push your changes to your forked repository: `git push origin feature/YourAmazingFeature`.
5.  Open a Pull Request against the main branch of this repository.

Please ensure your code adheres to existing style guidelines and includes relevant tests where applicable.

---

## License

This project is licensed under the **MIT License**. See the [LICENSE.md](LICENSE.md) file for full details.

---

