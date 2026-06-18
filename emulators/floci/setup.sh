#!/bin/bash
set -e

echo "🚀 Starting Event Booking Platform Setup..."

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "📍 Working directory: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Step 1: Start Floci
echo "📦 Starting Floci..."
podman-compose up -d
echo "⏳ Waiting for Floci to be ready..."
sleep 10

# Step 2: Deploy infrastructure
echo "🏗️ Deploying infrastructure with Terraform..."
cd "$PROJECT_ROOT/terraform"
terraform init
terraform apply -auto-approve

# Step 3: Get Terraform outputs and update frontend .env
echo "📝 Updating frontend .env with Terraform outputs..."
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null || echo "us-east-1_XXXXXXXXX")
CLIENT_ID=$(terraform output -raw user_pool_client_id 2>/dev/null || echo "xxxxxxxxxxxxxxxxxxxxx")

echo "✅ Frontend .env updated:"
cat > "$PROJECT_ROOT/frontend/.env" << EOF
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_COGNITO_REGION=us-east-1
REACT_APP_COGNITO_USER_POOL_ID=$USER_POOL_ID
REACT_APP_COGNITO_CLIENT_ID=$CLIENT_ID
EOF

cat "$PROJECT_ROOT/frontend/.env"

# Step 4: Seed events
echo ""
echo "🌱 Seeding DynamoDB with events..."
cd "$PROJECT_ROOT"
python seed_events.py

echo ""
echo "✅ Setup complete! Now run these in separate terminals:"
echo ""
echo "Terminal 2 (from $PROJECT_ROOT):"
echo "  python app.py"
echo ""
echo "Terminal 3 (from $PROJECT_ROOT):"
echo "  python worker.py"
echo ""
echo "Terminal 4 (from $PROJECT_ROOT):"
echo "  cd frontend && npm install && npm start"
echo ""
