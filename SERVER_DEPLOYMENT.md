# LeakLens Server Deployment Guide

This guide provides step-by-step instructions for deploying LeakLens on a Linux server using Docker.

## Prerequisites

- A Linux server (Ubuntu, Debian, etc.)
- Docker and Docker Compose installed
- Git installed
- SSH access to your server

## Installation Steps

1. **Install Docker and Docker Compose** (if not already installed)

   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   
   # Add your user to the docker group
   sudo usermod -aG docker $USER
   
   # Install Docker Compose
   sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   
   # Verify installations
   docker --version
   docker-compose --version
   ```

2. **Clone the LeakLens repository**

   ```bash
   git clone https://github.com/lkeld/leaklens.git
   cd leaklens
   ```

3. **Deploy using the script**

   ```bash
   # Make the script executable
   chmod +x deploy.sh
   
   # Run the deployment script
   ./deploy.sh
   ```

   The script will:
   - Stop any existing LeakLens containers
   - Pull the latest code (if in a git repository)
   - Build and start the Docker containers
   - Display the URL where you can access LeakLens

4. **Accessing LeakLens**

   Once deployed, you can access LeakLens at:
   ```
   http://your-server-ip:8080
   ```

## Managing Your Deployment

- **View logs**:
  ```bash
  docker-compose logs -f
  ```

- **Stop the service**:
  ```bash
  docker-compose down
  ```

- **Restart the service**:
  ```bash
  docker-compose restart
  ```

- **Update to the latest version**:
  ```bash
  git pull
  docker-compose up -d --build
  ```

## Troubleshooting

- **Container not starting**: Check logs with `docker-compose logs`
- **Can't access the website**: Make sure port 8080 is open in your firewall
  ```bash
  sudo ufw allow 8080/tcp
  ```
- **Permission issues**: Make sure you have Docker permissions
  ```bash
  sudo chmod 666 /var/run/docker.sock
  ```

## Customization

You can customize your deployment by editing the `docker-compose.yml` file:
- Change the exposed port (default is 8080)
- Modify environment variables
- Add custom configurations

After making changes, restart the containers with:
```bash
docker-compose up -d
``` 