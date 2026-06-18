# Floci Deployment Guide

Complete guide to deploying the Event Ticket Booking Platform to Floci (LocalStack AWS emulator).

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Floci Quick Start](#floci-quick-start)
3. [Step-by-Step Deployment](#step-by-step-deployment)
4. [Configuration](#configuration)
5. [Verification](#verification)
6. [Troubleshooting](#troubleshooting)
7. [Cleanup](#cleanup)

## Prerequisites

### Required Tools
- Docker or Podman (for Floci)
- AWS CLI v2
- SAM CLI
- Node.js 22.x
- npm or yarn
- Git

### Installation

**AWS CLI:**
```bash
# Windows (using chocolatey)
choco install awscli

# macOS
brew install awscli

# Linux
pip install awscli
```

**SAM CLI:**
```bash
pip install aws-sam-cli
```

**Node.js 22.x:**
```bash
# Using nvm (recommended)
nvm install 22
nvm use 22

# Or download from https://nodejs.org/
```

### Account Setup (for AWS Deployment)
- AWS Account with appropriate permissions
- AWS credentials configured: `aws configure`
- IAM user with AdministratorAccess or equivalent

---

## Floci Quick Start with Podman

The fastest way to get started:

```bash
# 1. Start Floci (all services with Podman)
podman-compose up -d

# 2. Wait for health check (15-30 seconds)
podman-compose logs -f floci

# 3. Deploy application
bash scripts/deploy.sh

# 4. Start frontend
cd frontend && npm start
```

Access app at **http://localhost:3000**

---

## Step-by-Step Deployment

### Step 1: Start Floci Container with Podman

**Option A: Using podman-compose (recommended):**
```bash
# Project root directory
podman-compose up -d

# Or with newer Podman built-in compose:
podman compose up -d

# Monitor startup
podman-compose logs -f floci

# Press Ctrl+C when you see "LOCALSTACK_READY"
```

**Option B: Manual podman run:

*Using Podman (Linux/macOS/Windows):*
```bash
podman run -d \
  --name floci \
  -p 4566:4566 \
  -e SERVICES=dynamodb,lambda,sqs,sns,s3,apigateway,cognito-idp,cloudwatch,logs \
  -e LAMBDA_EXECUTOR=podman \
  -e DOCKER_HOST=unix:///run/podman/podman.sock \
  -e PERSISTENCE=1 \
  -v /run/podman/podman.sock:/run/podman/podman.sock \
  -v $(pwd)/floci-data:/tmp/localstack/data \
  localstack/localstack:latest
```

**For rootless Podman** (if running without root):
```bash
podman run -d \
  --name floci \
  -p 4566:4566 \
  -e SERVICES=dynamodb,lambda,sqs,sns,s3,apigateway,cognito-idp,cloudwatch,logs \
  -e LAMBDA_EXECUTOR=podman \
  -e DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock \
  -e PERSISTENCE=1 \
  -v /run/user/$(id -u)/podman/podman.sock:/run/user/$(id -u)/podman/podman.sock \
  -v $(pwd)/floci-data:/tmp/localstack/data \
  localstack/localstack:latest
```

### Verify Floci is Running

```bash
# Health check
curl http://localhost:4566/_localstack/health

# Expected output:
# {"state": "running", "services": {...}}

# Or use CLI
aws --endpoint-url=http://localhost:4566 lambda list-functions
```

**Verify Floci is running:**
```bash
curl -s http://localhost:4566/_localstack/health | jq '.'
```

Expected output:
```json
{
  "services": {
    "dynamodb": "running",
    "lambda": "running",
    "sqs": "running",
    "sns": "running",
    "s3": "running",
    "apigateway": "running",
    "cognito-idp": "running"
  },
  "state": "running"
}
```

### Step 2: Deploy Complete Application

The `deploy.sh` script handles everything automatically:

```bash
# From project root
bash scripts/deploy.sh
```

**This script does:**
1. ✅ Verifies Floci is running
2. ✅ Sets AWS credentials for Floci
3. ✅ Builds SAM template
4. ✅ Deploys CloudFormation stack
5. ✅ Seeds DynamoDB with 4 sample events
6. ✅ Creates demo Cognito user
7. ✅ Generates frontend `.env` with stack outputs
8. ✅ Builds React frontend
9. ✅ Uploads frontend to S3
10. ✅ Runs smoke test

**Expected output:**
```
==========================================
DEPLOYMENT COMPLETE
==========================================

Stack Outputs:
OutputKey                   OutputValue
-----------------------     -------...
ApiEndpoint                 http://localhost:4566/...
UserPoolId                  us-east-1_xxxxx
FrontendBucketName         frontend-bucket-xxxx
...

Next Steps:
1. cd frontend && npm start
2. Open http://localhost:3000
3. Login: demo@example.com / Demo@123456
```

### Step 3: Start Frontend

```bash
cd frontend
npm start
```

Browser opens at **http://localhost:3000**

---

## Manual Component Deployment (Advanced)

If you need to deploy individual components instead of using the automated script:

## Floci Configuration

### Environment Variables

The deployment script automatically sets:
```bash
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT_URL=http://localhost:4566
```

### Customizing Floci Services

Edit `docker-compose.yml` to enable/disable services:
```yaml
environment:
  - SERVICES=dynamodb,s3,sqs,sns,apigateway,cognito-idp,lambda,cloudwatch,logs
```

Available services: dynamodb, s3, sqs, sns, apigateway, cognito-idp, lambda, cloudwatch, logs, and more.

### Persistent Storage

Data persists in `./floci-data/` folder:
```
floci-data/
├── dynamodb/
├── s3/
├── sqs/
├── sns/
└── lambda/
```

To keep data between restarts, leave the volume mounted. To reset data:
```bash
docker-compose down
rm -rf floci-data/
docker-compose up -d
```

---

## AWS Production Deployment (When Ready)

When you're ready to deploy to actual AWS, the process is similar:

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

2. **Update the deploy script** to use actual AWS endpoints instead of `http://localhost:4566`

3. **Run SAM deployment:**
   ```bash
   cd backend
   sam build
   sam deploy --guided
   ```

For now, **all development is done with Floci locally**. The infrastructure code in `template.yaml` is identical for both environments.

---

## Configuration

### Environment Variables

**Lambda Functions** (`backend/template.yaml`):
```yaml
Environment:
  Variables:
    BOOKINGS_TABLE: !Ref BookingsTable
    EVENTS_TABLE: !Ref EventsTable
    BOOKING_QUEUE_URL: !Ref BookingQueue
    BOOKING_TOPIC_ARN: !Ref BookingNotificationTopic
    TICKETS_BUCKET: !Ref TicketsBucket
    LOG_LEVEL: INFO
```

**Frontend** (`.env`):
```
REACT_APP_COGNITO_USER_POOL_ID=us-east-1_xxxxx
REACT_APP_COGNITO_CLIENT_ID=xxxxx
REACT_APP_API_ENDPOINT=https://api.example.com
```

### Updating Configuration

**Change Lambda timeout:**
```yaml
Globals:
  Function:
    Timeout: 60  # Change to desired timeout in seconds
```

**Change DynamoDB billing:**
```yaml
BookingsTable:
  BillingMode: PROVISIONED  # or PAY_PER_REQUEST
  ProvisionedThroughputCapacity:
    ReadCapacityUnits: 5
    WriteCapacityUnits: 5
```

---

## Verification

### Test API Endpoints

**Get Events:**
```bash
curl -X GET \
  "https://api.example.com/events" \
  -H "Content-Type: application/json"
```

**Search Events:**
```bash
curl -X GET \
  "https://api.example.com/events/search?q=music" \
  -H "Content-Type: application/json"
```

**Book Tickets:**
```bash
curl -X POST \
  "https://api.example.com/book" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "eventId": "event-001",
    "quantity": 2
  }'
```

**Get Booking History:**
```bash
curl -X GET \
  "https://api.example.com/history" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Verify AWS Resources

**Check DynamoDB Tables:**
```bash
aws dynamodb list-tables --region $REGION
```

**Check SQS Queues:**
```bash
aws sqs list-queues --region $REGION
```

**Check SNS Topics:**
```bash
aws sns list-topics --region $REGION
```

**Check S3 Buckets:**
```bash
aws s3 ls --region $REGION
```

**Check Lambda Functions:**
```bash
aws lambda list-functions --region $REGION
```

**Check CloudWatch Logs:**
```bash
aws logs describe-log-groups --region $REGION
```

---

## Cleanup

### Delete Floci Container

```bash
# Stop container
podman stop floci

# Remove container
podman rm floci

# Remove image
podman rmi floci/floci
```

### Delete AWS Stack

```bash
# Delete stack
aws cloudformation delete-stack \
  --stack-name event-booking-platform-prod \
  --region $REGION

# Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name event-booking-platform-prod \
  --region $REGION

echo "Stack deleted successfully"
```

### Remove S3 Artifacts Bucket

```bash
# Empty bucket first
aws s3 rm s3://$BUCKET_NAME --recursive

# Delete bucket
aws s3 rb s3://$BUCKET_NAME
```

### Remove CloudFormation Stack Files

```bash
rm -rf backend/.aws-sam
rm -rf backend/samconfig.toml
```

---

## Troubleshooting

### Issue: Floci won't start

**Solution:**
```bash
# Check if port 4566 is already in use
lsof -i :4566

# Kill existing process
kill -9 <PID>

# Try again
podman run -d --name floci -p 4566:4566 localstack/localstack:latest
```

### Issue: Lambda functions not executing

**Solution:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/event-booking-book --follow

# Check Lambda errors
aws lambda get-function --function-name event-booking-book
```

### Issue: DynamoDB table not found

**Solution:**
```bash
# Check if table exists
aws dynamodb describe-table --table-name Bookings

# If not, redeploy SAM stack
sam deploy --guided
```

### Issue: Frontend not connecting to API

**Solution:**
1. Check CORS configuration in API Gateway
2. Verify API endpoint in .env file
3. Check browser console for errors
4. Verify Lambda function is accessible

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
