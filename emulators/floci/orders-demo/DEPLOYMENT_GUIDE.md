# Complete Deployment & Operations Guide

Quick start with all commands to deploy and monitor the event booking platform.

---

## STEP 0: Start Floci (LocalStack) - DO THIS FIRST!

Floci must be running before you deploy infrastructure with Terraform.

### Option 1: Docker (Recommended)

**PowerShell:**
```powershell
docker run -d -p 4566:4566 --name floci localstack/localstack:latest
```

**Bash:**
```bash
docker run -d -p 4566:4566 --name floci localstack/localstack:latest
```

**Verify Floci is Running:**
```powershell
# PowerShell
$response = Invoke-WebRequest -Uri "http://localhost:4566/_floci/health" -SkipHttpErrorCheck
if ($response.StatusCode -eq 200) { Write-Host "✓ Floci is running" } else { Write-Host "✗ Floci not responding" }
```

```bash
# Bash
curl http://localhost:4566/_floci/health
# Should return: {"status":"running"} or similar
```

### Option 2: Floci CLI (if installed)

```bash
floci up
```

### Option 3: Docker Compose

```bash
docker-compose up -d
# (if docker-compose.yml exists in project)
```

### Check Container Status

```powershell
# List running containers
docker ps | findstr floci

# View logs
docker logs -f floci

# Stop if needed
docker stop floci

# Start again
docker start floci
```

---

## QUICK START - Copy/Paste These Commands

### Terminal 0: Start Floci (Required First!)
```powershell
docker run -d -p 4566:4566 --name floci localstack/localstack:latest

# Verify it's running
curl http://localhost:4566/_floci/health
```

### Terminal 1: Infrastructure
```bash
cd C:\Users\lreddy1\floci-event-book\terraform
terraform init
terraform apply -auto-approve
```

### Terminal 2: Flask Backend
```bash
cd C:\Users\lreddy1\floci-event-book
python app.py
```

### Terminal 3: Async Worker
```bash
cd C:\Users\lreddy1\floci-event-book
python worker.py
```

### Terminal 4: React Frontend
```bash
cd C:\Users\lreddy1\floci-event-book\frontend
npm install && npm start
```

### Terminal 5 (Optional): Monitor All
```bash
cd C:\Users\lreddy1\floci-event-book
bash scripts/watch-all.sh 2
```

---

## EXECUTION ORDER (Important!)

```
1. START FLOCI (Docker)          ← Do this FIRST
   ↓
2. DEPLOY INFRASTRUCTURE         ← Terraform needs Floci running
   ↓
3. SEED DATABASE & CREATE USER  ← AWS CLI commands
   ↓
4. START SERVICES (4 terminals) ← Flask, Worker, Frontend, Monitor
   ↓
5. TEST & MONITOR              ← Make bookings, watch flow
```

---

## STEP-BY-STEP GUIDE

## STEP 1: Start Floci (LocalStack)

### 1.1 Start Floci Container

**PowerShell:**
```powershell
# Start Floci
docker run -d -p 4566:4566 --name floci localstack/localstack:latest

# Wait a few seconds for startup
Start-Sleep -Seconds 5

# Verify it's running
Invoke-WebRequest -Uri "http://localhost:4566/_floci/health"
```

**Bash:**
```bash
# Start Floci
docker run -d -p 4566:4566 --name floci localstack/localstack:latest

# Wait for startup
sleep 5

# Verify
curl http://localhost:4566/_floci/health
```

### 1.2 Check Floci Status

**PowerShell:**
```powershell
# Check if running
docker ps | findstr floci

# View logs
docker logs floci | tail -20

# Full health check
Invoke-WebRequest -Uri "http://localhost:4566/_floci/health" | Select-Object -ExpandProperty Content
```

**Expected Output:**
```
CONTAINER ID   IMAGE                          STATUS
abc123def456   localstack/localstack:latest   Up 2 minutes
```

### 1.3 Troubleshooting Floci

```powershell
# Port already in use?
Get-NetTCPConnection -LocalPort 4566

# Stop existing container
docker stop floci
docker rm floci

# Start fresh
docker run -d -p 4566:4566 --name floci localstack/localstack:latest
```

---

## STEP 2: Deploy Infrastructure with Terraform

