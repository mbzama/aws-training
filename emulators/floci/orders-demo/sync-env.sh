#!/bin/bash
# Sync Terraform outputs to .env files

cd terraform

# Get Terraform outputs
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null || echo "")
CLIENT_ID=$(terraform output -raw user_pool_client_id 2>/dev/null || echo "")
SNS_TOPIC_ARN=$(terraform output -raw booking_topic_arn 2>/dev/null || echo "")

if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
  echo "⚠️  Warning: Could not get Cognito values from Terraform"
  exit 0
fi

cd ..

# Create .env for backend
cat > .env << EOF
COGNITO_USER_POOL_ID=$USER_POOL_ID
COGNITO_CLIENT_ID=$CLIENT_ID
SNS_TOPIC_ARN=$SNS_TOPIC_ARN
EOF

echo "✓ Backend .env created"

# Create .env for frontend
cat > frontend/.env << EOF
REACT_APP_COGNITO_USER_POOL_ID=$USER_POOL_ID
REACT_APP_COGNITO_CLIENT_ID=$CLIENT_ID
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_COGNITO_REGION=us-east-1
REACT_APP_DEBUG=false
EOF

echo "✓ Frontend .env created"
echo ""
echo "Configuration:"
echo "  User Pool ID: $USER_POOL_ID"
echo "  Client ID: $CLIENT_ID"
