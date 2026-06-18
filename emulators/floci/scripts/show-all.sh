#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          Floci Event Booking - Infrastructure Status          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "1️⃣  DYNAMODB TABLES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPTS_DIR/show-dynamodb.sh"

echo ""
echo "2️⃣  S3 BUCKETS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPTS_DIR/show-s3.sh"

echo ""
echo "3️⃣  SQS QUEUES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPTS_DIR/show-sqs.sh"

echo ""
echo "4️⃣  SNS TOPICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$SCRIPTS_DIR/show-sns.sh"

echo ""
echo "✅ Infrastructure Status Complete"
echo ""
