#!/bin/bash
# shellcheck disable=SC1091
set -e

# Get number of CPU cores
NUM_CORES=$(nproc)

# Create and set permissions for log files
touch /var/log/deploy.log /var/log/model-pull.log
chmod 666 /var/log/deploy.log /var/log/model-pull.log

# Set up logging for the deployment script
exec > >(tee /var/log/deploy.log) 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting deployment process with $NUM_CORES cores"

# Configure apt for parallel downloads
echo "Configuring apt for parallel downloads..."
cat > /etc/apt/apt.conf.d/80parallel-downloads << EOF
Acquire::Queue-Mode "host";
Acquire::http::Pipeline-Depth "5";
Acquire::http::Timeout "180";
Acquire::https::Pipeline-Depth "5";
Acquire::https::Timeout "180";
Acquire::http::Dl-Limit "50000";
Acquire::https::Dl-Limit "50000";
EOF

# Configure parallel make operations
echo "Configuring parallel make operations..."
cat > /etc/makepkg.conf << EOF
MAKEFLAGS="-j$NUM_CORES"
EOF

# Install CloudWatch agent
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing CloudWatch agent"
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch agent
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring CloudWatch agent"
mkdir -p /opt/aws/amazon-cloudwatch-agent/bin/
cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << 'CWAGENTCONFIG'
{
  "agent": {
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/deploy.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "${app_log_stream}"
          },
          {
            "file_path": "/var/log/model-pull.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "${model_pull_stream}"
          }
        ]
      }
    }
  }
}
CWAGENTCONFIG

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
systemctl start amazon-cloudwatch-agent

# Install dependencies using parallel processing
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing dependencies with parallel processing"
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    -o Acquire::Retries="3" \
    -o DPkg::MaxProcs="$NUM_CORES" \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    git \
    make \
    parallel

# Install Docker with parallel processing
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker with parallel processing"
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt and install Docker
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    --no-install-recommends \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    -o DPkg::MaxProcs="$NUM_CORES" \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-compose-plugin

# Configure Docker daemon
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Configuring Docker daemon"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKERCONFIG'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "metrics-addr" : "0.0.0.0:9323",
    "experimental" : true
}
DOCKERCONFIG

# Configure Docker permissions
usermod -aG docker ubuntu

# Single Docker restart after all configuration
systemctl daemon-reload
systemctl restart docker

# Wait for Docker to be ready
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for Docker to be ready..."
timeout 60 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done'

# Ensure docker socket has correct permissions
chmod 666 /var/run/docker.sock

# Configure Git and clone repository
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cloning repository"
cd /home/ubuntu || exit 1

if [ -z "${github_token}" ]; then
    echo "Error: github_token is not set"
    exit 1
fi

echo "${github_token}" > /root/.github-token
git clone "https://oauth2:${github_token}@github.com/rfomerand/ds_aws_docker.git"
chown -R ubuntu:ubuntu ds_aws_docker

# Deploy application
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Docker containers"
cd ds_aws_docker || exit 1

# Run docker compose with retry logic
MAX_COMPOSE_ATTEMPTS=3
COMPOSE_ATTEMPT=1

while [ $COMPOSE_ATTEMPT -le $MAX_COMPOSE_ATTEMPTS ]; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker compose attempt $COMPOSE_ATTEMPT of $MAX_COMPOSE_ATTEMPTS"
    if sudo -u ubuntu docker compose up -d; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker compose successfully started"
        break
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Docker compose attempt $COMPOSE_ATTEMPT failed"
        if [ $COMPOSE_ATTEMPT -eq $MAX_COMPOSE_ATTEMPTS ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to start Docker compose after $MAX_COMPOSE_ATTEMPTS attempts"
            exit 1
        fi
        sleep 30
        ((COMPOSE_ATTEMPT++))
    fi
done

# Create model pull script
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating model pull script"
cat > /root/pull-model.sh << 'PULLSCRIPT'
#!/bin/bash

# Set up logging
LOG_FILE="/var/log/model-pull.log"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Ensure all output is captured
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Log start of script
echo "================================================================="
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting model pull script with PID $$"
echo "================================================================="

# Function to check if docker container is running and healthy
check_container() {
    local container_name=$1
    local max_attempts=$2
    local attempt=1
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking status of container: $container_name"
    
    while [ $attempt -le $max_attempts ]; do
        # Check if container exists and is running
        if docker container inspect "$container_name" --format '{{.State.Running}}' 2>/dev/null | grep -q "true"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Container $container_name is running, checking API..."
            
            # Test Ollama API health
            if curl -s -f "http://localhost:11434/api/tags" >/dev/null 2>&1; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Ollama API is responding"
                return 0
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for Ollama API to be ready..."
            fi
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Attempt $attempt/$max_attempts: Container $container_name not ready yet"
        fi
        
        sleep 30
        ((attempt++))
    done
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Container $container_name failed to start after $max_attempts attempts"
    return 1
}

# Wait for Ollama container to be ready
if ! check_container "ollama" 20; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Ollama container not ready. Exiting."
    exit 1
fi

# Pull the model with retries
MAX_PULL_ATTEMPTS=3
pull_attempt=1

while [ $pull_attempt -le $MAX_PULL_ATTEMPTS ]; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting model pull attempt $pull_attempt: deepseek-r1:671b"
    
    if docker exec -i ollama ollama pull deepseek-r1:671b; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully pulled model: deepseek-r1:671b"
        break
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pull attempt $pull_attempt failed"
        if [ $pull_attempt -eq $MAX_PULL_ATTEMPTS ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to pull model after $MAX_PULL_ATTEMPTS attempts"
            exit 1
        fi
        sleep 60
        ((pull_attempt++))
    fi
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script completed successfully"
PULLSCRIPT

chmod +x /root/pull-model.sh

# Execute the model pull script in the background
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting model pull script in background"
nohup /root/pull-model.sh > /dev/null 2>&1 &

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deployment completed"
