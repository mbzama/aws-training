#!/bin/bash
set -e

# Cleanup - Stop Floci and optionally remove data
# This script stops the Floci container and cleans up resources

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Check if running via interactive shell or script
INTERACTIVE=true
if [ ! -t 0 ]; then
  INTERACTIVE=false
fi

# Main execution
log_header "CLEANUP"

# Navigate to project root
cd "$PROJECT_ROOT"

# Check podman-compose availability
if command -v podman-compose &> /dev/null; then
  COMPOSE_CMD="podman-compose"
elif podman compose --help &> /dev/null; then
  COMPOSE_CMD="podman compose"
else
  log_info "podman-compose not found. Trying manual cleanup..."
  podman stop floci-event-booking 2>/dev/null || true
  podman rm floci-event-booking 2>/dev/null || true
  exit 0
fi

log_info "Compose command: $COMPOSE_CMD"

# Check if container is running
if $COMPOSE_CMD ps | grep -q floci-event-booking; then
  log_info "Stopping Floci container..."
  $COMPOSE_CMD down || log_info "Container already stopped"
  log_info "✓ Container stopped"
else
  log_info "Container is not running"
fi

# Ask about data cleanup
REMOVE_DATA=false
if [ "$INTERACTIVE" = true ]; then
  echo ""
  echo "Floci data is stored in: $PROJECT_ROOT/floci-data/"
  echo ""
  read -p "Remove persistent data? (y/n, default: no) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    REMOVE_DATA=true
  fi
else
  log_info "Running non-interactively, keeping data..."
fi

if [ "$REMOVE_DATA" = true ]; then
  log_info "Removing persistent data..."
  rm -rf "$PROJECT_ROOT/floci-data"
  log_info "✓ Data removed"
else
  DATA_SIZE=$(du -sh "$PROJECT_ROOT/floci-data" 2>/dev/null | cut -f1)
  log_info "Keeping persistent data ($DATA_SIZE)"
fi

# Clean up environment file
if [ -f "$PROJECT_ROOT/.env.floci" ]; then
  log_info "Removing environment file..."
  rm "$PROJECT_ROOT/.env.floci"
  log_info "✓ .env.floci removed"
fi

# Summary
log_header "CLEANUP COMPLETE"

echo "Floci resources cleaned up!"
echo ""
echo "Status:"
echo "  ✓ Floci container stopped"
if [ "$REMOVE_DATA" = true ]; then
  echo "  ✓ Persistent data removed"
else
  echo "  ✓ Persistent data kept (can be used for next session)"
fi
echo ""

echo "To start again:"
echo "  bash scripts/setup-floci.sh"
echo "  bash scripts/full-pipeline.sh"
echo ""

log_info "Cleanup complete!"
