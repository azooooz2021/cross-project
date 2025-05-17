#!/bin/bash

# Setup logging
LOGFILE="/var/log/datahub_install.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting DataHub installation script"

# Error handling function
handle_error() {
  local exit_code=$?
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Command failed with exit code $exit_code"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Check $LOGFILE for details"
  exit $exit_code
}

# Set trap for error handling
trap 'handle_error' ERR

# Create systemd service for DataHub
create_systemd_service() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating DataHub systemd service"
  cat > /etc/systemd/system/datahub.service << EOF
[Unit]
Description=DataHub Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/datahub
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable datahub.service
  echo "$(date '+%Y-%m-%d %H:%M:%S') - DataHub service created and enabled"
}

# Update system and install dependencies
echo "$(date '+%Y-%m-%d %H:%M:%S') - Updating system and installing dependencies"
apt-get update && apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  gnupg \
  lsb-release \
  jq

# Install Docker
if ! command -v docker &> /dev/null; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable"
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io
  systemctl enable docker
  systemctl start docker
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Docker installed successfully"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Docker already installed"
fi

# Install Docker Compose plugin
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"
if ! [ -f "$DOCKER_COMPOSE_PATH" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing Docker Compose..."
  curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_PATH
  chmod +x $DOCKER_COMPOSE_PATH
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Docker Compose installed successfully"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Docker Compose already installed"
fi

# Ensure pip is installed and updated
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing/updating Python dependencies"
apt-get install -y python3-pip
python3 -m pip install --upgrade pip wheel setuptools

# Install DataHub CLI
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing DataHub CLI"
python3 -m pip install --upgrade acryl-datahub

# Define current user
CURRENT_USER="${SUDO_USER:-$USER}"
if [ "$CURRENT_USER" = "root" ]; then
  # If running as root with no sudo user, use the admin user
  CURRENT_USER=$(grep -m1 "sudo\|admin" /etc/passwd | cut -d: -f1)
  if [ -z "$CURRENT_USER" ]; then
    # Fallback to a common admin username if we can't find one
    CURRENT_USER="adminuser"
  fi
fi
echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting up for user: $CURRENT_USER"

# Add user to docker group
if getent passwd "$CURRENT_USER" > /dev/null; then
  usermod -aG docker $CURRENT_USER
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Added $CURRENT_USER to docker group"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: User $CURRENT_USER not found, skipping docker group assignment"
fi

# Prepare DataHub directory
echo "$(date '+%Y-%m-%d %H:%M:%S') - Preparing DataHub directory"
mkdir -p /opt/datahub
cd /opt/datahub

# Download docker-compose file
echo "$(date '+%Y-%m-%d %H:%M:%S') - Downloading docker-compose.yml"
curl -L https://raw.githubusercontent.com/datahub-project/datahub/master/docker/quickstart/docker-compose.quickstart.yml -o docker-compose.yml

# Create a healthcheck script
echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating healthcheck script"
cat > /opt/datahub/healthcheck.sh << 'EOF'
#!/bin/bash
LOGFILE="/var/log/datahub_healthcheck.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Running DataHub healthcheck" >> $LOGFILE

# Check if docker is running
if ! systemctl is-active --quiet docker; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Docker is not running, starting it" >> $LOGFILE
  systemctl start docker
fi

# Check if containers are running
cd /opt/datahub
RUNNING_CONTAINERS=$(docker-compose ps --services --filter "status=running" | wc -l)
EXPECTED_CONTAINERS=$(docker-compose config --services | wc -l)

if [ "$RUNNING_CONTAINERS" -lt "$EXPECTED_CONTAINERS" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Some containers are not running. Starting DataHub..." >> $LOGFILE
  docker-compose up -d
fi

# Check if frontend is accessible
if ! curl -s -o /dev/null -w '%{http_code}' http://localhost:9002 | grep -q "200"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Frontend is not accessible. Restarting DataHub..." >> $LOGFILE
  docker-compose restart datahub-datahub-frontend-react
fi
EOF

chmod +x /opt/datahub/healthcheck.sh

# Create a cron job to run the healthcheck
echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting up cron job for healthcheck"
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/datahub/healthcheck.sh") | crontab -

# Set proper ownership
if getent passwd "$CURRENT_USER" > /dev/null; then
  chown -R "$CURRENT_USER":"$CURRENT_USER" /opt/datahub
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Set ownership of /opt/datahub to $CURRENT_USER"
fi

# Create systemd service
create_systemd_service

# Start DataHub containers
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting DataHub containers..."
cd /opt/datahub
docker-compose up -d

# Wait for GMS to be healthy with improved error handling
echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for GMS (http://localhost:8080/health)..."
GMS_HEALTHY=false
for i in {1..30}; do
  if curl -s http://localhost:8080/health | grep -q "UP"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ GMS is healthy!"
    GMS_HEALTHY=true
    break
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - GMS not healthy yet... ($i/30)"
    sleep 10
  fi
done

if [ "$GMS_HEALTHY" = false ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: GMS did not become healthy in the allocated time"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking container logs for issues..."
  docker-compose logs --tail=50 datahub-gms >> $LOGFILE
fi

# Wait for frontend to respond with improved error handling
echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for Frontend (http://localhost:9002)..."
FRONTEND_HEALTHY=false
for i in {1..30}; do
  STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:9002 || echo "000")
  if [ "$STATUS" = "200" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ✅ Frontend is accessible!"
    FRONTEND_HEALTHY=true
    break
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Frontend not ready yet... ($i/30) - Status: $STATUS"
    sleep 10
  fi
done

if [ "$FRONTEND_HEALTHY" = false ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: Frontend did not become accessible in the allocated time"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking container logs for issues..."
  docker-compose logs --tail=50 datahub-frontend-react >> $LOGFILE
  
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempting to restart the frontend container..."
  docker-compose restart datahub-datahub-frontend-react
fi

# Open firewall ports if ufw is enabled
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Opening ports for DataHub..."
  ufw allow 9002/tcp
  ufw allow 8080/tcp
fi

# Ensure ports are open in Azure NSG via iptables
echo "$(date '+%Y-%m-%d %H:%M:%S') - Ensuring ports are open in iptables..."
iptables -A INPUT -p tcp --dport 9002 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Output access info
PUBLIC_IP=$(curl -s http://ifconfig.me)
echo ""
echo "============================================================"
echo "🎉 DataHub installation completed!"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Installation complete"
echo "Access it here:"
echo " - Local:   http://localhost:9002"
echo " - Public:  http://$PUBLIC_IP:9002"
echo ""
echo "Default credentials:"
echo " - Username: datahub"
echo " - Password: datahub"
echo ""
echo "Installation log: $LOGFILE"
echo "DataHub service: systemctl status datahub"
echo "============================================================"

# Final status check
if systemctl is-active --quiet datahub && [ "$FRONTEND_HEALTHY" = true ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - DataHub is running successfully" >> $LOGFILE
  exit 0
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: DataHub may not be fully operational" >> $LOGFILE
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Please check the logs and try restarting with: systemctl restart datahub" >> $LOGFILE
  exit 1
fi
