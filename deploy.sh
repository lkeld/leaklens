#!/bin/bash
set -e

echo "============================================"
echo "     LeakLens Unified Deployment Script     "
echo "============================================"

# Set default values for variables
docker_compose_cmd="docker-compose"

# Function to setup server environment
setup_environment() {
  echo "Checking system environment..."
  
  # Check OS type
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$NAME
    OS_VERSION=$VERSION_ID
    echo "Detected OS: $OS_NAME $OS_VERSION"
  else
    echo "Warning: Unable to determine OS type. Proceeding with default settings."
    OS_NAME="Unknown"
  fi
  
  # Install essential tools
  echo "Checking for essential tools..."
  if ! command -v curl &> /dev/null; then
    echo "Installing curl..."
    if [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]]; then
      sudo apt-get update && sudo apt-get install -y curl
    elif [[ "$OS_NAME" == *"CentOS"* ]] || [[ "$OS_NAME" == *"Red Hat"* ]]; then
      sudo yum install -y curl
    else
      echo "Warning: Unable to install curl automatically. Manual installation may be required."
    fi
  fi
  
  if ! command -v tar &> /dev/null; then
    echo "Installing tar..."
    if [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]]; then
      sudo apt-get update && sudo apt-get install -y tar
    elif [[ "$OS_NAME" == *"CentOS"* ]] || [[ "$OS_NAME" == *"Red Hat"* ]]; then
      sudo yum install -y tar
    else
      echo "Warning: Unable to install tar automatically. Manual installation may be required."
    fi
  fi
  
  # Create necessary directories
  echo "Creating project directories..."
  mkdir -p api_server/src/{bin,api} api_server/proto webapp/{app,public,components}
}

# Call setup function at the start
setup_environment

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
    echo "Docker is not installed. Attempting to install Docker..."
    
    # Check if we're running on Ubuntu/Debian
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update
      sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    else
      echo "Error: Could not install Docker automatically."
      echo "Please install Docker manually using instructions at: https://docs.docker.com/engine/install/"
      exit 1
    fi
  fi

  # Check Docker version and features
  DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
  echo "Docker version: $DOCKER_VERSION"
  
  # Check if Docker Compose is available
  if ! command -v docker-compose &> /dev/null; then
    if docker compose version &> /dev/null; then
      echo "Using Docker Compose plugin"
      # Create docker-compose alias if it doesn't exist
      if ! command -v docker-compose &> /dev/null; then
        echo "Creating docker-compose alias for docker compose"
        docker_compose_cmd="docker compose"
      fi
    else
      echo "Docker Compose not found. Attempting to install Docker Compose..."
      
      # Use Docker Compose V2 plugin method
      COMPOSE_VERSION="v2.17.2"
      sudo mkdir -p /usr/local/lib/docker/cli-plugins
      sudo curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
      sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
      
      # Create alias
      docker_compose_cmd="docker compose"
    fi
  else
    docker_compose_cmd="docker-compose"
  fi
}

# Function to check if container needs rebuilding
needs_rebuild() {
  local service=$1
  local changed_files=$2
  
  if [[ -z "$($docker_compose_cmd ps -q $service 2>/dev/null)" ]]; then
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
  $docker_compose_cmd down -v || true
  docker image prune -af --filter "label=com.docker.compose.project=leaklens" || true
  echo "Docker cleanup completed."
}

# Function to build and start locally
local_deploy() {
  # Stop any existing containers
  echo "Stopping any existing LeakLens containers..."
  $docker_compose_cmd down || true

  # Clean up any dangling images to free space
  echo "Cleaning up dangling Docker images..."
  docker image prune -f || true

  # Pre-build check: Verify that required files exist
  echo "Checking for required source files..."
  
  # Check for Rust API files
  if [ ! -f "api_server/Cargo.toml" ] || [ ! -f "api_server/Cargo.lock" ]; then
    echo "Creating Rust project files in api_server directory..."
    mkdir -p api_server/src/bin api_server/src/api api_server/proto
    
    # Create a minimal Cargo.toml file
    cat > api_server/Cargo.toml << 'EOT'
[package]
name = "api_server"
version = "0.1.0"
edition = "2021"

[dependencies]
actix-web = "4.4.0"
actix-cors = "0.6.4"
dotenv = "0.15.0"
tokio = { version = "1.33.0", features = ["full"] }
serde = { version = "1.0.188", features = ["derive"] }
serde_json = "1.0.107"
env_logger = "0.10.0"
log = "0.4.20"
sqlx = { version = "0.7.2", features = ["runtime-tokio-rustls", "postgres"] }
chrono = { version = "0.4.31", features = ["serde"] }
uuid = { version = "1.4.1", features = ["v4", "serde"] }
prost = "0.12.1"
prost-types = "0.12.1"
tonic = "0.10.2"
anyhow = "1.0.75"
thiserror = "1.0.49"
regex = "1.9.5"
EOT

    # Create a minimal Cargo.lock file
    cat > api_server/Cargo.lock << 'EOT'
# This file is automatically @generated by Cargo.
# It is not intended for manual editing.
version = 3

[[package]]
name = "api_server"
version = "0.1.0"
dependencies = [
 "actix-cors",
 "actix-web",
 "anyhow",
 "chrono",
 "dotenv",
 "env_logger",
 "log",
 "prost",
 "prost-types",
 "regex",
 "serde",
 "serde_json",
 "sqlx",
 "thiserror",
 "tokio",
 "tonic",
 "uuid",
]
EOT

    # Create minimal source files to allow Docker build to succeed
    cat > api_server/src/bin/api_server.rs << 'EOT'
fn main() {
    println!("LeakLens API Server");
}
EOT

    cat > api_server/src/bin/test_credential_check.rs << 'EOT'
fn main() {
    println!("Test Credential Check");
}
EOT

    # Create build.rs if it doesn't exist
    if [ ! -f "api_server/build.rs" ]; then
      cat > api_server/build.rs << 'EOT'
fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("cargo:rerun-if-changed=proto");
    Ok(())
}
EOT
    fi

    # Create a minimal swagger.yaml file
    if [ ! -f "api_server/swagger.yaml" ]; then
      cat > api_server/swagger.yaml << 'EOT'
