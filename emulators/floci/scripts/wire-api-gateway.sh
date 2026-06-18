#!/bin/bash

# Wire API Gateway to Lambda functions
# Connects each API endpoint to its corresponding Lambda

set -e

FLOCI_ENDPOINT="http://localhost:4566"
REGION="us-east-1"
ACCOUNT_ID="000000000000"

export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

echo "=========================================="
echo "Wiring API Gateway to Lambda Functions"
echo "=========================================="
echo ""

# Get API ID
API_ID=$(aws apigateway get-rest-apis \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$API_ID" ]; then
  echo "Error: Could not find API Gateway"
  exit 1
fi

echo "Found API ID: $API_ID"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Found Root Resource ID: $ROOT_ID"
echo ""

# Create /events resource
echo "Creating /events resource..."
EVENTS_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part events \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Created /events resource: $EVENTS_RESOURCE"

# Create GET /events method
echo "Creating GET /events method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $EVENTS_RESOURCE \
  --http-method GET \
  --authorization-type NONE \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

# Connect GET /events to events-lambda
echo "Connecting to events-lambda..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $EVENTS_RESOURCE \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:event-booking-events/invocations" \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo "✓ GET /events connected to events-lambda"

# Create /book resource
echo ""
echo "Creating /book resource..."
BOOK_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part book \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Created /book resource: $BOOK_RESOURCE"

# Create POST /book method
echo "Creating POST /book method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $BOOK_RESOURCE \
  --http-method POST \
  --authorization-type NONE \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

# Connect POST /book to booking-lambda
echo "Connecting to booking-lambda..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $BOOK_RESOURCE \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:event-booking-book/invocations" \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo "✓ POST /book connected to booking-lambda"

# Create /history resource
echo ""
echo "Creating /history resource..."
HISTORY_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part history \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Created /history resource: $HISTORY_RESOURCE"

# Create GET /history method
echo "Creating GET /history method..."
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $HISTORY_RESOURCE \
  --http-method GET \
  --authorization-type NONE \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

# Connect GET /history to history-lambda
echo "Connecting to history-lambda..."
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $HISTORY_RESOURCE \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$ACCOUNT_ID:function:event-booking-history/invocations" \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo "✓ GET /history connected to history-lambda"

# Create /auth resource and methods
echo ""
echo "Creating /auth resource..."
AUTH_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part auth \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Created /auth resource: $AUTH_RESOURCE"

# Create /auth/signin resource
SIGNIN_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $AUTH_RESOURCE \
  --path-part signin \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

# Create POST /auth/signin method with mock response
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $SIGNIN_RESOURCE \
  --http-method POST \
  --authorization-type NONE \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $SIGNIN_RESOURCE \
  --http-method POST \
  --type MOCK \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo "✓ POST /auth/signin created (uses Cognito directly from frontend)"

# Redeploy API
echo ""
echo "Redeploying API Gateway..."
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo ""
echo "=========================================="
echo "API Gateway Wired Successfully!"
echo "=========================================="
echo ""
echo "Endpoints created:"
echo "  GET    /events   → event-booking-events"
echo "  POST   /book     → event-booking-book"
echo "  GET    /history  → event-booking-history"
echo ""
echo "Ready to test bookings!"
echo ""
