#!/bin/bash
set -euo pipefail
exec > /var/log/user-data.log 2>&1

export DEBIAN_FRONTEND=noninteractive
RDP_PASSWORD="${rdp_password}"
AWS_REGION="${aws_region}"

# ── System update ─────────────────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y

# ── Desktop environment (XFCE4 + XRDP) ───────────────────────────────────────
apt-get install -y \
  xfce4 \
  xfce4-goodies \
  xrdp \
  dbus-x11 \
  x11-xserver-utils \
  xorgxrdp

systemctl enable xrdp
systemctl start xrdp

# Allow ubuntu user to start a graphical session via xrdp
echo "startxfce4" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession

# Set the RDP password for ubuntu user
echo "ubuntu:$RDP_PASSWORD" | chpasswd

# Add xrdp user to ssl-cert group (required for TLS)
usermod -aG ssl-cert xrdp
systemctl restart xrdp

# ── Node.js 20 LTS (arm64) ────────────────────────────────────────────────────
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# ── Claude Code ───────────────────────────────────────────────────────────────
npm install -g @anthropic-ai/claude-code

# ── AWS CLI v2 (arm64) ────────────────────────────────────────────────────────
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o awscliv2.zip
apt-get install -y unzip
unzip -q awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# ── VS Code (arm64 .deb) ──────────────────────────────────────────────────────
curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64" \
  -o /tmp/vscode.deb
apt-get install -y /tmp/vscode.deb
rm /tmp/vscode.deb

# ── Useful dev tools ──────────────────────────────────────────────────────────
apt-get install -y \
  git \
  curl \
  wget \
  jq \
  vim \
  tmux \
  build-essential \
  python3-pip \
  ca-certificates \
  gnupg

# ── Configure AWS region default ──────────────────────────────────────────────
sudo -u ubuntu bash -c "
  mkdir -p /home/ubuntu/.aws
  cat > /home/ubuntu/.aws/config <<EOF
[default]
region = $AWS_REGION
output = json
EOF
"

# ── Desktop shortcut: VS Code ─────────────────────────────────────────────────
sudo -u ubuntu bash -c "
  mkdir -p /home/ubuntu/Desktop
  cat > /home/ubuntu/Desktop/vscode.desktop <<EOF
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
Exec=/usr/bin/code --no-sandbox %F
Icon=vscode
Type=Application
Categories=Development;
EOF
  chmod +x /home/ubuntu/Desktop/vscode.desktop
"

# ── Final restart of xrdp ─────────────────────────────────────────────────────
systemctl restart xrdp

echo "Bootstrap complete: $(date)"
