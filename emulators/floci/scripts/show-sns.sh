#!/bin/bash
set -e

export AWS_ENDPOINT_URL="http://localhost:4566"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"

echo "=========================================="
echo "SNS Topics Contents"
echo "=========================================="
echo ""

echo "[Topics]"
aws sns list-topics --endpoint-url $AWS_ENDPOINT_URL | jq '.Topics[] | {TopicArn: .TopicArn}'
echo ""

echo "[Subscriptions]"
aws sns list-subscriptions --endpoint-url $AWS_ENDPOINT_URL | jq '.Subscriptions[] | {TopicArn: .TopicArn, Protocol: .Protocol, Endpoint: .Endpoint}'
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
TOPIC_COUNT=$(aws sns list-topics --endpoint-url $AWS_ENDPOINT_URL | jq '.Topics | length')
SUB_COUNT=$(aws sns list-subscriptions --endpoint-url $AWS_ENDPOINT_URL | jq '.Subscriptions | length')

echo "Topics: $TOPIC_COUNT"
echo "Subscriptions: $SUB_COUNT"
echo ""