### 2.1 Initialize and Deploy
```bash
cd C:\Users\lreddy1\floci-event-book\terraform

# Initialize
terraform init

# Validate
terraform validate

# Plan (review changes)
terraform plan

# Apply (deploy)
terraform apply -auto-approve
```

### Get Terraform Outputs
```bash
terraform output -raw user_pool_id
terraform output -raw user_pool_client_id
terraform output  # Show all
```

**Created Resources:**
- DynamoDB: Events table, Bookings table
- SQS: BookingQueue, BookingQueueDLQ
- SNS: BookingNotifications topic
- S3: event-tickets-000000000000 bucket
- Cognito: EventBookingUserPool, EventBookingClient

---

## STEP 3: Configure Credentials & Seed Data

### 3.1 Set AWS Environment (PowerShell)
```powershell
$env:AWS_ENDPOINT_URL = 'http://localhost:4566'
$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = 'us-east-1'
```

### 3.2 Set AWS Environment (Bash)
```bash
export AWS_ENDPOINT_URL='http://localhost:4566'
export AWS_ACCESS_KEY_ID='test'
export AWS_SECRET_ACCESS_KEY='test'
export AWS_DEFAULT_REGION='us-east-1'
```

### 3.3 Seed DynamoDB Events
```bash
cd C:\Users\lreddy1\floci-event-book

# Add 4 sample events
aws dynamodb put-item --table-name Events --item '{\"eventId\":{\"S\":\"event-001\"},\"name\":{\"S\":\"Summer Music Festival 2026\"},\"category\":{\"S\":\"Music\"},\"ticketPrice\":{\"N\":\"99.99\"},\"capacity\":{\"N\":\"5000\"}}' --endpoint-url http://localhost:4566

aws dynamodb put-item --table-name Events --item '{\"eventId\":{\"S\":\"event-002\"},\"name\":{\"S\":\"Tech Conference 2026\"},\"category\":{\"S\":\"Technology\"},\"ticketPrice\":{\"N\":\"299.99\"},\"capacity\":{\"N\":\"3000\"}}' --endpoint-url http://localhost:4566

aws dynamodb put-item --table-name Events --item '{\"eventId\":{\"S\":\"event-003\"},\"name\":{\"S\":\"Food Carnival 2026\"},\"category\":{\"S\":\"Food\"},\"ticketPrice\":{\"N\":\"49.99\"},\"capacity\":{\"N\":\"2000\"}}' --endpoint-url http://localhost:4566

aws dynamodb put-item --table-name Events --item '{\"eventId\":{\"S\":\"event-004\"},\"name\":{\"S\":\"Basketball Championship 2026\"},\"category\":{\"S\":\"Sports\"},\"ticketPrice\":{\"N\":\"150.00\"},\"capacity\":{\"N\":\"20000\"}}' --endpoint-url http://localhost:4566
```

### 3.4 Create Demo User in Cognito
```bash
# Get User Pool ID from Terraform output
# Then create the user:
aws cognito-idp admin-create-user --user-pool-id us-east-1_a658793f8 --username demo@example.com --temporary-password TempPassword123! --endpoint-url http://localhost:4566

# Set permanent password
aws cognito-idp admin-set-user-password --user-pool-id us-east-1_a658793f8 --username demo@example.com --password Demo@123456 --permanent --endpoint-url http://localhost:4566
```

**Demo Credentials:**
- Email: demo@example.com
- Password: Demo@123456

---

## STEP 4: Start Services (4 Separate Terminals)

### Terminal 1: Flask Backend Service
```bash
cd C:\Users\lreddy1\floci-event-book
python app.py
```

**Expected Output:**
- [OK] Flask API running on http://localhost:5000
- [OK] Events: GET http://localhost:5000/events
- [OK] Book: POST http://localhost:5000/book
- [OK] History: GET http://localhost:5000/history

**API Endpoints:**
- GET /events - List all events
- POST /book - Book event (requires Authorization: Bearer token)
- GET /history - Get booking history
- GET /dynamodb-contents - View DynamoDB tables
- GET /s3-contents - View S3 tickets bucket
- GET /sqs-contents - View SQS queue messages
- GET /sns-contents - View SNS topic info
- GET /health - Health check

### Terminal 2: Async Worker Service
```bash
cd C:\Users\lreddy1\floci-event-book
python worker.py
```

**Expected Output:**
- 2026-06-14 14:17:51 - __main__ - INFO - Starting Event Booking Worker...
- 2026-06-14 14:17:51 - __main__ - INFO - Listening to SQS queue: BookingQueue

