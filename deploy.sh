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
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  echo ""
  echo "You can access LeakLens at: http://$SERVER_IP:8080"
  echo ""
  echo "To view logs: docker-compose -f docker-compose.production.yml logs -f"
  echo "To stop the service: docker-compose -f docker-compose.production.yml down"
else
  echo "❌ Error: Failed to start LeakLens containers. Check logs with: docker-compose -f docker-compose.production.yml logs"
  exit 1
fi
