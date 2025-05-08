#!/bin/bash
set -e

echo "============================================"
echo "     LeakLens Unified Deployment Script     "
echo "============================================"

# Set default values for variables
docker_compose_cmd="docker-compose"
USE_PREBUILT=false
BUILD_ONLY=false
PREBUILT_DIR="./build/prebuilt"
SSH_KEY_FILE=""

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
  
  # Check for jq if we're building a prebuilt package
  if [ "$BUILD_ONLY" == "true" ] && ! command -v jq &> /dev/null; then
    echo "Installing jq (required for package.json processing)..."
    if [[ "$OS_NAME" == *"Ubuntu"* ]] || [[ "$OS_NAME" == *"Debian"* ]]; then
      sudo apt-get update && sudo apt-get install -y jq
    elif [[ "$OS_NAME" == *"CentOS"* ]] || [[ "$OS_NAME" == *"Red Hat"* ]]; then
      sudo yum install -y jq
    else
      echo "Error: jq is required for creating prebuilt packages. Please install it manually."
      echo "Visit: https://stedolan.github.io/jq/download/"
      exit 1
    fi
  fi
  
  # Create necessary directories
  echo "Creating project directories..."
  mkdir -p api_server/src/bin api_server/src/api api_server/proto 
  mkdir -p webapp/app webapp/public webapp/components
  mkdir -p build/prebuilt/api build/prebuilt/webapp build/prebuilt/scripts
}

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
  echo "  -p, --prebuilt       Use prebuilt binaries (for faster deployment on slow servers)"
  echo "  -b, --build-only     Build binaries but don't deploy (creates prebuilt package)"
  echo "  -k, --key FILE       Specify a custom SSH key file for remote deployment"
  echo ""
  echo "Examples:"
  echo "  ./deploy.sh                  # Standard local deployment"
  echo "  ./deploy.sh -f               # Fast local deployment (incremental build)"
  echo "  ./deploy.sh -s 13.236.185.53 # Deploy to remote server" 
  echo "  ./deploy.sh -c               # Clean deployment (full rebuild)"
  echo "  ./deploy.sh -b               # Build binaries for later deployment"
  echo "  ./deploy.sh -p -s 13.236.185.53 # Deploy prebuilt binaries to server"
  echo "  ./deploy.sh -k ~/my-key.pem -s 13.236.185.53 # Deploy using specific SSH key"
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
  local custom_key=$2
  local SERVER_USER=${3:-"azureuser"}
  local SERVER_PORT=${4:-"22"}
  local SERVER_DIR=${5:-"/var/www/leakcheck"}
  
  echo "Deploying to remote server: $SERVER_HOST"
  
  # Define SSH key location based on OS
  local SSH_KEY_FILE=""
  if [ -n "$custom_key" ]; then
    # Use the custom key if provided
    SSH_KEY_FILE="$custom_key"
  elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "cygwin"* ]]; then
    # Windows path format
    SSH_KEY_FILE="C:/Users/luke/Downloads/LeakLens_key.pem"
    # Convert Windows path to appropriate format for the current shell
    SSH_KEY_FILE=$(echo $SSH_KEY_FILE | sed 's/\\/\//g')
  else
    # Linux/Mac path format - provide a sensible default, but allow override
    SSH_KEY_FILE="${SSH_KEY_FILE:-"$HOME/.ssh/LeakLens_key.pem"}"
  fi
  
  # Ensure the key file has correct permissions (ignored on Windows)
  if [[ "$OSTYPE" != "msys"* && "$OSTYPE" != "win32"* && "$OSTYPE" != "cygwin"* ]]; then
    chmod 600 "$SSH_KEY_FILE" || echo "Warning: Could not set permissions on key file. This might cause SSH to reject the key."
  fi
  
  # Check if the key file exists
  if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Error: SSH key file not found at $SSH_KEY_FILE"
    echo "Please make sure the file exists and the path is correct."
    exit 1
  fi
  
  echo "Using SSH key: $SSH_KEY_FILE"
  
  # Common SSH options
  local SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  
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
  scp -i "$SSH_KEY_FILE" $SSH_OPTS -P $SERVER_PORT leaklens-deploy.tar.gz $SERVER_USER@$SERVER_HOST:~/ || {
    echo "ERROR: Failed to copy files to server"
    exit 1
  }
  
  echo "Setting up and deploying on the server..."
  # Execute commands on the server using the SSH key
  ssh -i "$SSH_KEY_FILE" $SSH_OPTS -p $SERVER_PORT $SERVER_USER@$SERVER_HOST << EOF
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