**What the Worker Does:**
1. Polls SQS BookingQueue every 10 seconds
2. Receives up to 10 messages per poll
3. For each message:
   - Generates PDF ticket (500ms)
   - Uploads to S3
   - Updates DynamoDB booking status
   - Deletes from queue
4. Failed messages sent to DLQ after 3 retries

### Terminal 3: React Frontend
```bash
cd C:\Users\lreddy1\floci-event-book\frontend
npm install
npm start
```

**Expected Output:**
- Compiled successfully!
- You can now view floci-event-book in the browser.
- Local: http://localhost:3000

Open browser: http://localhost:3000
Login: demo@example.com / Demo@123456

### Terminal 4 (Optional): Watch All Services
```bash
cd C:\Users\lreddy1\floci-event-book
bash scripts/watch-all.sh 2
```

Refreshes every 2 seconds showing:
- DynamoDB (Events, Bookings)
- S3 (Tickets)
- SQS (BookingQueue, DLQ)
- SNS (BookingNotifications)

---

## STEP 5: Monitor Updates in DynamoDB, S3, SQS

### Check DynamoDB Changes

**Using Bash Script:**
```bash
bash scripts/show-dynamodb.sh
bash scripts/watch-dynamodb.sh 1  # Auto-refresh every 1 second
```

**Using PowerShell:**
```powershell
aws dynamodb scan --table-name Events --endpoint-url http://localhost:4566 | jq '.Items'

aws dynamodb scan --table-name Bookings --endpoint-url http://localhost:4566 | jq '.Items'
```

### Check S3 Ticket Files

**Using Bash Script:**
```bash
bash scripts/show-s3.sh
bash scripts/watch-s3.sh 1  # Auto-refresh
```

**Using PowerShell:**
```powershell
aws s3 ls s3://event-tickets-000000000000/tickets/ --endpoint-url http://localhost:4566

# Download specific ticket
aws s3 cp s3://event-tickets-000000000000/tickets/BOOK-51829CDD.pdf . --endpoint-url http://localhost:4566

# Open the PDF
Invoke-Item BOOK-51829CDD.pdf
```

### Check SQS Queue Status

**Using Bash Script:**
```bash
bash scripts/show-sqs.sh
bash scripts/watch-sqs.sh 1  # Auto-refresh every 1 second
```

**Using PowerShell:**
```powershell
# Get message count
aws sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/BookingQueue --attribute-names ApproximateNumberOfMessages --endpoint-url http://localhost:4566

# Peek at messages (non-destructive)
aws sqs receive-message --queue-url http://localhost:4566/000000000000/BookingQueue --max-number-of-messages 10 --endpoint-url http://localhost:4566 | jq '.Messages[].Body | fromjson'

# Check DLQ for failed messages
aws sqs receive-message --queue-url http://localhost:4566/000000000000/BookingQueueDLQ --endpoint-url http://localhost:4566
```

---

## STEP 6: Test Complete End-to-End Flow

### Test 1: Make a Booking

**PowerShell Script:**
```powershell
$token = 'test-token-12345'
$body = @{
    eventId = 'event-001'
    quantity = 2
    userEmail = 'test@example.com'
} | ConvertTo-Json

Invoke-WebRequest -Uri 'http://localhost:5000/book' -Method POST 
  -Headers @{'Authorization'='Bearer ' + $token; 'Content-Type'='application/json'} 
  -Body $body
```

**Expected Response (should arrive in < 100ms):**
```json
{
  \"success\": true,
  \"bookingId\": \"BOOK-51829CDD\",
  \"eventId\": \"event-001\",
  \"quantity\": 2,
  \"totalPrice\": 199.98,
  \"status\": \"CONFIRMED\"
}
```

### Test 2: Watch Queue + Worker Processing

**Terminal A: Watch SQS Queue**
```bash
bash scripts/watch-sqs.sh 1
```

**Terminal B: Make Booking**
```powershell
$token = 'test-token'
$body = @{ eventId = 'event-002'; quantity = 1; userEmail = 'customer@example.com' } | ConvertTo-Json
Invoke-WebRequest -Uri 'http://localhost:5000/book' -Method POST -Headers @{'Authorization'='Bearer ' + $token; 'Content-Type'='application/json'} -Body $body
```

