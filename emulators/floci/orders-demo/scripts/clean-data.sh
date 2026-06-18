#!/bin/bash

# Clean all data from FLOCI services
# Keeps infrastructure (tables, queues, etc.) but deletes all records

set -e

FLOCI_ENDPOINT="http://localhost:4566"
REGION="us-east-1"

echo "=========================================="
echo "Cleaning FLOCI Data"
echo "=========================================="
echo ""
echo "This will delete:"
echo "  ✓ All bookings from DynamoDB"
echo "  ✓ All files from S3"
echo "  ✓ All messages from SQS"
echo "  ✓ All CloudWatch logs"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Cancelled"
  exit 1
fi

echo ""
echo "Starting cleanup..."
echo ""

# Set AWS credentials for Floci
export AWS_ENDPOINT_URL=$FLOCI_ENDPOINT
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=$REGION

# 1. Clear DynamoDB Bookings Table
echo "[1/5] Clearing DynamoDB Bookings table..."
BOOKINGS=$(aws dynamodb scan \
  --table-name Bookings \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | jq -r '.Items[] | "\(.userId.S),\(.bookingId.S)"')

COUNT=0
while IFS=',' read -r userId bookingId; do
  if [ -n "$userId" ] && [ -n "$bookingId" ]; then
    aws dynamodb delete-item \
      --table-name Bookings \
      --key "{\"userId\":{\"S\":\"$userId\"},\"bookingId\":{\"S\":\"$bookingId\"}}" \
      --endpoint-url $FLOCI_ENDPOINT 2>/dev/null
    COUNT=$((COUNT + 1))
  fi
done <<< "$BOOKINGS"

echo "  ✓ Deleted $COUNT bookings"

# 2. Clear DynamoDB Events Table (optional - usually want to keep sample events)
echo "[2/5] Events table - keeping sample events"

# 3. Clear S3 Tickets Bucket
echo "[3/5] Clearing S3 Tickets bucket..."
TICKETS=$(aws s3 ls s3://event-tickets-000000000000/ --recursive \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | awk '{print $4}')

TICKET_COUNT=0
while IFS= read -r file; do
  if [ -n "$file" ]; then
    aws s3 rm "s3://event-tickets-000000000000/$file" \
      --endpoint-url $FLOCI_ENDPOINT 2>/dev/null
    TICKET_COUNT=$((TICKET_COUNT + 1))
  fi
done <<< "$TICKETS"

echo "  ✓ Deleted $TICKET_COUNT ticket files"

# 4. Clear SQS Queues
echo "[4/5] Clearing SQS queues..."

# Get queue URLs
BOOKING_QUEUE=$(aws sqs list-queues \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  jq -r '.QueueUrls[] | select(contains("BookingQueue") and not contains("DLQ"))' | head -1)

DLQ_QUEUE=$(aws sqs list-queues \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  jq -r '.QueueUrls[] | select(contains("BookingQueueDLQ"))' | head -1)

# Purge queues
if [ -n "$BOOKING_QUEUE" ]; then
  aws sqs purge-queue --queue-url "$BOOKING_QUEUE" \
    --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true
  echo "  ✓ Purged BookingQueue"
fi

if [ -n "$DLQ_QUEUE" ]; then
  aws sqs purge-queue --queue-url "$DLQ_QUEUE" \
    --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true
  echo "  ✓ Purged BookingQueueDLQ"
fi

# 5. Clear CloudWatch Logs
echo "[5/5] Clearing CloudWatch Logs..."

LOG_GROUPS=$(aws logs describe-log-groups \
  --endpoint-url $FLOCI_ENDPOINT 2>/dev/null | \
  jq -r '.logGroups[].logGroupName' 2>/dev/null)

LOG_COUNT=0
while IFS= read -r log_group; do
  if [ -n "$log_group" ]; then
    # Delete log group
    aws logs delete-log-group --log-group-name "$log_group" \
      --endpoint-url $FLOCI_ENDPOINT 2>/dev/null || true
    LOG_COUNT=$((LOG_COUNT + 1))
  fi
done <<< "$LOG_GROUPS"

echo "  ✓ Cleared $LOG_COUNT log groups"

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "All data has been cleared:"
echo "  ✓ Bookings: $COUNT deleted"
echo "  ✓ Tickets: $TICKET_COUNT deleted"
echo "  ✓ SQS Queues: Purged"
echo "  ✓ CloudWatch Logs: $LOG_COUNT groups cleared"
echo ""
echo "Infrastructure remains intact (tables, queues, topics, etc.)"
echo ""
echo "Ready for fresh testing!"
echo ""
