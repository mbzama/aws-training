#!/bin/bash
set -e

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

echo "=========================================="
echo "SQS Queues Contents"
echo "=========================================="
echo ""

# Get queue URLs
BOOKING_QUEUE_URL=$(aws sqs get-queue-url --queue-name BookingQueue --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null | jq -r '.QueueUrl')
BOOKING_DLQ_URL=$(aws sqs get-queue-url --queue-name BookingQueueDLQ --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null | jq -r '.QueueUrl')

echo "[Booking Queue]"
echo "URL: $BOOKING_QUEUE_URL"
BOOKING_MSGS=$(aws sqs get-queue-attributes --queue-url $BOOKING_QUEUE_URL --attribute-names ApproximateNumberOfMessages --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null | jq -r '.Attributes.ApproximateNumberOfMessages')
echo "Messages: $BOOKING_MSGS"
echo ""

if [ "$BOOKING_MSGS" -gt 0 ]; then
  echo "[Booking Queue Messages (Peek)]"
  # NOTE: Only peeking at messages without consuming them
  # Messages should only be consumed by the actual worker (worker.py)
  for i in $(seq 1 $BOOKING_MSGS); do
    MSG=$(aws sqs receive-message --queue-url $BOOKING_QUEUE_URL --attribute-names All --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null)
    if [ ! -z "$MSG" ]; then
      BODY=$(echo "$MSG" | jq -r '.Messages[0].Body // empty')
      if [ ! -z "$BODY" ]; then
        echo "Message $i:"
        echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
        # Return message to queue immediately (0 second visibility = visible again)
        MSG_HANDLE=$(echo "$MSG" | jq -r '.Messages[0].ReceiptHandle')
        aws sqs change-message-visibility --queue-url $BOOKING_QUEUE_URL --receipt-handle "$MSG_HANDLE" --visibility-timeout 0 --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null || true
      fi
    fi
  done
  echo ""
fi

echo "[Dead Letter Queue (DLQ)]"
echo "URL: $BOOKING_DLQ_URL"
DLQ_MSGS=$(aws sqs get-queue-attributes --queue-url $BOOKING_DLQ_URL --attribute-names ApproximateNumberOfMessages --endpoint-url $AWS_ENDPOINT_URL 2>/dev/null | jq -r '.Attributes.ApproximateNumberOfMessages')
echo "Failed Messages: $DLQ_MSGS"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Booking Queue: $BOOKING_MSGS pending"
echo "Dead Letter Queue: $DLQ_MSGS failed"
echo ""
