# LeakLens Server Deployment Guide

This guide provides step-by-step instructions for deploying LeakLens on a Debian/Ubuntu server using Docker.

## Prerequisites

- A Linux server (Debian/Ubuntu recommended)
- Root or sudo access to the server
- Basic knowledge of the command line

## Step 1: Install Docker and Docker Compose

```bash
# Update package lists
sudo apt-get update

# Install required packages
sudo apt-get install -y ca-certificates curl gnupg

# Set up Docker's apt repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# For Debian
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# For Ubuntu, use this instead:
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again
sudo apt-get update

# Install Docker packages
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add your user to the docker group (optional)
sudo usermod -aG docker $USER

# Verify installations
docker --version
docker-compose --version
```

You may need to log out and back in for the group changes to take effect.

## Step 2: Clone the Repository

```bash
# Create the directory where you want to deploy (adjust as needed)
sudo mkdir -p /var/www/leakcheck
sudo chown $USER:$USER /var/www/leakcheck

# Clone the repository
git clone https://github.com/lkeld/leaklens.git /var/www/leakcheck
cd /var/www/leakcheck
```

## Step 3: Deploy with the Script

Make the deployment script executable and run it:

```bash
sudo chmod +x run-on-server.sh
./run-on-server.sh
```

The script will:
1. Create a docker-compose.yml file
2. Stop any existing containers
3. Build and start the Docker containers
4. Show the URL where LeakLens is accessible

## Step 4: Access LeakLens

Once the deployment is complete, you can access LeakLens at:
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
  
- **OpenSSL build errors**: Make sure `make`, `gcc`, and `perl` are installed
  ```bash
  sudo apt-get install -y make gcc perl
  ```
  
- **Can't access the website**: Make sure port 8080 is open in your firewall
  ```bash
  sudo ufw allow 8080/tcp
  ```
  
- **Permission issues**: Make sure you have Docker permissions
  ```bash
  sudo chmod 666 /var/run/docker.sock
  ```

## Security Considerations

- Consider setting up HTTPS with a reverse proxy like Nginx
- Restrict access to the Docker socket
- Regularly update your Docker images and the underlying server

## Customization

You can customize your deployment by editing the `docker-compose.yml` file:
- Change the exposed port (default is 8080)
- Modify environment variables
- Add custom configurations

After making changes, restart the containers with:
```bash
docker-compose up -d
``` 