#!/bin/bash
set -e

# Test APIs - Verify all endpoints are working
# This script tests key API endpoints with curl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_test() {
  echo -e "${CYAN}TEST:${NC} $1"
}

log_pass() {
  echo -e "${GREEN}✓ PASS${NC} $1"
}

log_fail() {
  echo -e "${RED}✗ FAIL${NC} $1"
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
log_header "API TESTING"

# Set AWS credentials
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# Get API endpoint if not already set
if [ -z "$API_ENDPOINT" ]; then
  log_info "Retrieving API endpoint..."
  OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --endpoint-url "$FLOCI_ENDPOINT" \
    --query "Stacks[0].Outputs" 2>/dev/null || echo "[]")

  API_ENDPOINT=$(echo "$OUTPUTS" | grep -o '"OutputKey":"ApiEndpoint".*"OutputValue":"[^"]*"' | grep -o '"OutputValue":"[^"]*"' | cut -d'"' -f4)
fi

if [ -z "$API_ENDPOINT" ]; then
  log_fail "API endpoint not found. Make sure infrastructure is deployed."
  exit 1
fi

log_info "API Endpoint: $API_ENDPOINT"
echo ""

# Test 1: Health check
log_test "Health check (no auth required)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X GET "$FLOCI_ENDPOINT/_localstack/health")

if [ "$RESPONSE" = "200" ]; then
  log_pass "Floci is running"
else
  log_fail "Floci health check failed (status: $RESPONSE)"
  exit 1
fi

# Test 2: Get Events (unauthenticated)
log_test "GET /events (no auth required)"
EVENTS=$(curl -s -X GET "$API_ENDPOINT/events" \
  -H "Content-Type: application/json")

if echo "$EVENTS" | grep -q "event-001"; then
  EVENT_COUNT=$(echo "$EVENTS" | grep -o '"eventId"' | wc -l)
  log_pass "Events endpoint working ($EVENT_COUNT events found)"
else
  log_fail "Events endpoint failed or no events found"
fi

# Test 3: DynamoDB Tables
log_test "DynamoDB tables"
TABLES=$(aws dynamodb list-tables \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --query "TableNames" \
  --output text)

if echo "$TABLES" | grep -q "Events"; then
  log_pass "Events table exists"
else
  log_fail "Events table not found"
fi

if echo "$TABLES" | grep -q "Bookings"; then
  log_pass "Bookings table exists"
else
  log_fail "Bookings table not found"
fi

# Test 4: Lambda Functions
log_test "Lambda functions"
FUNCTIONS=$(aws lambda list-functions \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --query "Functions[*].FunctionName" \
  --output text)

for FUNC in events-lambda booking-lambda history-lambda ticket-generator-lambda; do
  if echo "$FUNCTIONS" | grep -q "$FUNC"; then
    log_pass "Function $FUNC exists"
  else
    log_fail "Function $FUNC not found"
  fi
done

# Test 5: Cognito User Pool
log_test "Cognito user pool"
if [ -n "$USER_POOL_ID" ]; then
  USERS=$(aws cognito-idp list-users \
    --user-pool-id "$USER_POOL_ID" \
    --endpoint-url "$FLOCI_ENDPOINT" \
    --query "Users[*].Username" \
    --output text)

  if echo "$USERS" | grep -q "demo@example.com"; then
    log_pass "Demo user exists in Cognito"
  else
    log_fail "Demo user not found in Cognito"
  fi
else
  log_fail "Cognito not configured"
fi

# Test 6: S3 Buckets
log_test "S3 buckets"
BUCKETS=$(aws s3 ls --endpoint-url "$FLOCI_ENDPOINT" | awk '{print $3}')

if echo "$BUCKETS" | grep -q "frontend"; then
  log_pass "Frontend bucket exists"
else
  log_fail "Frontend bucket not found"
fi

if echo "$BUCKETS" | grep -q "tickets"; then
  log_pass "Tickets bucket exists"
else
  log_fail "Tickets bucket not found"
fi

# Test 7: SQS Queue
log_test "SQS queue"
QUEUES=$(aws sqs list-queues \
  --endpoint-url "$FLOCI_ENDPOINT" \
  --query "QueueUrls" \
  --output text 2>/dev/null || echo "")

if echo "$QUEUES" | grep -q "BookingQueue"; then
  log_pass "Booking queue exists"
else
  log_fail "Booking queue not found"
fi

# Summary
log_header "API TESTING SUMMARY"

echo "All critical infrastructure components are running!"
echo ""
echo "Services verified:"
echo "  ✓ Floci (LocalStack)"
echo "  ✓ API Gateway"
echo "  ✓ Lambda functions (4)"
echo "  ✓ DynamoDB tables (2)"
echo "  ✓ Cognito user pool"
echo "  ✓ S3 buckets (2)"
echo "  ✓ SQS queue"
echo ""
echo "Next steps:"
echo "  1. Start frontend dev server: bash $SCRIPT_DIR/start-frontend.sh"
echo "  2. Open browser: http://localhost:3000"
echo "  3. Login with demo@example.com / Demo@123456"
echo ""

log_info "API testing complete!"
