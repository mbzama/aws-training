#!/bin/bash
set -e

# Sync Terraform Outputs to Frontend Environment
# Extracts outputs from Terraform and updates frontend/.env

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if terraform.tfstate exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
  log_error "Terraform state file not found. Run deploy-terraform.sh first."
fi

log_header "SYNCING TERRAFORM OUTPUTS TO FRONTEND"

cd "$TERRAFORM_DIR"

# Get outputs in JSON format
OUTPUTS=$(terraform output -json 2>/dev/null || echo "{}")

# Extract outputs using jq (more reliable than grep)
if command -v jq &> /dev/null; then
  USER_POOL_ID=$(echo "$OUTPUTS" | jq -r '.user_pool_id.value // empty' 2>/dev/null || echo "")
  USER_POOL_CLIENT_ID=$(echo "$OUTPUTS" | jq -r '.user_pool_client_id.value // empty' 2>/dev/null || echo "")
  API_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.flask_endpoint.value // empty' 2>/dev/null || echo "")
  REGION="us-east-1"
else
  # Fallback to grep parsing if jq not available
  log_info "jq not found, using grep to parse outputs..."
  USER_POOL_ID=$(echo "$OUTPUTS" | grep -o '"user_pool_id"[^}]*"value"[^}]*"[^"]*"' | tail -1 | grep -o '[a-z0-9_]*_[a-z0-9]*' | head -1)
  USER_POOL_CLIENT_ID=$(echo "$OUTPUTS" | grep -o '"user_pool_client_id"[^}]*"value"[^}]*"[^"]*"' | tail -1 | grep -o '[a-z0-9]*' | tail -1)
  API_ENDPOINT=$(echo "$OUTPUTS" | grep -o '"flask_endpoint"[^}]*"value"[^}]*"[^"]*"' | tail -1 | sed 's/.*://; s/"//g' | xargs)
  REGION="us-east-1"
fi

# Validate we got values
if [ -z "$USER_POOL_ID" ] || [ -z "$USER_POOL_CLIENT_ID" ]; then
  log_error "Failed to extract Cognito outputs from Terraform. Make sure terraform apply was successful."
fi

log_info "Extracted outputs:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $USER_POOL_CLIENT_ID"
echo "  API Endpoint: $API_ENDPOINT"
echo "  Region: $REGION"

# Create frontend .env file
log_info "Updating $FRONTEND_DIR/.env..."

cat > "$FRONTEND_DIR/.env" << EOF
# Auto-generated from Terraform outputs
# Last updated: $(date)

REACT_APP_COGNITO_USER_POOL_ID=$USER_POOL_ID
REACT_APP_COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID
REACT_APP_COGNITO_REGION=$REGION
REACT_APP_API_ENDPOINT=$API_ENDPOINT
REACT_APP_DEBUG=false
EOF

log_info "✓ Frontend .env updated"

log_header "SYNC COMPLETE"

echo "Frontend environment configured with Terraform outputs."
echo ""
echo "You can now:"
echo "  1. Start frontend dev server: bash scripts/start-frontend.sh"
echo "  2. Or rebuild frontend: bash scripts/build-frontend.sh"
echo ""
