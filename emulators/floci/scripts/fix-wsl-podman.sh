#!/bin/bash
set -e

echo "=========================================="
echo "WSL Podman Permanent Configuration"
echo "=========================================="
echo ""

# Enable lingering
echo "[1/3] Enabling Podman lingering for rootless operation..."
sudo loginctl enable-linger $(id -u)
echo "✓ Lingering enabled"
echo ""

# Verify systemd
echo "[2/3] Verifying systemd is running..."
if systemctl is-system-running > /dev/null 2>&1; then
  echo "✓ Systemd is running"
else
  echo "⚠ Systemd may not be fully running yet"
fi
echo ""

# Configure Podman registries
echo "[3/3] Configuring Podman registries..."
sudo mkdir -p /etc/containers
sudo tee /etc/containers/registries.conf > /dev/null << 'EOF'
unqualified-search-registries = ["docker.io"]

[[registry]]
prefix = "docker.io"
location = "docker.io"
EOF
echo "✓ Registries configured"
echo ""

echo "=========================================="
echo "All permanent fixes applied!"
echo "=========================================="
echo ""
echo "You can now run the pipeline:"
echo "  cd /mnt/c/Users/lreddy1/event-booking-floci-main/event-booking-floci-main"
echo "  bash scripts/full-pipeline.sh"
echo ""
