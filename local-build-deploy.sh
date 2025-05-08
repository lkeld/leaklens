#!/bin/bash

# LeakLens Local Build and Server Deploy Script
set -e

echo "============================================"
echo "  LeakLens Local Build and Server Deploy    "
echo "============================================"

# Define variables - change these to match your environment
SERVER_USER="admin"
SERVER_HOST="13.236.185.53"
SERVER_PORT="22"
SERVER_DIR="/var/www/leakcheck"

# Define the path to the SSH key file
if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "cygwin"* ]]; then
  # Windows path format
  SSH_KEY_FILE="C:/Users/luke/Downloads/mainkey.pem"
  # Convert Windows path to appropriate format for the current shell
  SSH_KEY_FILE=$(echo $SSH_KEY_FILE | sed 's/\\/\//g')
else
  # Linux/Mac path format
  SSH_KEY_FILE="/mnt/c/Users/luke/Downloads/mainkey.pem"
fi

# Ensure the key file has correct permissions (ignored on Windows)
if [[ "$OSTYPE" != "msys"* && "$OSTYPE" != "win32"* && "$OSTYPE" != "cygwin"* ]]; then
  chmod 600 "$SSH_KEY_FILE"
fi

# Check if the key file exists
if [ ! -f "$SSH_KEY_FILE" ]; then
  echo "Error: SSH key file not found at $SSH_KEY_FILE"
  echo "Please make sure the file exists and the path is correct."
  exit 1
fi

echo "Using SSH key: $SSH_KEY_FILE"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "Error: Docker is not installed. Please install Docker first."
  exit 1
fi

echo "Step 1: Creating deployment files..."

# Create a new docker-compose.yml file
cat > docker-compose.production.yml << EOL
version: '3.8'

services:
  api:
    build:
      context: ./api_server
      dockerfile: Dockerfile
    container_name: leaklens-api
    ports:
      - "10000:3000"
    environment:
      - SERVER_HOST=0.0.0.0
      - SERVER_PORT=3000
      - RUST_LOG=info
      - CORS_ALLOWED_ORIGINS=http://localhost:3001,http://webapp:3001
    restart: unless-stopped
    networks:
      - leaklens-network

  webapp:
    build:
      context: ./webapp
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
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

# Create a Dockerfile for the API server if it doesn't already exist or is incomplete
if [ ! -f "api_server/Dockerfile" ] || ! grep -q "FROM rust:" "api_server/Dockerfile"; then
  cat > api_server/Dockerfile << EOL
FROM rust:1.81-slim-bullseye AS builder

# Install dependencies
RUN apt-get update && apt-get install -y \\
    pkg-config \\
    libssl-dev \\
    protobuf-compiler \\
    && rm -rf /var/lib/apt/lists/*

# Create a new empty project
WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \\
    ca-certificates \\
    libssl1.1 \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the binary from builder
COPY --from=builder /app/target/release/api_server .
COPY --from=builder /app/swagger.yaml .

# Set executable permissions
RUN chmod +x ./api_server

# Set the startup command
CMD ["./api_server"]
EOL
fi

# Create a Dockerfile for the webapp if it doesn't already exist or is incomplete
if [ ! -f "webapp/Dockerfile" ] || ! grep -q "FROM node:" "webapp/Dockerfile"; then
  cat > webapp/Dockerfile << EOL
FROM node:20.10-alpine AS builder

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
FROM node:20.10-alpine

WORKDIR /app

# Copy built app from builder
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/package-lock.json ./package-lock.json

# Install only production dependencies
RUN npm install --only=production --legacy-peer-deps

# Expose port
EXPOSE 3001

# Start the app
CMD ["npm", "start"]
EOL
fi

# Create a deployment script
cat > deploy.sh << EOL
#!/bin/bash
set -e

echo "Deploying LeakLens with Docker"

# Stop any existing containers
echo "Stopping any existing LeakLens containers..."
docker-compose -f docker-compose.production.yml down 2>/dev/null || true

# Pull the latest changes if needed
# git pull

# Start the containers
echo "Starting LeakLens..."
docker-compose -f docker-compose.production.yml up -d --build

# Check if containers are running
if docker-compose -f docker-compose.production.yml ps | grep -q "leaklens"; then
  echo "✅ LeakLens is now running!"
  
  # Get server IP
  SERVER_IP=\$(hostname -I | awk '{print \$1}')
  
  echo ""
  echo "You can access LeakLens at: http://\$SERVER_IP:8080"
  echo ""
  echo "To view logs: docker-compose -f docker-compose.production.yml logs -f"
  echo "To stop the service: docker-compose -f docker-compose.production.yml down"
else
  echo "❌ Error: Failed to start LeakLens containers. Check logs with: docker-compose -f docker-compose.production.yml logs"
  exit 1
fi
EOL

chmod +x deploy.sh

echo "Step 2: Creating deployment archive..."
# Create an archive with just the necessary files
tar -czf leaklens-deploy.tar.gz \
    docker-compose.production.yml \
    deploy.sh \
    api_server/Dockerfile \
    api_server/Cargo.toml \
    api_server/Cargo.lock \
    api_server/src \
    api_server/proto \
    api_server/swagger.yaml \
    api_server/build.rs \
    webapp/Dockerfile \
    webapp/package.json \
    webapp/package-lock.json \
    webapp/public \
    webapp/components \
    webapp/hooks \
    webapp/lib \
    webapp/styles \
    webapp/app \
    webapp/next.config.mjs \
    webapp/postcss.config.mjs \
    webapp/tailwind.config.ts \
    webapp/tsconfig.json
    
echo "Step 3: Deploying to server..."
echo "Using SSH key authentication..."

# Copy the archive to the server using the SSH key
scp -i "$SSH_KEY_FILE" -P $SERVER_PORT leaklens-deploy.tar.gz $SERVER_USER@$SERVER_HOST:~/ || {
  echo "ERROR: Failed to copy files to server"
  exit 1
}

# Execute commands on the server using the SSH key
ssh -i "$SSH_KEY_FILE" -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << EOF
  # Create the deployment directory if it doesn't exist
  mkdir -p $SERVER_DIR
  
  # Extract the archive
  tar -xzf ~/leaklens-deploy.tar.gz -C $SERVER_DIR
  
  # Make the deploy script executable
  chmod +x $SERVER_DIR/deploy.sh
  
  # Run the deploy script
  cd $SERVER_DIR
  ./deploy.sh
  
  # Clean up
  rm ~/leaklens-deploy.tar.gz
EOF

echo "Deployment completed!"
echo "Your application should now be building and running on the server."
echo "This may take some time as Docker builds the containers on the server."
echo "You can access it at: http://$SERVER_HOST:8080"
echo ""
echo "To check the build progress, SSH to the server and run:"
echo "  docker-compose -f docker-compose.production.yml logs -f" 