# Build prebuilt package for later deployment
build_prebuilt_package() {
  echo "Building prebuilt package for deployment..."
  
  # Create needed directories with -p to ensure all parent directories are created
  mkdir -p "$PREBUILT_DIR/api" "$PREBUILT_DIR/webapp" "$PREBUILT_DIR/scripts"
  
  # Build the API server (Rust)
  echo "Building Rust API server for static linking (musl)..."
  cd api_server
  if ! command -v cargo &> /dev/null; then
    echo "Error: Rust (cargo) not installed. Please install Rust to build the API server."
    echo "Visit https://rustup.rs/ for installation instructions."
    exit 1
  fi
  # Add the musl target if it's not already installed
  if ! rustup target list --installed | grep -q "x86_64-unknown-linux-musl"; then
    echo "x86_64-unknown-linux-musl target not found, installing..."
    rustup target add x86_64-unknown-linux-musl
  fi
  
  # Build for the musl target
  cargo build --release --target x86_64-unknown-linux-musl
  
  mkdir -p "../$PREBUILT_DIR/api"
  # Copy the statically linked binary from the correct target directory
  cp target/x86_64-unknown-linux-musl/release/api_server "../$PREBUILT_DIR/api/api_server"
  cp swagger.yaml "../$PREBUILT_DIR/api/" 2>/dev/null || echo "No swagger.yaml found, skipping..."
  cd ..
  
  # Build the webapp (Next.js)
  echo "Building Next.js webapp..."
  cd webapp
  if ! command -v npm &> /dev/null; then
    echo "Error: Node.js not installed. Please install Node.js to build the webapp."
    echo "Visit https://nodejs.org/ for installation instructions."
    exit 1
  fi
  
  # Install dependencies if node_modules doesn't exist
  if [ ! -d "node_modules" ]; then
    echo "Installing npm dependencies..."
    npm ci --no-fund --no-audit --prefer-offline --legacy-peer-deps
  fi
  
  # Build the Next.js app
  echo "Building Next.js app..."
  NODE_OPTIONS=--max_old_space_size=4096 npm run build
  
  # Create package.json with only production dependencies
  if command -v jq &> /dev/null; then
    echo "Creating minimal package.json with jq..."
    jq 'del(.devDependencies) | .dependencies."next" = "15.2.4" | .dependencies."react" = "^18" | .dependencies."react-dom" = "^18"' "$(pwd)/package.json" > "../$PREBUILT_DIR/webapp/package.json" || {
      echo "Failed to process package.json with jq. Falling back to manual method."
      cat > "../$PREBUILT_DIR/webapp/package.json" << 'EOT'
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
    "next": "15.2.4",
    "react": "^18",
    "react-dom": "^18",
    "vaul": "^0.9.6"
  }
}
EOT
    }
  else
    echo "Creating minimal package.json without jq (fallback method)..."
    cat > "../$PREBUILT_DIR/webapp/package.json" << 'EOT'
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
    "next": "15.2.4",
    "react": "^18",
    "react-dom": "^18",
    "vaul": "^0.9.6"
  }
}
EOT
  fi
  
  # Copy the built app
  cp -r .next "../$PREBUILT_DIR/webapp/"
  cp -r public "../$PREBUILT_DIR/webapp/"
  cd ..
  
  # Create the Nginx configuration file for prebuilt deployment
  cat > "$PREBUILT_DIR/nginx.default.conf" << 'EOT_NGINX_CONF'
