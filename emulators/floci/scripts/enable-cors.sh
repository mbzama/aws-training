#!/bin/bash

# Enable CORS on API Gateway for localhost:3000

set -e

FLOCI_ENDPOINT="http://localhost:4566"
REGION="us-east-1"

echo "=========================================="
echo "Enabling CORS on API Gateway"
echo "=========================================="
echo ""

# Set AWS credentials
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# Get API ID
API_ID=$(aws apigateway get-rest-apis \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$API_ID" ]; then
  echo "Error: Could not find API Gateway"
  exit 1
fi

echo "Found API ID: $API_ID"
echo ""

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  grep -o '"id": "[^"]*"' | head -1 | cut -d'"' -f4)

echo "Found Root Resource ID: $ROOT_ID"
echo ""

# Create OPTIONS method for CORS preflight
echo "Creating OPTIONS method for CORS..."

aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method OPTIONS \
  --authorization-type NONE \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || echo "OPTIONS method may already exist"

# Create mock integration for OPTIONS
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method OPTIONS \
  --type MOCK \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

# Add CORS headers to OPTIONS response
aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters 'method.response.header.Access-Control-Allow-Headers='"'"'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"'"',method.response.header.Access-Control-Allow-Methods='"'"'*'"'"',method.response.header.Access-Control-Allow-Origin='"'"'*'"'"'' \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $ROOT_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters 'method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true,method.response.header.Access-Control-Allow-Origin=true' \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

echo "✓ OPTIONS method configured"
echo ""

# Update GET method response to include CORS headers
echo "Adding CORS headers to existing methods..."

# Get all resources
RESOURCES=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null)

echo "$RESOURCES" | grep -o '"id": "[^"]*"' | cut -d'"' -f4 | while read RESOURCE_ID; do
  # Try to add CORS headers to GET method
  aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --status-code 200 \
    --response-parameters 'method.response.header.Access-Control-Allow-Origin='"'"'*'"'"'' \
    --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true

  # Add header to method response
  aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method GET \
    --status-code 200 \
    --response-parameters 'method.response.header.Access-Control-Allow-Origin=true' \
    --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true
done

echo "✓ CORS headers added to methods"
echo ""

# Redeploy API
echo "Redeploying API..."

DEPLOYMENT=$(aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null)

echo "✓ API redeployed"
echo ""

echo "=========================================="
echo "CORS Enabled!"
echo "=========================================="
echo ""
echo "You can now make requests from http://localhost:3000"
echo ""
echo "Refresh your browser and try booking again!"
echo ""
