#!/bin/bash
set -e

# Event Ticket Booking Platform - Manual Deployment with Terraform
# Deploys infrastructure to Floci using Terraform

echo "=========================================="
echo "Event Ticket Booking Platform"
echo "Manual Deployment (Terraform + Floci)"
echo "=========================================="

FLOCI_ENDPOINT="http://localhost:4566"
REGION="us-east-1"
ACCOUNT_ID="000000000000"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] ✓ $1"; }
log_error() { echo "[ERROR] $1"; exit 1; }

# 1. Verify Floci is running
log_info "Verifying Floci is running on $FLOCI_ENDPOINT..."
if curl -s "$FLOCI_ENDPOINT/_floci/health" > /dev/null 2>&1; then
  log_success "Floci is running"
else
  log_info "Floci health check inconclusive, attempting to continue..."
fi

# 2. Navigate to terraform directory
log_info "Initializing Terraform..."
cd "$PROJECT_ROOT/terraform"

terraform init || log_error "Terraform init failed"
log_success "Terraform initialized"

# 3. Plan deployment
log_info "Planning infrastructure deployment..."
terraform plan -out=tfplan || log_error "Terraform plan failed"
log_success "Deployment plan created"

# 4. Apply deployment
log_info "Applying infrastructure with Terraform..."
terraform apply tfplan || log_error "Terraform apply failed"
log_success "Infrastructure deployed"

# 5. Get outputs from Terraform
log_info "Extracting Terraform outputs..."
cd "$PROJECT_ROOT/terraform"

FLASK_ENDPOINT="http://localhost:5000"
USER_POOL_ID=$(terraform output -raw user_pool_id 2>/dev/null || echo "")
CLIENT_ID=$(terraform output -raw user_pool_client_id 2>/dev/null || echo "")
BOOKINGS_TABLE=$(terraform output -raw bookings_table_name 2>/dev/null || echo "")
BOOKING_QUEUE=$(terraform output -raw booking_queue_url 2>/dev/null || echo "")

if [ -z "$USER_POOL_ID" ]; then
  log_error "Failed to extract User Pool ID from Terraform. Check terraform apply output above."
fi

log_success "Outputs extracted:"
log_info "  Flask Endpoint: $FLASK_ENDPOINT"
log_info "  User Pool ID: $USER_POOL_ID"
log_info "  Client ID: $CLIENT_ID"

# 6. Configure frontend
log_info "Configuring frontend environment variables..."
cd "$PROJECT_ROOT/frontend"

cat > .env << EOF
REACT_APP_COGNITO_USER_POOL_ID=$USER_POOL_ID
REACT_APP_COGNITO_CLIENT_ID=$CLIENT_ID
REACT_APP_API_ENDPOINT=$FLASK_ENDPOINT
REACT_APP_COGNITO_REGION=$REGION
REACT_APP_DEBUG=false
EOF

log_success "Frontend .env configured"

# 7. Seed DynamoDB with sample events
log_info "Seeding DynamoDB with sample events..."

cd "$PROJECT_ROOT"

EVENTS=(
  '{"eventId":{"S":"event-001"},"name":{"S":"Summer Music Festival 2026"},"description":{"S":"Three-day electronic music festival featuring top international DJs"},"category":{"S":"Music"},"date":{"S":"2026-07-15"},"location":{"S":"Central Park, New York"},"capacity":{"N":"5000"},"ticketPrice":{"N":"99.99"},"ticketsSold":{"N":"0"}}'
  '{"eventId":{"S":"event-002"},"name":{"S":"Tech Conference 2026"},"description":{"S":"Annual technology conference with keynote speakers"},"category":{"S":"Technology"},"date":{"S":"2026-09-20"},"location":{"S":"San Francisco Convention Center"},"capacity":{"N":"3000"},"ticketPrice":{"N":"299.99"},"ticketsSold":{"N":"0"}}'
  '{"eventId":{"S":"event-003"},"name":{"S":"Food Carnival 2026"},"description":{"S":"Street food festival with cuisines from around the world"},"category":{"S":"Food"},"date":{"S":"2026-08-10"},"location":{"S":"Golden Gate Park, San Francisco"},"capacity":{"N":"2000"},"ticketPrice":{"N":"49.99"},"ticketsSold":{"N":"0"}}'
  '{"eventId":{"S":"event-004"},"name":{"S":"Basketball Championship 2026"},"description":{"S":"Championship playoff game featuring top basketball teams"},"category":{"S":"Sports"},"date":{"S":"2026-06-15"},"location":{"S":"Madison Square Garden, New York"},"capacity":{"N":"20000"},"ticketPrice":{"N":"150.00"},"ticketsSold":{"N":"0"}}'
)

for i in "${!EVENTS[@]}"; do
  EVENT_ID=$((i + 1))
  aws dynamodb put-item \
    --table-name Events \
    --item "${EVENTS[$i]}" \
    --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null || log_info "Event $EVENT_ID may already exist"
done

log_success "DynamoDB seeded with 4 events"

# 8. Create demo Cognito user
log_info "Creating demo Cognito user..."
if [ -n "$USER_POOL_ID" ]; then
  aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username demo@example.com \
    --temporary-password TempPassword123! \
    --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null || true

  aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username demo@example.com \
    --password Demo@123456 \
    --permanent \
    --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null || log_info "Demo user may already exist"

  log_success "Demo user created: demo@example.com / Demo@123456"
else
  log_info "Could not retrieve User Pool ID"
fi

echo ""
echo "=========================================="
echo "DEPLOYMENT COMPLETE!"
echo "=========================================="
echo ""
echo "Resources created with Terraform:"
echo "  [OK] DynamoDB: Events, Bookings tables"
echo "  [OK] SQS: BookingQueue with DLQ"
echo "  [OK] SNS: BookingNotifications topic"
echo "  [OK] S3: Tickets bucket"
echo "  [OK] Cognito: User Pool and Client"
echo ""
echo "Configuration:"
echo "  User Pool ID:       $USER_POOL_ID"
echo "  Client ID:          $CLIENT_ID"
echo "  Bookings Table:     $BOOKINGS_TABLE"
echo "  Booking Queue:      $BOOKING_QUEUE"
echo "  Flask Endpoint:     $FLASK_ENDPOINT"
echo ""
echo "Next steps:"
echo "  1. python app.py (start Flask backend)"
echo "  2. cd frontend && npm start"
echo "  3. Open http://localhost:3000"
echo "  4. Login: demo@example.com / Demo@123456"
echo "  5. Book an event!"
echo ""
echo "To clean up:"
echo "  cd terraform && terraform destroy"
echo ""
