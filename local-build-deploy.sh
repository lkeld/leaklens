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
LOCAL_BUILD_DIR="./build"

# Detect if we're running on Windows
IS_WINDOWS=false
if [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "cygwin"* ]]; then
  IS_WINDOWS=true
  echo "Detected Windows environment. Will adjust file names for Linux deployment."
fi

# Define the path to the SSH key file
if [[ "$IS_WINDOWS" == "true" ]]; then
  # Windows path format
  SSH_KEY_FILE="C:/Users/luke/Downloads/mainkey.pem"
  # Convert Windows path to appropriate format for the current shell
  SSH_KEY_FILE=$(echo $SSH_KEY_FILE | sed 's/\\/\//g')
else
  # Linux/Mac path format
  SSH_KEY_FILE="/mnt/c/Users/luke/Downloads/mainkey.pem"
fi

# Ensure the key file has correct permissions (ignored on Windows)
if [[ "$IS_WINDOWS" == "false" ]]; then
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

# Check and install necessary development dependencies
echo "Checking and installing build dependencies..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # For Debian/Ubuntu systems
  if ! command -v protoc &> /dev/null; then
    echo "Installing protobuf compiler..."
    sudo apt-get update
    sudo apt-get install -y protobuf-compiler
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # For MacOS
  if ! command -v protoc &> /dev/null; then
    echo "Installing protobuf compiler..."
    brew install protobuf
  fi
elif [[ "$IS_WINDOWS" == "true" ]]; then
  # For Windows (Git Bash, MinGW, Cygwin)
  echo "On Windows, please manually install Protocol Buffers from: https://github.com/protocolbuffers/protobuf/releases"
  echo "After installation, ensure 'protoc' is in your PATH or set the PROTOC environment variable."
  if ! command -v protoc &> /dev/null; then
    read -p "Press Enter to continue if you've installed protoc, or Ctrl+C to cancel..." 
  fi
fi

# Verify protoc is now available
if ! command -v protoc &> /dev/null; then
  echo "Warning: protoc is still not found. Build may fail."
  echo "You can install it manually and set the PROTOC environment variable to point to it."
  echo "For example: export PROTOC=/path/to/protoc"
  read -p "Press Enter to continue anyway, or Ctrl+C to cancel..." 
fi

# Create build directory
mkdir -p $LOCAL_BUILD_DIR

echo "Step 1: Building API server locally..."
# Build API server
cd api_server
cargo build --release

# Debug: Show what files were actually generated
echo "Listing release target directory content:"
ls -la target/release/

# Copy build artifacts
mkdir -p ../$LOCAL_BUILD_DIR/api_server

# Handle Windows .exe extension 
API_SERVER_BIN=""
if [[ "$IS_WINDOWS" == "true" ]]; then
  if [ -f "target/release/api_server.exe" ]; then
    echo "Found Windows binary: target/release/api_server.exe"
    # Keep the .exe extension for deployment to ensure script is referring to correct file
    cp target/release/api_server.exe ../$LOCAL_BUILD_DIR/api_server/
    API_SERVER_BIN="api_server.exe"
  elif [ -f "target/release/leaklens-api.exe" ]; then
    echo "Found Windows binary: target/release/leaklens-api.exe"
    cp target/release/leaklens-api.exe ../$LOCAL_BUILD_DIR/api_server/
    API_SERVER_BIN="leaklens-api.exe"
  else
    echo "Error: Could not find the API server executable in target/release/"
    echo "Looking for api_server.exe or leaklens-api.exe"
    exit 1
  fi
else
  if [ -f "target/release/api_server" ]; then
    echo "Found Linux binary: target/release/api_server"
    cp target/release/api_server ../$LOCAL_BUILD_DIR/api_server/
    API_SERVER_BIN="api_server"
  elif [ -f "target/release/leaklens-api" ]; then
    echo "Found Linux binary: target/release/leaklens-api"
    cp target/release/leaklens-api ../$LOCAL_BUILD_DIR/api_server/api_server
    API_SERVER_BIN="api_server"
  else
    echo "Error: Could not find the API server executable in target/release/"
    echo "Looking for api_server or leaklens-api"
    exit 1
  fi
fi