server {
    listen 80;
    server_name leaklens.0x.lv www.leaklens.0x.lv;

    # ACME challenge for Certbot
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name leaklens.0x.lv www.leaklens.0x.lv;

    ssl_certificate /etc/letsencrypt/live/leaklens.0x.lv/fullchain.pem; #managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/leaklens.0x.lv/privkey.pem; #managed by Certbot

    # SSL Best Practices
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m; # about 40000 sessions
    ssl_session_tickets off;
    # add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always; # Consider enabling HSTS after confirming everything works

    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOT_NGINX_CONF

  # Create a minimal Docker Compose file for prebuilt deployment
  # Use environment's GOOGLE_CLIENT_ID if set, otherwise use a placeholder
  local google_client_id_value=${GOOGLE_CLIENT_ID:-"YOUR_GOOGLE_CLIENT_ID_HERE_PLEASE_REPLACE"}
  local google_client_secret_value=${GOOGLE_CLIENT_SECRET:-"YOUR_GOOGLE_CLIENT_SECRET_HERE_PLEASE_REPLACE"}
  local google_refresh_token_value=${GOOGLE_REFRESH_TOKEN:-"YOUR_GOOGLE_REFRESH_TOKEN_HERE_PLEASE_REPLACE"}
  local jwt_secret_value=${JWT_SECRET:-"YOUR_JWT_SECRET_HERE_PLEASE_REPLACE"}
  local database_url_value=${DATABASE_URL:-"YOUR_DATABASE_URL_HERE_PLEASE_REPLACE"}
  
  if [ "$google_client_id_value" == "YOUR_GOOGLE_CLIENT_ID_HERE_PLEASE_REPLACE" ]; then
    echo "Warning: GOOGLE_CLIENT_ID is not set in your environment. A placeholder will be used."
  fi
  if [ "$google_client_secret_value" == "YOUR_GOOGLE_CLIENT_SECRET_HERE_PLEASE_REPLACE" ]; then
    echo "Warning: GOOGLE_CLIENT_SECRET is not set in your environment. A placeholder will be used."
  fi
  if [ "$google_refresh_token_value" == "YOUR_GOOGLE_REFRESH_TOKEN_HERE_PLEASE_REPLACE" ]; then
    echo "Warning: GOOGLE_REFRESH_TOKEN is not set in your environment. A placeholder will be used."
  fi
  if [ "$jwt_secret_value" == "YOUR_JWT_SECRET_HERE_PLEASE_REPLACE" ]; then
    echo "Warning: JWT_SECRET is not set in your environment. A placeholder will be used."
  fi
  if [ "$database_url_value" == "YOUR_DATABASE_URL_HERE_PLEASE_REPLACE" ]; then
    echo "Warning: DATABASE_URL is not set in your environment. A placeholder will be used."
  fi

  cat > "$PREBUILT_DIR/docker-compose.yml" << EOT
version: '3.8'

services:
  leaklens:
    image: leaklens-prebuilt
    build:
      context: .
      dockerfile: Dockerfile.prebuilt
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /var/www/certbot:/var/www/certbot:ro
    environment:
      # These will be sourced from the .env file on the deployment server
      - GOOGLE_CLIENT_ID=\${GOOGLE_CLIENT_ID}
      - GOOGLE_CLIENT_SECRET=\${GOOGLE_CLIENT_SECRET}
      - GOOGLE_REFRESH_TOKEN=\${GOOGLE_REFRESH_TOKEN}
      - JWT_SECRET=\${JWT_SECRET}
      - DATABASE_URL=\${DATABASE_URL}
      # Add any other necessary environment variables for your api_server here.
      # Ensure they also use the \${VAR_NAME} syntax if they should be sourced from .env on the server.
      # For example:
      # - OTHER_VARIABLE=\${OTHER_VARIABLE}
EOT

  # Create a simplified Dockerfile for prebuilt deployment
  cat > "$PREBUILT_DIR/Dockerfile.prebuilt" << EOT
FROM debian:bullseye-slim

# Set environment variable to avoid debconf errors
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies, Nginx, Node.js
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl1.1 \
    nginx \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update && apt-get install -y \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

# Create needed directories
RUN mkdir -p /app/api /app/webapp /app/scripts /var/www/certbot && chown www-data:www-data /var/www/certbot

# Create startup script
COPY scripts/start.sh /app/scripts/
RUN chmod +x /app/scripts/start.sh

# Copy dummy SSL certificates to allow Nginx to start
# These will be overridden by real certs mounted from the host after Certbot runs
COPY dummy_certs/ /etc/letsencrypt/

# Copy the Rust API build artifact
WORKDIR /app/api
COPY api/* ./

# Copy the Next.js webapp
WORKDIR /app/webapp
COPY webapp/package.json /app/webapp/
COPY webapp/.next /app/webapp/.next
COPY webapp/public /app/webapp/public

# Install production dependencies only
RUN npm install --production --no-fund --no-audit

# Configure Nginx
COPY nginx.default.conf /etc/nginx/sites-available/default

# Expose the port
EXPOSE 80

# Set working directory to the root so we can access the script
WORKDIR /app

# Set the startup command
CMD ["/app/scripts/start.sh"]
EOT

  # Create the startup script
  mkdir -p "$PREBUILT_DIR/scripts"
  cat > "$PREBUILT_DIR/scripts/start.sh" << 'EOT'
#!/bin/bash
set -e

echo "Starting LeakLens application..."

# Start the API server in the background
echo "Starting API server..."
cd /app/api
./api_server &
API_PID=$!

# Start the Next.js app in the background
echo "Starting Next.js webapp..."
cd /app/webapp
npm start &
NEXT_PID=$!

echo "Starting Nginx..."
# Start Nginx in the foreground
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
EOT

  # Generate dummy SSL certificates for Nginx to start before Certbot runs
  echo "Generating dummy SSL certificates..."
  DUMMY_CERT_DIR="$PREBUILT_DIR/dummy_certs"
  DUMMY_LIVE_DIR="$DUMMY_CERT_DIR/live/leaklens.0x.lv"
  DUMMY_ARCHIVE_DIR="$DUMMY_CERT_DIR/archive/leaklens.0x.lv"
  mkdir -p "$DUMMY_LIVE_DIR"
  mkdir -p "$DUMMY_ARCHIVE_DIR"

  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout "$DUMMY_ARCHIVE_DIR/privkey1.pem" \
    -out "$DUMMY_ARCHIVE_DIR/fullchain1.pem" \
    -subj "/CN=leaklens.0x.lv" > /dev/null 2>&1

  # Create symlinks similar to Certbot's structure
  ln -s ../../archive/leaklens.0x.lv/privkey1.pem "$DUMMY_LIVE_DIR/privkey.pem"
  ln -s ../../archive/leaklens.0x.lv/fullchain1.pem "$DUMMY_LIVE_DIR/fullchain.pem"
  ln -s ../../archive/leaklens.0x.lv/fullchain1.pem "$DUMMY_LIVE_DIR/cert.pem" # Nginx might also look for cert.pem
  ln -s ../../archive/leaklens.0x.lv/fullchain1.pem "$DUMMY_LIVE_DIR/chain.pem" # and chain.pem

  # Create a tar.gz of the prebuilt package
  echo "Creating prebuilt package archive..."
  tar -czf leaklens-prebuilt.tar.gz -C "$PREBUILT_DIR" .
  
  echo "✅ Prebuilt package created successfully: leaklens-prebuilt.tar.gz"
  echo "Use './deploy.sh -p -s YOUR_SERVER_IP' to deploy this package to your server."
}

# Deploy the prebuilt package
deploy_prebuilt() {
  local target=$1
  local custom_key=$2
  
  if [ ! -f "leaklens-prebuilt.tar.gz" ]; then
    echo "Error: No prebuilt package found. Please run './deploy.sh -b' first to create a prebuilt package."
    exit 1
  fi
  
  if [ "$target" == "local" ]; then
    echo "Deploying prebuilt package locally..."
    
    # Extract the prebuilt package
    mkdir -p prebuilt_deploy
    tar -xzf leaklens-prebuilt.tar.gz -C prebuilt_deploy
    
    # Deploy using Docker
    cd prebuilt_deploy
    $docker_compose_cmd build
    $docker_compose_cmd up -d
    cd ..
    
    echo "✅ Prebuilt LeakLens is now running locally!"
    echo "You can access LeakLens at: http://localhost:8080"
  else
    echo "Deploying prebuilt package to server: $target"
    
    # Define the default SSH user and server directory
    local SERVER_USER=${3:-"azureuser"}
    local SERVER_DIR=${4:-"/var/www/leakcheck"}
    
    # Define SSH key location based on OS
    local SSH_KEY_FILE=""
    if [ -n "$custom_key" ]; then
      # Use the custom key if provided
      SSH_KEY_FILE="$custom_key"
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "cygwin"* ]]; then
      # Windows path format
      SSH_KEY_FILE="C:/Users/luke/Downloads/LeakLens_key.pem"
      # Convert Windows path to appropriate format for the current shell
      SSH_KEY_FILE=$(echo $SSH_KEY_FILE | sed 's/\\/\//g')
    else
      # Linux/Mac path format - provide a sensible default, but allow override
      SSH_KEY_FILE="${SSH_KEY_FILE:-"$HOME/.ssh/LeakLens_key.pem"}"
    fi
    
    echo "Using SSH key file: $SSH_KEY_FILE"
    
    # Ensure the key file has correct permissions (ignored on Windows)
    if [[ "$OSTYPE" != "msys"* && "$OSTYPE" != "win32"* && "$OSTYPE" != "cygwin"* ]]; then
      chmod 600 "$SSH_KEY_FILE" || echo "Warning: Could not set permissions on key file. This might cause SSH to reject the key."
    fi
    
    # Verify the key file exists
    if [ ! -f "$SSH_KEY_FILE" ]; then
      echo "Error: SSH key file not found at $SSH_KEY_FILE"
      echo "Please ensure the file exists and the path is correct."
      exit 1
    fi
    
    # Common SSH options
    local SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    
    # Copy the prebuilt package to the server using the key
    echo "Copying prebuilt package to server..."
    scp -i "$SSH_KEY_FILE" $SSH_OPTS "leaklens-prebuilt.tar.gz" "$SERVER_USER@$target:~/"
    
    # SSH into the server and deploy
    echo "Deploying on server..."
    ssh -i "$SSH_KEY_FILE" $SSH_OPTS "$SERVER_USER@$target" << EOF
      set -e # Exit immediately if a command exits with a non-zero status.
      
      # Create the deployment directory if it doesn't exist
      mkdir -p $SERVER_DIR
      
      # Extract the prebuilt package
      echo "Extracting prebuilt package on server..."
      tar -xzf ~/leaklens-prebuilt.tar.gz -C $SERVER_DIR
      
      # Deploy using Docker
      cd $SERVER_DIR
      echo "Building Docker image on server..."
      docker-compose build
      echo "Starting Docker containers on server..."
      docker-compose up -d
      
      # Clean up
      echo "Cleaning up archive on server..."
      rm ~/leaklens-prebuilt.tar.gz
EOF
    
    echo "✅ Prebuilt LeakLens deployment to server $target initiated."
    echo "You can access LeakLens at: http://$target:8080"
  fi
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
    -p|--prebuilt)
      USE_PREBUILT=true
      shift
      ;;
    -b|--build-only)
      BUILD_ONLY=true
      shift
      ;;
    -k|--key)
      SSH_KEY_FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Main deployment logic
echo "Starting LeakLens deployment process..."

# Call setup function
setup_environment

# Set up error handling
trap 'echo "Error: Deployment failed. Check logs above for details."; exit 1' ERR

# Check if we're just building a prebuilt package
if [ "$BUILD_ONLY" == "true" ]; then
  echo "Building prebuilt package only, no deployment..."
  build_prebuilt_package
  echo "Prebuilt package built successfully. You can deploy it with: ./deploy.sh -p [-s SERVER_HOST]"
  exit 0
fi

# Check if we're using prebuilt package for deployment
if [ "$USE_PREBUILT" == "true" ]; then
  if [ "$SERVER_DEPLOY" == "true" ]; then
    echo "Deploying prebuilt package to server: $SERVER_HOST"
    deploy_prebuilt "$SERVER_HOST" "$SSH_KEY_FILE"
  else
    echo "Deploying prebuilt package locally"
    deploy_prebuilt "local" "$SSH_KEY_FILE"
  fi
  echo "Prebuilt deployment completed successfully!"
  exit 0
fi

# Regular deployment flow - only check Docker if not using prebuilt
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
  remote_deploy "$SERVER_HOST" "$SSH_KEY_FILE"
fi

if [ "$LOCAL_DEPLOY" == "true" ]; then
  local_deploy
fi

echo "Deployment completed successfully!"
echo "You can now access LeakLens at http://localhost:8080 (or your server IP:8080)"
