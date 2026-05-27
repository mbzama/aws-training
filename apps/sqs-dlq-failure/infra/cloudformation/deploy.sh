#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Deploy or update the SQS + DLQ CloudFormation stack
#
# Usage:
#   ./deploy.sh [environment] [aws-profile]
#
# Examples:
#   ./deploy.sh                     # defaults: env=dev, profile=default
#   ./deploy.sh staging my-profile  # staging env with named AWS profile
#   ./deploy.sh prod prod-admin     # production deployment
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

ENVIRONMENT="${1:-dev}"
AWS_PROFILE="${2:-default}"
STACK_NAME="sqs-dlq-failure-${ENVIRONMENT}"
TEMPLATE_FILE="$(dirname "$0")/sqs-queues.yml"
REGION="${AWS_REGION:-us-east-1}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deploying SQS + DLQ Stack"
echo "  Stack      : ${STACK_NAME}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Region     : ${REGION}"
echo "  Profile    : ${AWS_PROFILE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Validate the template first
echo ""
echo "🔍 Validating template..."
aws cloudformation validate-template \
  --template-body "file://${TEMPLATE_FILE}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --output text \
  --query 'Description'

echo "✅ Template valid"
echo ""

# Deploy (create or update)
echo "🚀 Deploying stack..."
aws cloudformation deploy \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --parameter-overrides \
      Environment="${ENVIRONMENT}" \
  --capabilities CAPABILITY_IAM \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --no-fail-on-empty-changeset

echo ""
echo "✅ Stack deployed successfully!"
echo ""

# Print outputs — copy the URLs into .env.local
echo "📋 Stack Outputs (paste into .env.local):"
echo "──────────────────────────────────────────"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${REGION}" \
  --profile "${AWS_PROFILE}" \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
