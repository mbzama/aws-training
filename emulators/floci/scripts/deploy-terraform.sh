#!/bin/bash

# Deploy Infrastructure with Terraform to Floci
# This script initializes and applies Terraform configuration to LocalStack

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

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

# Configuration
FLOCI_ENDPOINT="http://localhost:4566"
REGION="us-east-1"
ENVIRONMENT="prod"

# Main execution
log_header "TERRAFORM INFRASTRUCTURE DEPLOYMENT"

# Verify Floci is running
log_info "Verifying Floci is running..."
if ! curl -s "$FLOCI_ENDPOINT/_localstack/health" 2>/dev/null | grep -q '"cognito-idp"'; then
  log_error "Floci is not running or Cognito not ready. Start it with: bash scripts/setup-floci.sh"
fi
log_info "✓ Floci is running at $FLOCI_ENDPOINT"

# Set AWS credentials for Floci
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT

log_info "✓ AWS credentials configured for Floci"

# Navigate to terraform directory
cd "$TERRAFORM_DIR" || log_error "Failed to navigate to terraform directory"
log_info "Working directory: $(pwd)"

# Initialize Terraform
log_info "Initializing Terraform..."
terraform init -upgrade || log_error "Terraform init failed"
log_info "✓ Terraform initialized"

# Validate Terraform configuration
log_info "Validating Terraform configuration..."
terraform validate || log_error "Terraform validation failed"
log_info "✓ Terraform configuration is valid"

# Format check (non-blocking)
log_info "Checking Terraform formatting..."
terraform fmt -check -recursive || log_warning "⚠ Terraform formatting issues (non-critical)"

# Plan Terraform changes
log_info "Planning Terraform changes..."
terraform plan -var="aws_region=$REGION" -var="environment=$ENVIRONMENT" -out=tfplan || log_error "Terraform plan failed"
log_info "✓ Terraform plan generated"

# Apply Terraform changes
log_info "Applying Terraform changes..."
terraform apply -auto-approve tfplan || log_error "Terraform apply failed"
log_info "✓ Infrastructure deployed with Terraform"

# Extract and save outputs
log_info "Extracting Terraform outputs..."
ENV_FILE="$PROJECT_ROOT/.env.terraform"

# Get outputs in JSON format (remove null redirects to see errors)
OUTPUTS=$(terraform output -json)

# Use jq if available, otherwise use Python
if command -v jq &> /dev/null; then
  log_info "Using jq to parse Terraform outputs..."
  API_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.flask_endpoint.value // .api_endpoint.value // ""' 2>/dev/null)
  USER_POOL_ID=$(echo "$OUTPUTS" | jq -r '.user_pool_id.value // ""' 2>/dev/null)
  USER_POOL_CLIENT_ID=$(echo "$OUTPUTS" | jq -r '.user_pool_client_id.value // ""' 2>/dev/null)
  EVENTS_TABLE=$(echo "$OUTPUTS" | jq -r '.events_table_name.value // ""' 2>/dev/null)
  BOOKINGS_TABLE=$(echo "$OUTPUTS" | jq -r '.bookings_table_name.value // ""' 2>/dev/null)
  TICKETS_BUCKET=$(echo "$OUTPUTS" | jq -r '.tickets_bucket_name.value // ""' 2>/dev/null)
  FRONTEND_BUCKET=$(echo "$OUTPUTS" | jq -r '.frontend_bucket_name.value // ""' 2>/dev/null)
  BOOKING_QUEUE_URL=$(echo "$OUTPUTS" | jq -r '.booking_queue_url.value // ""' 2>/dev/null)