echo "API server binary copied as: $API_SERVER_BIN"

cp swagger.yaml ../$LOCAL_BUILD_DIR/api_server/
cd ..

# Verify the API server binary exists in the build directory
echo "Verifying API server binary in build directory:"
ls -la $LOCAL_BUILD_DIR/api_server/

echo "Step 2: Building webapp locally..."
# Build webapp
cd webapp
npm install --no-fund --no-audit --legacy-peer-deps
npm run build
# Copy build artifacts
mkdir -p ../$LOCAL_BUILD_DIR/webapp
cp -r .next ../$LOCAL_BUILD_DIR/webapp/
cp -r public ../$LOCAL_BUILD_DIR/webapp/
cp package.json package-lock.json ../$LOCAL_BUILD_DIR/webapp/
cd ..

# Create a minimal docker-compose.yml that uses pre-built artifacts
echo "Step 3: Creating deployment docker-compose.yml..."
cat > $LOCAL_BUILD_DIR/docker-compose.yml << EOL
version: '3.8'

services:
  api:
    image: debian:bullseye-slim
    container_name: leaklens-api
    ports:
      - "10000:3000"
    volumes:
      - ./api_server:/app
    working_dir: /app
    command: bash -c "ls -la && ./${API_SERVER_BIN} || (apt-get update && apt-get install -y wine64 && wine64 ./${API_SERVER_BIN})"
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
    image: node:20.10-alpine
    container_name: leaklens-webapp
    depends_on:
      - api
    ports:
      - "8080:3001"
    volumes:
      - ./webapp:/app
    working_dir: /app
    command: sh -c "npm install --only=production --legacy-peer-deps && npm start"
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

echo "Step 4: Creating deployment script..."
cat > $LOCAL_BUILD_DIR/deploy.sh << EOL
#!/bin/bash
set -e

echo "Deploying LeakLens with pre-built artifacts"

# Debug: List files in the api_server directory
echo "Files in API server directory:"
ls -la ./api_server/

# Make sure the API server is executable if not .exe
if [[ "${API_SERVER_BIN}" != *".exe" ]]; then
  chmod +x ./api_server/${API_SERVER_BIN} || echo "Warning: Could not set executable permission"
fi

# Stop any existing containers
echo "Stopping any existing LeakLens containers..."
docker-compose down 2>/dev/null || true

echo "Starting LeakLens..."
docker-compose up -d

# Check if containers are running
if docker-compose ps | grep -q "leaklens"; then
  echo "✅ LeakLens is now running!"
  
  # Get server IP
  SERVER_IP=\$(hostname -I | awk '{print \$1}')
  
  echo ""
  echo "You can access LeakLens at: http://\$SERVER_IP:8080"
  echo ""
  echo "To view logs: docker-compose logs -f"
  echo "To stop the service: docker-compose down"
else
  echo "❌ Error: Failed to start LeakLens containers. Check logs with: docker-compose logs"
  exit 1
fi
EOL

chmod +x $LOCAL_BUILD_DIR/deploy.sh

# Create the deploy archive
echo "Step 5: Creating deployment archive..."
tar -czf leaklens-deploy.tar.gz -C $LOCAL_BUILD_DIR .

echo "Step 6: Deploying to server..."
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
  
  # Debug: List the files to verify the API server binary exists
  echo "Files in the deployment directory:"
  ls -la $SERVER_DIR/api_server/
  
  # Make the API server executable if not .exe
  if [[ "${API_SERVER_BIN}" != *".exe" ]]; then
    chmod +x $SERVER_DIR/api_server/${API_SERVER_BIN} || echo "Warning: Could not set executable permission"
  fi
  
  # Install Wine if needed for Windows binary
  if [[ "${API_SERVER_BIN}" == *".exe" ]]; then
    echo "Windows binary detected. Installing Wine if needed..."
    sudo apt-get update
    sudo apt-get install -y wine64
  fi
  
  # Run the deploy script
  cd $SERVER_DIR
  ./deploy.sh
  
  # Clean up
  rm ~/leaklens-deploy.tar.gz
EOF

echo "Deployment completed!"
echo "Your locally compiled version of LeakLens should now be running on the server."
echo "You can access it at: http://$SERVER_HOST:8080" 