#!/bin/bash

# LeakLens Server Quick Deploy Script (Debug Version)
set -e

echo "===================================="
echo "  LeakLens Debug Server Deployment  "
echo "===================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed. Please install Docker first."
  exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: Docker Compose is not installed. Please install Docker Compose first."
  exit 1
fi

# Create a modified Dockerfile for the API server
mkdir -p .docker-build
cat > .docker-build/api.Dockerfile << 'EOL'
# LeakLens API Server Dockerfile (Debug Version)
FROM rust:1.81-slim-bullseye AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    make \
    gcc \
    perl \
    protobuf-compiler \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Verify protoc is installed
RUN protoc --version || echo "protoc not found"

# Set up working directory
WORKDIR /app

# Copy the entire project
COPY . .

# Set environment variable for Prost build to use system protoc
ENV PROTOC=/usr/bin/protoc

# Build dependencies - this is done separately to cache dependencies
RUN cargo build --release

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the build artifact from the builder stage
WORKDIR /app
COPY --from=builder /app/target/release/api_server .
COPY --from=builder /app/swagger.yaml ./

# Expose the port
EXPOSE 3000

# Set the startup command
CMD ["./api_server"]
EOL

# Create a modified Dockerfile for the webapp
cat > .docker-build/webapp.Dockerfile << 'EOL'
# LeakLens WebApp Dockerfile
# Multi-stage build for optimized production image

# Build stage
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install dependencies with legacy-peer-deps to resolve dependency conflicts
ENV CI=false
RUN npm install --no-fund --no-audit --legacy-peer-deps

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Runtime stage
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV production
ENV PORT 3001

# Copy built assets from builder stage
COPY --from=builder /app/package.json /app/package-lock.json ./
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public

# Expose the port
EXPOSE 3001

# Start the application
CMD ["npm", "start"]
EOL

# Create docker-compose.yml file in the current directory
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  api:
    build:
      context: ./api_server
      dockerfile: ../.docker-build/api.Dockerfile
    container_name: leaklens-api
    ports:
      - "10000:3000"
    environment:
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=3000
      - RUST_LOG=info
      - CORS_ALLOWED_ORIGINS=http://localhost:3001,http://webapp:3001
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/status"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    networks:
      - leaklens-network

  webapp:
    build:
      context: ./webapp
      dockerfile: ../.docker-build/webapp.Dockerfile
    container_name: leaklens-webapp
    depends_on:
      - api
    ports:
      - "8080:3001"
    environment:
      - NODE_ENV=production
      - NEXT_PUBLIC_API_URL=http://api:3000
    restart: unless-stopped
    networks:
      - leaklens-network

networks:
  leaklens-network:
    driver: bridge
EOL

# Stop any existing containers
echo "Stopping any existing LeakLens containers..."
docker-compose down 2>/dev/null || true

echo "Building and starting LeakLens..."
# First build the API
docker-compose build --no-cache api

# Then build and start all services
echo "Starting all containers..."
docker-compose up -d

echo "Checking container status..."
docker-compose ps

# Give containers a moment to start up
sleep 10

# Check if containers are running
if docker-compose ps | grep -q "leaklens"; then
  echo "✅ LeakLens is now running!"
  
  # Get server IP
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  echo ""
  echo "You can access LeakLens at: http://$SERVER_IP:8080"
  echo ""
  echo "To view logs: docker-compose logs -f"
  echo "To stop the service: docker-compose down"
else
  echo "❌ Error: Failed to start LeakLens containers. Check logs with: docker-compose logs"
  docker-compose logs
  exit 1
fi 