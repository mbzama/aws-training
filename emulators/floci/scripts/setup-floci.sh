#!/bin/bash
set -e

# Setup Floci - Start and verify AWS emulator
# This script starts the Floci (LocalStack) container and waits for it to be ready

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

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Main execution
log_header "FLOCI SETUP"

# Check Podman is installed
log_info "Checking Podman installation..."
if ! command -v podman &> /dev/null; then
  log_error "Podman is not installed. Please install Podman first."
  log_error "See PODMAN_SETUP.md for installation instructions."
fi
log_info "✓ Podman found: $(podman --version)"

# Check podman-compose or podman compose
log_info "Checking Podman Compose..."
if command -v podman-compose &> /dev/null; then
  COMPOSE_CMD="podman-compose"
  log_info "✓ Found podman-compose"
elif podman compose --help &> /dev/null; then
  COMPOSE_CMD="podman compose"
  log_info "✓ Found podman compose (built-in)"
else
  log_warning "podman-compose not found. Install with: pip install podman-compose"
  log_warning "Or use newer Podman with built-in compose support"
  exit 1
fi

# Navigate to project root
cd "$PROJECT_ROOT"

# Check if container already running
log_info "Checking if Floci is already running..."
if $COMPOSE_CMD ps 2>/dev/null | grep -q floci-event-booking; then
  log_warning "Floci container already running. Skipping start..."
else
  log_info "Floci not found. Starting container..."
  $COMPOSE_CMD up -d
fi

# Start Floci
log_info "Starting Floci container..."
$COMPOSE_CMD up -d

# Wait for container to be healthy
log_info "Waiting for Floci to be ready (this may take 30-60 seconds)..."
FLOCI_ENDPOINT="http://localhost:4566"
MAX_ATTEMPTS=120
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if curl -s "$FLOCI_ENDPOINT/_localstack/health" 2>/dev/null | grep -q -E '"state"|running|ready|services'; then
    log_info "✓ Floci is running"
    sleep 10  # Extra buffer to ensure services are fully ready
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  if [ $((ATTEMPT % 10)) -eq 0 ]; then
    echo -n "."
  fi
  sleep 1
done

if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
  log_warning "Floci startup timeout, but continuing anyway..."
fi

# Verify all services
log_info "Verifying AWS services..."
HEALTH=$(curl -s "$FLOCI_ENDPOINT/_localstack/health" 2>/dev/null)

echo "Services status:"
echo "$HEALTH" | grep -oP '"dynamodb":|"lambda":|"sqs":|"sns":|"s3":|"apigateway":|"cognito-idp":' | while read -r service; do
  SERVICE_NAME=$(echo "$service" | sed 's/"//g' | sed 's/://g')
  echo "  ✓ $SERVICE_NAME"
done

# Set environment variables for Floci
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

log_info "✓ Environment variables configured"

# Show connection details
log_header "FLOCI READY"

echo "Floci endpoint: $FLOCI_ENDPOINT"
echo "Data directory: $PROJECT_ROOT/floci-data/"
echo ""
echo "Environment variables set:"
echo "  AWS_ENDPOINT_URL=$FLOCI_ENDPOINT"
echo "  AWS_ACCESS_KEY_ID=test"
echo "  AWS_SECRET_ACCESS_KEY=test"
echo "  AWS_DEFAULT_REGION=us-east-1"
echo ""
echo "Next steps:"
echo "  1. Deploy infrastructure: bash scripts/deploy-infrastructure.sh"
echo "  2. Or run full pipeline: bash scripts/full-pipeline.sh"
echo ""
echo "View logs:"
echo "  $COMPOSE_CMD logs -f floci"
echo ""

log_info "Setup complete!"
