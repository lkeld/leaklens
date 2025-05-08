#!/bin/bash
set -e

echo "============================================"
echo "     LeakLens Deployment Script             "
echo "============================================"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if docker-compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Stop any existing containers
echo "Stopping any existing LeakLens containers..."
docker-compose down || true

# Clean up any dangling images to free space
echo "Cleaning up dangling Docker images..."
docker image prune -f || true

# Pull the latest images if using pre-built images or skip if building locally
# docker-compose pull || true

# Build and start the containers
echo "Building and starting LeakLens..."
# Build with a timeout to prevent hanging builds
DOCKER_BUILDKIT=1 docker-compose build --no-cache || {
    echo "Error: Failed to build Docker images."
    echo "Checking Docker build logs..."
    docker-compose logs
    exit 1
}

echo "Starting services..."
docker-compose up -d || {
    echo "Error: Failed to start Docker containers."
    echo "Checking logs..."
    docker-compose logs
    exit 1
}

# Wait a moment for containers to fully start
echo "Waiting for services to start..."
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
    echo "❌ Error: Failed to start LeakLens containers."
    echo "Checking logs..."
    docker-compose logs
    exit 1
fi
