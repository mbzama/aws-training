#!/bin/bash
set -e

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

echo "=========================================="
echo "S3 Buckets Contents"
echo "=========================================="
echo ""

echo "[Tickets Bucket: event-tickets-000000000000]"
aws s3 ls s3://event-tickets-000000000000 --endpoint-url $AWS_ENDPOINT_URL --recursive 2>/dev/null || echo "Bucket is empty"
echo ""

echo "=========================================="
echo "S3 Summary"
echo "=========================================="
TICKET_COUNT=$(aws s3 ls s3://event-tickets-000000000000 --endpoint-url $AWS_ENDPOINT_URL --recursive 2>/dev/null | wc -l)
echo "Tickets generated: $TICKET_COUNT"
echo ""
