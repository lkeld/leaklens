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

# Copy package files
COPY webapp/package.json webapp/package-lock.json ./

# Install dependencies with legacy-peer-deps to resolve dependency conflicts
ENV CI=false
RUN npm install --no-fund --no-audit --legacy-peer-deps

# Copy source code
COPY webapp/ .

# Build the application
RUN npm run build

# Runtime stage
FROM debian:bullseye-slim

# Set environment variable to avoid debconf errors
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies and Nginx
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    nginx \
    && rm -rf /var/lib/apt/lists/*

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

# Create startup script
RUN mkdir -p /app/scripts
COPY <<-EOT /app/scripts/start.sh
#!/bin/bash
# Start the API server in the background
cd /app/api
./api_server &

# Start the Next.js app in the background
cd /app/webapp
npm start &

# Start Nginx in the foreground
nginx -g 'daemon off;'
EOT

RUN chmod +x /app/scripts/start.sh

# Expose the port
EXPOSE 80

# Set the startup command
CMD ["/app/scripts/start.sh"] 