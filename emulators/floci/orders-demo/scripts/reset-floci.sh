#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Resetting Floci Setup"
echo "=========================================="
echo ""

cd "$PROJECT_ROOT"

# Stop and remove containers
echo "[1/4] Stopping and removing old containers..."
podman-compose down 2>/dev/null || true
podman rm -f floci-event-booking 2>/dev/null || true
podman rmi docker.io/floci/floci:latest 2>/dev/null || true
echo "✓ Old containers removed"
echo ""

# Clean up networks
echo "[2/4] Cleaning up networks..."
podman network prune -f 2>/dev/null || true
echo "✓ Networks cleaned"
echo ""

# Clean up Podman system
echo "[3/4] Cleaning Podman system..."
podman system reset -f 2>/dev/null || true
echo "✓ System reset"
echo ""

# Restart podman service
echo "[4/4] Restarting Podman service..."
systemctl --user restart podman.service 2>/dev/null || true
sleep 2
echo "✓ Podman service restarted"
echo ""

echo "=========================================="
echo "Reset complete! Now run:"
echo "  bash scripts/full-pipeline.sh"
echo "=========================================="