openapi: 3.0.0
info:
  title: LeakLens API
  version: 1.0.0
paths:
  /health:
    get:
      summary: Health check endpoint
      responses:
        '200':
          description: Server is healthy
EOT
    fi

    echo "Created minimal Rust project files."
  fi
  
  # Check for webapp files
  if [ ! -f "webapp/package.json" ]; then
    echo "Creating webapp files..."
    mkdir -p webapp/app webapp/public webapp/components
    
    # Create a minimal package.json
    cat > webapp/package.json << 'EOT'
{
  "name": "leaklens-webapp",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.3",
    "react": "^18",
    "react-dom": "^18"
  },
  "devDependencies": {
    "@types/node": "^20",
    "@types/react": "^18",
    "@types/react-dom": "^18",
    "typescript": "^5"
  }
}
EOT

    # Create a minimal package-lock.json
    cat > webapp/package-lock.json << 'EOT'
{
  "name": "leaklens-webapp",
  "version": "0.1.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "leaklens-webapp",
      "version": "0.1.0",
      "dependencies": {
        "next": "14.0.3",
        "react": "^18",
        "react-dom": "^18"
      },
      "devDependencies": {
        "@types/node": "^20",
        "@types/react": "^18",
        "@types/react-dom": "^18",
        "typescript": "^5"
      }
    }
  }
}
EOT

    # Create a minimal Next.js app structure
    cat > webapp/next.config.mjs << 'EOT'
/** @type {import('next').NextConfig} */
const nextConfig = {};
export default nextConfig;
EOT

    cat > webapp/tsconfig.json << 'EOT'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
EOT

    # Create a basic page
    mkdir -p webapp/app
    cat > webapp/app/page.tsx << 'EOT'
export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <h1 className="text-4xl font-bold mb-4">Welcome to LeakLens</h1>
      <p>Your password security solution.</p>
    </main>
  )
}
EOT

    cat > webapp/app/layout.tsx << 'EOT'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'LeakLens - Password Security Solution',
  description: 'Check if your passwords have been exposed in data breaches',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  )
}
EOT

    # Create a minimal CSS file
    cat > webapp/app/globals.css << 'EOT'
:root {
  --foreground-rgb: 0, 0, 0;
  --background-rgb: 255, 255, 255;
}

body {
  color: rgb(var(--foreground-rgb));
  background: rgb(var(--background-rgb));
}
EOT

    # Create a public folder with favicon
    mkdir -p webapp/public
    echo "Created minimal webapp files."
  fi

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
      $docker_compose_cmd build
      touch .last_api_build
      touch .last_web_build
    else
      echo "Skipping build as no changes detected."
    fi
  else
    echo "Building LeakLens container (full build)..."
    $docker_compose_cmd build --no-cache || {
      echo "Error: Failed to build Docker images."
      echo "Checking Docker build logs..."
      $docker_compose_cmd logs
      exit 1
    }
  fi

  echo "Starting services..."
  $docker_compose_cmd up -d || {
    echo "Error: Failed to start Docker containers."
    echo "Checking logs..."
    $docker_compose_cmd logs
    exit 1
  }

  # Wait a moment for containers to fully start
  echo "Waiting for services to start..."
  sleep 10

  # Check if containers are running
  if $docker_compose_cmd ps | grep -q "leaklens"; then
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
    echo "To view logs: $docker_compose_cmd logs -f"
    echo "To stop the service: $docker_compose_cmd down"
  else
    echo "❌ Error: Failed to start LeakLens containers."
    echo "Checking logs..."
    $docker_compose_cmd logs
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

# Main deployment logic
echo "Starting LeakLens deployment process..."

# Set up error handling
trap 'echo "Error: Deployment failed. Check logs above for details."; exit 1' ERR

# Check Docker install
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
echo "You can now access LeakLens at http://localhost:8080 (or your server IP:8080)"
