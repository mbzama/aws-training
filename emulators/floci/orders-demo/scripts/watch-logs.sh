#!/bin/bash

# Watch CloudWatch Logs in real-time
# Shows all Lambda function logs as they execute

echo "=========================================="
echo "CloudWatch Logs Monitor"
echo "=========================================="
echo ""
echo "Streaming logs from all Lambda functions..."
echo "Press Ctrl+C to stop"
echo ""

aws logs tail /aws/lambda --follow --endpoint-url http://localhost:4566