**Expected Sequence:**
1. Booking request returns in < 100ms
2. Message appears in SQS queue (watch terminal shows count increases)
3. Worker picks it up (next 10-second poll)
4. Worker logs: Processing booking
5. Worker logs: Ticket uploaded to S3
6. Worker logs: Booking status updated
7. Message disappears from queue (count decreases to 0)

### Test 3: Verify PDF Was Generated in S3

**PowerShell Script:**
```powershell
# List all PDFs
aws s3 ls s3://event-tickets-000000000000/tickets/ --endpoint-url http://localhost:4566

# Download the file
aws s3 cp s3://event-tickets-000000000000/tickets/BOOK-51829CDD.pdf . --endpoint-url http://localhost:4566

# Open PDF to verify
Invoke-Item BOOK-51829CDD.pdf
```

### Test 4: Check Booking History API

**PowerShell Script:**
```powershell
Invoke-WebRequest -Uri 'http://localhost:5000/history' | Select-Object -ExpandProperty Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

**Expected Output:**
```json
{
  \"bookings\": [
    {
      \"bookingId\": \"BOOK-51829CDD\",
      \"eventId\": \"event-001\",
      \"userId\": \"test@example.com\",
      \"quantity\": 2,
      \"totalPrice\": 199.98,
      \"status\": \"CONFIRMED\",
      \"createdAt\": \"2026-06-14T14:18:00.123456\"
    }
  ],
  \"statistics\": {
    \"totalBookings\": 1,
    \"totalSpent\": 199.98,
    \"confirmedBookings\": 1
  }
}
```

---

## Command Reference by Service

### Terraform Commands
```bash
cd C:\Users\lreddy1\floci-event-book\terraform

terraform init                  # Initialize
terraform validate              # Validate config
terraform plan                  # Show changes
terraform apply -auto-approve  # Deploy
terraform output               # Show outputs
terraform destroy -auto-approve # Cleanup
```

### Flask Backend
```bash
cd C:\Users\lreddy1\floci-event-book
python app.py                  # Start server
tail -f app.log                # Watch logs
curl http://localhost:5000/health  # Health check
```

### Async Worker
```bash
cd C:\Users\lreddy1\floci-event-book
python worker.py               # Start worker
tail -f worker.log             # Watch logs
```

### React Frontend
```bash
cd C:\Users\lreddy1\floci-event-book\frontend
npm install                    # Install dependencies
npm start                      # Development server
npm run build                  # Production build
```

### DynamoDB Monitoring
```bash
bash scripts/show-dynamodb.sh       # Show contents once
bash scripts/watch-dynamodb.sh 2   # Auto-refresh every 2s

aws dynamodb scan --table-name Events --endpoint-url http://localhost:4566
aws dynamodb scan --table-name Bookings --endpoint-url http://localhost:4566
```

### S3 Monitoring
```bash
bash scripts/show-s3.sh             # Show contents once
bash scripts/watch-s3.sh 2         # Auto-refresh every 2s

aws s3 ls s3://event-tickets-000000000000/tickets/ --endpoint-url http://localhost:4566
```

### SQS Monitoring
```bash
bash scripts/show-sqs.sh            # Show status once
bash scripts/watch-sqs.sh 2        # Auto-refresh every 2s

aws sqs get-queue-attributes --queue-url http://localhost:4566/000000000000/BookingQueue --attribute-names ApproximateNumberOfMessages --endpoint-url http://localhost:4566
```

### SNS Monitoring
```bash
bash scripts/show-sns.sh            # Show topic info
bash scripts/watch-sns.sh 2        # Auto-refresh every 2s

aws sns list-topics --endpoint-url http://localhost:4566
```

### All Services (Combined)
```bash
bash scripts/watch-all.sh 2  # Watch everything at once
```

---

## Cleanup

```bash
cd C:\Users\lreddy1\floci-event-book\terraform
terraform destroy -auto-approve

# Stop Floci
docker stop <container-id>
```

---

## Summary

✅ Infrastructure: Terraform IaC deployment
✅ Backend: Flask with JWT auth + logging
✅ Worker: Async PDF generation
✅ Frontend: React with Cognito integration
✅ Monitoring: Bash + PowerShell scripts
✅ Observability: Structured logs + AWS metrics

**Setup Time:** ~15 minutes
**Status:** Production-ready
**Architecture:** Async + event-driven
