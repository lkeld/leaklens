# LeakLens Combined Dockerfile
# Multi-stage build for both API and WebApp with Nginx reverse proxy

# Build API stage
FROM rust:1.81-slim-bullseye AS api-builder

# Install dependencies with fix for debconf issues
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    make \
    gcc \
    perl \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# Set up working directory
WORKDIR /app

# Copy the API server code
COPY api_server/ .

# Create or touch the missing file
RUN mkdir -p src/bin && touch src/bin/test_credential_check.rs

# Fix warnings and add minimal content to the test file
RUN echo 'fn main() { println!("Test Credential Check"); }' > src/bin/test_credential_check.rs

# Fix unused imports and variable warnings WITHOUT adding underscores
RUN if [ -f src/api/check_routes.rs ]; then \
    sed -i 's/use std::time::{Duration, Instant};/use std::time::Instant;/' src/api/check_routes.rs && \
    sed -i '/use tokio::time::sleep;/d' src/api/check_routes.rs; \
    fi

# Don't add underscores to variables that are actually used
# This command explicitly keeps variable names without underscores
RUN if [ -f src/api/check_routes.rs ]; then \
    sed -i 's/if let Some(_job) = jobs.get/if let Some(job) = jobs.get/g' src/api/check_routes.rs && \
    sed -i 's/if let Some(_job) = jobs.get_mut/if let Some(job) = jobs.get_mut/g' src/api/check_routes.rs && \
    sed -i 's/if let Some(_job) = jobs.remove/if let Some(job) = jobs.remove/g' src/api/check_routes.rs; \
    fi

# Build dependencies - this is done separately to cache dependencies
RUN cargo build --release

# Build the application
RUN cargo clean && cargo build --release

# Build WebApp stage
FROM node:20.10-alpine AS webapp-builder

# Set working directory
WORKDIR /app

# Display Node.js and npm versions for debugging
RUN node -v && npm -v

# Configure npm for better network resilience
RUN npm config set registry https://registry.npmjs.org/ \
    && npm config set fetch-retries 5 \
    && npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000 \
    && npm config set timeout 300000

# Copy package files
COPY webapp/package.json webapp/package-lock.json ./

# Install dependencies with legacy-peer-deps to resolve dependency conflicts
# Add retry logic for network issues
ENV CI=false
RUN for i in $(seq 1 3); do \
      echo "Attempt $i: Installing npm packages..." && \
      npm install --no-fund --no-audit --legacy-peer-deps && break || \
      echo "Attempt $i failed. Retrying in 10 seconds..." && \
      sleep 10; \
    done

# Copy source code
COPY webapp/ .

# Build the application with retry logic
RUN for i in $(seq 1 3); do \
      echo "Attempt $i: Building the application..." && \
      npm run build && break || \
      echo "Attempt $i failed. Retrying in 10 seconds..." && \
      sleep 10; \
    done

# Runtime stage
FROM debian:bullseye-slim

# Set environment variable to avoid debconf errors
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies, Nginx, Node.js and npm
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    nginx \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create needed directories
RUN mkdir -p /app/api /app/webapp /app/scripts

# Create startup script directly in the final image
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting LeakLens application..."\n\
\n\
# Start the API server in the background\n\
echo "Starting API server..."\n\
cd /app/api\n\
./api_server &\n\
API_PID=$!\n\
\n\
# Start the Next.js app in the background\n\
echo "Starting Next.js webapp..."\n\
cd /app/webapp\n\
npm start &\n\
NEXT_PID=$!\n\
\n\
echo "Starting Nginx..."\n\
# Start Nginx in the foreground\n\
nginx -g "daemon off;" &\n\
NGINX_PID=$!\n\
\n\
# Wait for any process to exit\n\
wait -n\n\
\n\
# Exit with status of process that exited first\n\
exit $?\n' > /app/scripts/start.sh

# Make the script executable
RUN chmod +x /app/scripts/start.sh

# Copy the Rust API build artifact
WORKDIR /app/api
COPY --from=api-builder /app/target/release/api_server .
COPY --from=api-builder /app/swagger.yaml ./

# Copy the Next.js webapp
WORKDIR /app/webapp
COPY --from=webapp-builder /app/package.json /app/webapp/package.json
COPY --from=webapp-builder /app/package-lock.json /app/webapp/package-lock.json
COPY --from=webapp-builder /app/node_modules /app/webapp/node_modules
COPY --from=webapp-builder /app/.next /app/webapp/.next
COPY --from=webapp-builder /app/public /app/webapp/public

# Configure Nginx
COPY <<-EOT /etc/nginx/sites-available/default
server {
    listen 80;
    server_name localhost;
    
    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOT

# Expose the port
EXPOSE 80

# Set working directory to the root so we can access the script
WORKDIR /app

# Set the startup command
CMD ["/app/scripts/start.sh"] 