#!/bin/bash
set -e

# Deploy Frontend - Upload built frontend to S3
# This script uploads the React build to Floci S3 bucket

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

# Configuration
FLOCI_ENDPOINT="http://localhost:4566"
STACK_NAME="event-booking-platform"
REGION="us-east-1"

# Source environment if available
if [ -f "$PROJECT_ROOT/.env.floci" ]; then
  source "$PROJECT_ROOT/.env.floci"
fi

# Main execution
log_header "FRONTEND DEPLOYMENT"

# Set AWS credentials
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# Get frontend bucket if not already set
if [ -z "$FRONTEND_BUCKET" ]; then
  log_info "Retrieving frontend bucket name..."
  OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --endpoint-url "$FLOCI_ENDPOINT" \
    --query "Stacks[0].Outputs" 2>/dev/null || echo "[]")

  FRONTEND_BUCKET=$(echo "$OUTPUTS" | grep -o '"OutputKey":"FrontendBucketName".*"OutputValue":"[^"]*"' | grep -o '"OutputValue":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$FRONTEND_BUCKET" ]; then
  log_error "Could not retrieve frontend bucket name. Make sure infrastructure is deployed."
fi

log_info "Frontend bucket: $FRONTEND_BUCKET"

# Navigate to frontend directory
cd "$PROJECT_ROOT/frontend"

# Verify build exists
if [ ! -d "build" ]; then
  log_error "Build directory not found. Run: bash scripts/build-frontend.sh"
fi

log_info "Uploading build files to S3..."

# Upload to S3
aws s3 sync build/ "s3://$FRONTEND_BUCKET/" \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --delete \
  --acl public-read || log_error "S3 upload failed"

log_info "✓ Files uploaded to S3"

# Set cache control headers for index.html
log_info "Configuring cache headers..."
aws s3 cp "s3://$FRONTEND_BUCKET/index.html" "s3://$FRONTEND_BUCKET/index.html" \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --metadata-directive REPLACE \
  --cache-control "no-cache" \
  --content-type "text/html" || log_warning "Could not set cache headers"

log_info "✓ Cache headers configured"

# List uploaded files
log_info "Verifying uploaded files..."
FILE_COUNT=$(aws s3 ls "s3://$FRONTEND_BUCKET/" \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --recursive | wc -l)

log_info "✓ Uploaded $FILE_COUNT files to S3"

# Show S3 bucket contents
log_info "S3 bucket contents:"
aws s3 ls "s3://$FRONTEND_BUCKET/" \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --recursive | head -20

# Summary
log_header "FRONTEND DEPLOYMENT COMPLETE"

echo "Frontend deployed to S3!"
echo ""
echo "Bucket:  s3://$FRONTEND_BUCKET"
echo "Files:   $FILE_COUNT"
echo "Access:  http://localhost:3000 (via dev server)"
echo ""
echo "Next steps:"
echo "  1. Start development server: bash scripts/start-frontend.sh"
echo "  2. Open browser: http://localhost:3000"
echo "  3. Login with: demo@example.com / Demo@123456"
echo ""

log_info "Frontend deployment complete!"
