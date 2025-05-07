#!/bin/bash

# LeakLens Server Quick Deploy Script
set -e

echo "===================================="
echo "  LeakLens Quick Server Deployment  "
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

# Create a directory for LeakLens
mkdir -p ~/leaklens
cd ~/leaklens

# Create docker-compose.yml file
cat > docker-compose.yml << 'EOL'
version: '3.8'

services:
  leaklens:
    build:
      context: .
      dockerfile: Dockerfile
    image: ghcr.io/lkeld/leaklens:latest  # Use the pre-built image from GitHub Container Registry
    container_name: leaklens
    ports:
      - "8080:80"
    environment:
      - NODE_ENV=production
      - SERVER_HOST=0.0.0.0
      - RUST_LOG=info
    volumes:
      - leaklens_data:/app/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/api/status"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  leaklens_data:
    driver: local
EOL

# Pull the latest image and start the container
echo "Stopping any existing LeakLens containers..."
docker-compose down 2>/dev/null || true

echo "Pulling the latest LeakLens Docker image..."
docker-compose pull

echo "Starting LeakLens..."
docker-compose up -d

# Check if container is running
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
  echo "❌ Error: Failed to start LeakLens container. Check logs with: docker-compose logs"
  exit 1
fi 