else
  log_warning "jq not found, using Python to parse outputs..."
  API_ENDPOINT=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('flask_endpoint', {}).get('value', d.get('api_endpoint', {}).get('value', '')))" 2>/dev/null)
  USER_POOL_ID=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('user_pool_id', {}).get('value', ''))" 2>/dev/null)
  USER_POOL_CLIENT_ID=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('user_pool_client_id', {}).get('value', ''))" 2>/dev/null)
  EVENTS_TABLE=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('events_table_name', {}).get('value', ''))" 2>/dev/null)
  BOOKINGS_TABLE=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('bookings_table_name', {}).get('value', ''))" 2>/dev/null)
  TICKETS_BUCKET=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('tickets_bucket_name', {}).get('value', ''))" 2>/dev/null)
  FRONTEND_BUCKET=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('frontend_bucket_name', {}).get('value', ''))" 2>/dev/null)
  BOOKING_QUEUE_URL=$(echo "$OUTPUTS" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('booking_queue_url', {}).get('value', ''))" 2>/dev/null)
fi

# Validate we got the critical values
if [ -z "$USER_POOL_ID" ] || [ -z "$USER_POOL_CLIENT_ID" ]; then
  log_error "Failed to extract Cognito outputs. Terraform apply may have failed. Check terraform output -json"
fi

# Save outputs to environment file
log_info "Saving outputs to $ENV_FILE..."
cat > "$ENV_FILE" << EOF
# Terraform Stack Outputs
# Auto-generated by deploy-terraform.sh on $(date)

export FLOCI_ENDPOINT=$FLOCI_ENDPOINT
export REGION=$REGION
export ENVIRONMENT=$ENVIRONMENT

export API_ENDPOINT=$API_ENDPOINT
export USER_POOL_ID=$USER_POOL_ID
export USER_POOL_CLIENT_ID=$USER_POOL_CLIENT_ID
export EVENTS_TABLE=$EVENTS_TABLE
export BOOKINGS_TABLE=$BOOKINGS_TABLE
export TICKETS_BUCKET=$TICKETS_BUCKET
export FRONTEND_BUCKET=$FRONTEND_BUCKET
export BOOKING_QUEUE_URL=$BOOKING_QUEUE_URL

# For Flask Backend (Cognito integration with Floci)
export COGNITO_USER_POOL_ID=$USER_POOL_ID
export COGNITO_CLIENT_ID=$USER_POOL_CLIENT_ID
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# For React Frontend
export REACT_APP_API_ENDPOINT=$API_ENDPOINT
export REACT_APP_DEBUG=false
EOF

log_info "✓ Outputs saved to .env.terraform"

# Display outputs
log_header "TERRAFORM OUTPUTS"

echo "API Endpoint:           $API_ENDPOINT"
echo "User Pool ID:           $USER_POOL_ID"
echo "User Pool Client ID:    $USER_POOL_CLIENT_ID"
echo "Events Table:           $EVENTS_TABLE"
echo "Bookings Table:         $BOOKINGS_TABLE"
echo "Tickets S3 Bucket:      $TICKETS_BUCKET"
echo "Frontend S3 Bucket:     $FRONTEND_BUCKET"
echo "Booking Queue URL:      $BOOKING_QUEUE_URL"
echo ""

# List all resources
log_info "Listing Terraform resources..."
terraform state list

# Next steps
log_header "DEPLOYMENT COMPLETE"

echo "Terraform infrastructure deployed successfully!"
echo ""
echo "Environment outputs saved to: $ENV_FILE"
echo "Load them with: source $ENV_FILE"
echo ""
echo "Backend Configuration (Cognito + Floci):"
echo "  - User Pool ID:  $USER_POOL_ID"
echo "  - Client ID:     $USER_POOL_CLIENT_ID"
echo "  - Region:        $REGION"
echo "  - Endpoint:      $FLOCI_ENDPOINT"
echo ""
echo "Next steps:"
echo "  1. Load env vars:          source $ENV_FILE"
echo "  2. Start Flask backend:    python app.py"
echo "  3. In another terminal:"
echo "  4. Start frontend:         cd frontend && npm start"
echo ""
echo "Demo user available:"
echo "  Email:    demo@example.com"
echo "  Password: Demo@123456"
echo ""
echo "To view Floci logs:"
echo "  podman-compose logs -f floci"
echo ""
echo "To clean up:"
echo "  bash scripts/cleanup.sh"
echo ""

log_info "Terraform deployment complete!"
