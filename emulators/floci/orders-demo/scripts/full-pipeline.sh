#!/bin/bash
set -e

# Full Pipeline - Complete end-to-end deployment
# This script runs all stages to get from zero to running application

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

log_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

log_stage() {
  echo ""
  echo -e "${BLUE}──────────────────────────────────────${NC}"
  echo -e "${BLUE}Stage: $1${NC}"
  echo -e "${BLUE}──────────────────────────────────────${NC}"
  echo ""
}

# Main execution
log_header "FLOCI FULL PIPELINE"

echo "This script will run all stages to set up your application:"
echo "  1. Setup Floci"
echo "  2. Deploy Infrastructure"
echo "  3. Seed Data"
echo "  4. Build Frontend"
echo "  5. Deploy Frontend"
echo "  6. Start Development Server"
echo ""
echo "Estimated time: 3-5 minutes"
echo ""

# Stage 1: Setup Floci
log_stage "1. Setup Floci"
if bash "$SCRIPT_DIR/setup-floci.sh"; then
  log_info "✓ Floci setup complete"
else
  log_error "Floci setup failed"
fi

# Stage 2: Deploy Infrastructure
log_stage "2. Deploy Infrastructure"
if bash "$SCRIPT_DIR/deploy-infrastructure.sh"; then
  log_info "✓ Infrastructure deployed"
else
  log_error "Infrastructure deployment failed"
fi

# Source outputs for later stages
if [ -f "$PROJECT_ROOT/.env.floci" ]; then
  source "$PROJECT_ROOT/.env.floci"
fi

# Stage 3: Seed Data
log_stage "3. Seed Data"
if bash "$SCRIPT_DIR/seed-data.sh"; then
  log_info "✓ Data seeded"
else
  log_error "Data seeding failed"
fi

# Stage 4: Build Frontend
log_stage "4. Build Frontend"
if bash "$SCRIPT_DIR/build-frontend.sh"; then
  log_info "✓ Frontend built"
else
  log_error "Frontend build failed"
fi

# Stage 5: Deploy Frontend
log_stage "5. Deploy Frontend"
if bash "$SCRIPT_DIR/deploy-frontend.sh"; then
  log_info "✓ Frontend deployed"
else
  log_error "Frontend deployment failed"
fi

# Summary
log_header "PIPELINE COMPLETE"

echo "All stages completed successfully!"
echo ""
echo "Your application is ready to use."
echo ""
echo "Access Information:"
echo "  URL:      http://localhost:3000"
echo "  Email:    demo@example.com"
echo "  Password: Demo@123456"
echo ""
echo "What's running:"
echo "  ✓ Floci (LocalStack) on port 4566"
echo "  ✓ Cognito User Pool"
echo "  ✓ API Gateway"
echo "  ✓ 4 Lambda functions"
echo "  ✓ DynamoDB (Bookings & Events tables)"
echo "  ✓ S3 (Frontend & Tickets)"
echo "  ✓ SQS/SNS (Async messaging)"
echo ""
echo "Next step:"
echo "  bash $SCRIPT_DIR/start-frontend.sh"
echo ""
echo "Or in another terminal:"
echo "  cd $PROJECT_ROOT/frontend"
echo "  npm start"
echo ""
echo "To view Floci logs:"
echo "  cd $PROJECT_ROOT"
echo "  podman-compose logs -f floci"
echo ""
echo "To run tests:"
echo "  bash $SCRIPT_DIR/test-apis.sh"
echo ""
echo "To cleanup:"
echo "  bash $SCRIPT_DIR/cleanup.sh"
echo ""

log_info "Full pipeline complete! Ready to start frontend development server."
