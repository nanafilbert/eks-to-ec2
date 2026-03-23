#!/bin/bash
# Run once on a fresh Ubuntu 24.04 EC2 instance
set -euo pipefail

log() { echo "[provision] $*"; }

log "Updating packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y -qq \
  curl wget git unzip htop vim \
  ufw fail2ban ca-certificates gnupg \
  jq wireguard-tools

# AWS CLI v2 — not in Ubuntu 24.04 apt repo
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o /tmp/awscliv2.zip -d /tmp/
sudo /tmp/aws/install --update || true # --update flag is idempotent, but doesn't work on first install for some reason
rm -rf /tmp/awscliv2.zip /tmp/aws

# ── Swap ──────────────────────────────────────────────────────────────
# Prevents OOM crashes on smaller instances
if [ ! -f /swapfile ]; then
  log "Creating 4GB swap..."
  sudo fallocate -l 4G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
fi

# ── Docker ────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  log "Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io docker-compose-plugin
  sudo usermod -aG docker "${USER}"
  sudo systemctl enable docker
  sudo systemctl start docker
fi

# ── Firewall ──────────────────────────────────────────────────────────
log "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   comment 'SSH'
sudo ufw allow 80/tcp   comment 'HTTP (ALB only — locked down via security group)'
sudo ufw allow 51820/udp comment 'WireGuard'
sudo ufw --force enable

# ── Docker log rotation ───────────────────────────────────────────────
sudo mkdir -p /etc/docker
cat <<'DAEMON' | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "50m", "max-file": "5" }
}
DAEMON
sudo systemctl restart docker

# ── SSM Agent ─────────────────────────────────────────────────────────
log "Configuring SSM agent..."
sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# ── fail2ban ──────────────────────────────────────────────────────────
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

log "Done. Log out and back in for Docker group to take effect."
