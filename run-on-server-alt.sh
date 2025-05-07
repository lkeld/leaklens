#!/bin/bash

# LeakLens Server Quick Deploy Script (Alternative Version)
set -e

echo "===================================="
echo "  LeakLens Alternative Deployment   "
echo "===================================="

# First, install protobuf-compiler on the host system
echo "Installing Protocol Buffers compiler..."
sudo apt-get update
sudo apt-get install -y protobuf-compiler

# Verify installation
echo "Verifying Protocol Buffers compiler installation..."
protoc --version

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

# Create a special build script inside the api_server directory
echo "Creating build helper script..."
cat > api_server/build.rs << 'EOL'
fn main() {
    // Use system protoc to compile protos
    if let Ok(protoc_path) = std::env::var("PROTOC") {
        println!("cargo:warning=Using protoc from path: {}", protoc_path);
    } else {
        // Look for protoc in the system path
        println!("cargo:warning=No PROTOC env var set, using system protoc");
    }

    // Tell Cargo to rerun this script if the proto file changes
    println!("cargo:rerun-if-changed=proto/leak_detection_api.proto");

    // Invoke protoc directly to generate the files
    println!("cargo:warning=Attempting to invoke protoc directly");
    let status = std::process::Command::new("protoc")
        .arg("--rust_out=./src/proto")
        .arg("--proto_path=./proto")
        .arg("./proto/leak_detection_api.proto")
        .status();

    match status {
        Ok(exit) => println!("cargo:warning=protoc exited with: {}", exit),
        Err(e) => println!("cargo:warning=Failed to run protoc: {}", e),
    }
}
EOL

# Create docker-compose.yml file
cat > docker-compose.yml << 'EOL'
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
      - PROTOC=/usr/bin/protoc
      - CORS_ALLOWED_ORIGINS=http://localhost:3001,http://webapp:3001
    volumes:
      - /usr/bin/protoc:/usr/bin/protoc:ro
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
      dockerfile: Dockerfile
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
docker-compose up -d --build

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
  exit 1
fi 