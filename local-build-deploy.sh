#!/bin/bash

# LeakLens Local Build and Server Deploy Script
set -e

echo "============================================"
echo "     LeakLens Local Build & Deploy          "
echo "============================================"

# This script is for local development and testing
# It avoids full rebuilds where possible

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

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
  echo "Error: Docker Compose is not installed. Please install Docker Compose first."
  exit 1
fi

# Function to check if container needs rebuilding
needs_rebuild() {
    local service=$1
    local changed_files=$2
    
    if [[ -z "$(docker-compose ps -q $service 2>/dev/null)" ]]; then
        echo "Service $service does not exist. Build needed."
        return 0
    fi
    
    if [[ ! -z "$changed_files" ]]; then
        echo "Source files have changed. Build needed."
        return 0
    fi
    
    echo "No rebuild needed for $service."
    return 1
}

# Check for changes in source files
API_CHANGES=$(find api_server -type f -not -path "*/target/*" -not -path "*/\.*" -newer .last_api_build 2>/dev/null)
WEB_CHANGES=$(find webapp -type f -not -path "*/node_modules/*" -not -path "*/\.*" -newer .last_web_build 2>/dev/null)

# Stop any existing containers
echo "Stopping any existing LeakLens containers..."
docker-compose down || true

# Always use BuildKit for better performance
export DOCKER_BUILDKIT=1

# Selective rebuild based on changes
if needs_rebuild "leaklens" "$API_CHANGES$WEB_CHANGES"; then
    echo "Building LeakLens container..."
    docker-compose build
    touch .last_api_build
    touch .last_web_build
else
    echo "Skipping build as no changes detected."
fi

echo "Starting services..."
docker-compose up -d || {
    echo "Error: Failed to start Docker containers."
    echo "Checking logs..."
    docker-compose logs
    exit 1
}

# Wait a moment for containers to fully start
echo "Waiting for services to start..."
sleep 5

# Check if containers are running
if docker-compose ps | grep -q "leaklens"; then
    echo "✅ LeakLens is now running!"
    
    # Get server IP (or localhost if local)
    if command -v hostname &> /dev/null; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    else
        SERVER_IP="localhost"
    fi
    
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