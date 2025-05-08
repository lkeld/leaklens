#!/bin/bash
set -e

echo "============================================"
echo "     LeakLens Unified Deployment Script     "
echo "============================================"

# Function to show usage information
show_usage() {
  echo "Usage: ./deploy.sh [OPTION]"
  echo "Deploy LeakLens with various options"
  echo ""
  echo "Options:"
  echo "  -h, --help           Show this help message"
  echo "  -l, --local          Deploy locally (no server deployment)"
  echo "  -f, --fast           Use fast build mode (skip rebuilding unchanged components)"
  echo "  -s, --server HOST    Deploy to remote server (requires SSH key)"
  echo "  -c, --clean          Clean all Docker containers and images before building"
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh                  # Standard local deployment"
  echo "  ./deploy.sh -f               # Fast local deployment (incremental build)"
  echo "  ./deploy.sh -s 13.236.185.53 # Deploy to remote server" 
  echo "  ./deploy.sh -c               # Clean deployment (full rebuild)"
  exit 0
}

# Function to check if Docker is installed
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed. Please install Docker first."
    exit 1
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose is not installed. Please install Docker Compose first."
    exit 1
  fi
}

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

# Function to clean Docker resources
clean_docker() {
  echo "Cleaning Docker resources..."
  docker-compose down -v || true
  docker image prune -af --filter "label=com.docker.compose.project=leaklens" || true
  echo "Docker cleanup completed."
}

# Function to build and start locally
local_deploy() {
  # Stop any existing containers
  echo "Stopping any existing LeakLens containers..."
  docker-compose down || true

  # Clean up any dangling images to free space
  echo "Cleaning up dangling Docker images..."
  docker image prune -f || true

  # Always use BuildKit for better performance
  export DOCKER_BUILDKIT=1

  # Build and start the containers
  if [ "$FAST_MODE" == "true" ]; then
    # Check for changes in source files
    API_CHANGES=$(find api_server -type f -not -path "*/target/*" -not -path "*/\.*" -newer .last_api_build 2>/dev/null)
    WEB_CHANGES=$(find webapp -type f -not -path "*/node_modules/*" -not -path "*/\.*" -newer .last_web_build 2>/dev/null)
    
    # Selective rebuild based on changes
    if needs_rebuild "leaklens" "$API_CHANGES$WEB_CHANGES"; then
      echo "Building LeakLens container..."
      docker-compose build
      touch .last_api_build
      touch .last_web_build
    else
      echo "Skipping build as no changes detected."
    fi
  else
    echo "Building LeakLens container (full build)..."
    docker-compose build --no-cache || {
      echo "Error: Failed to build Docker images."
      echo "Checking Docker build logs..."
      docker-compose logs
      exit 1
    }
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
  sleep 10

  # Check if containers are running
  if docker-compose ps | grep -q "leaklens"; then
    echo "✅ LeakLens is now running!"
    
    # Get server IP
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
}

# Function to deploy to a remote server
remote_deploy() {
  local SERVER_HOST=$1
  local SERVER_USER=${2:-"admin"}
  local SERVER_PORT=${3:-"22"}
  local SERVER_DIR=${4:-"/var/www/leakcheck"}
  
  echo "Deploying to remote server: $SERVER_HOST"
  
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
  
  echo "Creating deployment archive..."
  # Create an archive with just the necessary files
  tar -czf leaklens-deploy.tar.gz \
    docker-compose.yml \
    deploy.sh \
    Dockerfile \
    api_server/Cargo.toml \
    api_server/Cargo.lock \
    api_server/src \
    api_server/proto \
    api_server/swagger.yaml \
    api_server/build.rs \
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
  
  echo "Copying files to server..."
  # Copy the archive to the server using the SSH key
  scp -i "$SSH_KEY_FILE" -P $SERVER_PORT leaklens-deploy.tar.gz $SERVER_USER@$SERVER_HOST:~/ || {
    echo "ERROR: Failed to copy files to server"
    exit 1
  }
  
  echo "Setting up and deploying on the server..."
  # Execute commands on the server using the SSH key
  ssh -i "$SSH_KEY_FILE" -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << EOF
    # Create the deployment directory if it doesn't exist
    mkdir -p $SERVER_DIR
    
    # Extract the archive
    tar -xzf ~/leaklens-deploy.tar.gz -C $SERVER_DIR
    
    # Make the deploy script executable
    chmod +x $SERVER_DIR/deploy.sh
    
    # Run the deploy script locally on the server
    cd $SERVER_DIR
    ./deploy.sh -l
    
    # Clean up
    rm ~/leaklens-deploy.tar.gz
EOF
  
  echo "Remote deployment completed!"
  echo "Your application should now be running on the server."
  echo "You can access it at: http://$SERVER_HOST:8080"
}

# Parse command line arguments
SERVER_DEPLOY=false
SERVER_HOST=""
LOCAL_DEPLOY=false
FAST_MODE=false
CLEAN_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage
      ;;
    -l|--local)
      LOCAL_DEPLOY=true
      shift
      ;;
    -f|--fast)
      FAST_MODE=true
      shift
      ;;
    -s|--server)
      SERVER_DEPLOY=true
      SERVER_HOST="$2"
      shift 2
      ;;
    -c|--clean)
      CLEAN_MODE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Check if Docker is installed
check_docker

# Clean if requested
if [ "$CLEAN_MODE" == "true" ]; then
  clean_docker
fi

# If no specific mode is selected, default to local deploy
if [ "$SERVER_DEPLOY" == "false" ] && [ "$LOCAL_DEPLOY" == "false" ]; then
  LOCAL_DEPLOY=true
fi

# Run the selected deployment mode
if [ "$SERVER_DEPLOY" == "true" ]; then
  if [ -z "$SERVER_HOST" ]; then
    echo "Error: Server host is required for remote deployment."
    show_usage
  fi
  remote_deploy "$SERVER_HOST"
fi

if [ "$LOCAL_DEPLOY" == "true" ]; then
  local_deploy
fi

echo "Deployment completed successfully!"
