#!/bin/bash
set -e

# Seed Data - Initialize DynamoDB and Cognito with test data
# This script seeds the database with sample events and creates demo user

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
log_header "DATA SEEDING"

# Set AWS credentials
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# Get stack outputs if not already set
if [ -z "$USER_POOL_ID" ]; then
  log_info "Retrieving stack outputs..."
  OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --endpoint-url "$FLOCI_ENDPOINT" \
    --query "Stacks[0].Outputs" 2>/dev/null || echo "[]")

  USER_POOL_ID=$(echo "$OUTPUTS" | grep -o '"OutputKey":"UserPoolId".*"OutputValue":"[^"]*"' | grep -o '"OutputValue":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$USER_POOL_ID" ]; then
  log_error "Could not retrieve User Pool ID. Make sure infrastructure is deployed."
fi

log_info "User Pool ID: $USER_POOL_ID"

# Seed Events table
log_info "Seeding DynamoDB Events table with sample events..."

EVENTS=(
  '{
    "eventId": {"S": "event-001"},
    "name": {"S": "Summer Music Festival 2026"},
    "description": {"S": "Three-day electronic music festival featuring top international DJs"},
    "category": {"S": "Music"},
    "date": {"S": "2026-07-15"},
    "location": {"S": "Central Park, New York"},
    "capacity": {"N": "5000"},
    "ticketPrice": {"N": "99.99"}
  }'
  '{
    "eventId": {"S": "event-002"},
    "name": {"S": "Tech Conference 2026"},
    "description": {"S": "Annual technology conference with keynote speakers"},
    "category": {"S": "Technology"},
    "date": {"S": "2026-09-20"},
    "location": {"S": "San Francisco Convention Center"},
    "capacity": {"N": "3000"},
    "ticketPrice": {"N": "299.99"}
  }'
  '{
    "eventId": {"S": "event-003"},
    "name": {"S": "Food Carnival 2026"},
    "description": {"S": "Street food festival with cuisines from around the world"},
    "category": {"S": "Food"},
    "date": {"S": "2026-08-10"},
    "location": {"S": "Golden Gate Park, San Francisco"},
    "capacity": {"N": "2000"},
    "ticketPrice": {"N": "49.99"}
  }'
  '{
    "eventId": {"S": "event-004"},
    "name": {"S": "Basketball Championship 2026"},
    "description": {"S": "Championship playoff game featuring top basketball teams"},
    "category": {"S": "Sports"},
    "date": {"S": "2026-06-15"},
    "location": {"S": "Madison Square Garden, New York"},
    "capacity": {"N": "20000"},
    "ticketPrice": {"N": "150.00"}
  }'
)

for i in "${!EVENTS[@]}"; do
  EVENT_NUM=$((i + 1))
  echo "  Seeding event $EVENT_NUM..."

  aws dynamodb put-item \
    --table-name Events \
    --item "${EVENTS[$i]}" \
    --endpoint-url "$FLOCI_ENDPOINT" 2>/dev/null || \
    log_error "Failed to seed event $EVENT_NUM"
done

log_info "✓ 4 events seeded successfully"

# Verify events were created
log_info "Verifying events..."
COUNT=$(aws dynamodb scan \
  --table-name Events \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --select "COUNT" \
  --query "Count" \
  --output text)

log_info "✓ Events table contains $COUNT events"

# Create Cognito user
log_info "Creating demo Cognito user..."

DEMO_EMAIL="demo@example.com"
DEMO_PASSWORD="Demo@123456"
TEMP_PASSWORD="TempPassword123!"

# Create user
aws cognito-idp admin-create-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$DEMO_EMAIL" \
  --temporary-password "$TEMP_PASSWORD" \
  --endpoint-url "$FLOCI_ENDPOINT" 2>/dev/null || \
  log_error "Failed to create Cognito user"

log_info "✓ User created with temporary password"

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id "$USER_POOL_ID" \
  --username "$DEMO_EMAIL" \
  --password "$DEMO_PASSWORD" \
  --permanent \
  --endpoint-url "$FLOCI_ENDPOINT" 2>/dev/null || \
  log_error "Failed to set permanent password"

log_info "✓ Permanent password set"

# Verify user was created
log_info "Verifying user..."
aws cognito-idp admin-get-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$DEMO_EMAIL" \
  --endpoint-url "$FLOCI_ENDPOINT" > /dev/null 2>&1 || \
  log_error "Failed to verify user"

log_info "✓ User verified"

# Summary
log_header "DATA SEEDING COMPLETE"

echo "Sample data created:"
echo ""
echo "Events:"
echo "  ✓ Summer Music Festival 2026 (event-001) - \$99.99"
echo "  ✓ Tech Conference 2026 (event-002) - \$299.99"
echo "  ✓ Food Carnival 2026 (event-003) - \$49.99"
echo "  ✓ Basketball Championship 2026 (event-004) - \$150.00"
echo ""
echo "Demo User:"
echo "  Email:    $DEMO_EMAIL"
echo "  Password: $DEMO_PASSWORD"
echo ""
echo "Next steps:"
echo "  1. Build frontend:  bash scripts/build-frontend.sh"
echo "  2. Deploy frontend: bash scripts/deploy-frontend.sh"
echo "  3. Start frontend:  bash scripts/start-frontend.sh"
echo ""
echo "Or continue with full pipeline:"
echo "  bash scripts/full-pipeline.sh"
echo ""

log_info "Data seeding complete!"
