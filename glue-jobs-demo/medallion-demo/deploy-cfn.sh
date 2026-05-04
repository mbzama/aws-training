#!/usr/bin/env bash
# Deploy the medallion demo using CloudFormation.
# Usage: ./deploy-cfn.sh [bucket-suffix]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="medallion-demo"
TEMPLATE_FILE="${SCRIPT_DIR}/cloudformation/template.yaml"
SCRIPTS_DIR="${SCRIPT_DIR}/glue_scripts"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Medallion Demo — CloudFormation Deployment ${NC}"
echo -e "${GREEN}=============================================${NC}"

# --- Preflight checks ---

echo ""
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &>/dev/null; then
  echo -e "${RED}ERROR: AWS CLI is not installed.${NC}"
  exit 1
fi

IDENTITY=$(aws sts get-caller-identity 2>&1) || {
  echo -e "${RED}ERROR: AWS credentials not configured or invalid.${NC}"
  exit 1
}
ACCOUNT_ID=$(echo "$IDENTITY" | python3 -c "import sys, json; print(json.load(sys.stdin)['Account'])")
echo "  AWS Account : $ACCOUNT_ID"
echo "  Region      : $REGION"

# --- Determine bucket suffix ---

BUCKET_SUFFIX="${1:-}"
if [ -z "$BUCKET_SUFFIX" ]; then
  echo ""
  read -rp "Enter a unique bucket suffix (Enter to use account ID '$ACCOUNT_ID'): " BUCKET_SUFFIX
  BUCKET_SUFFIX="${BUCKET_SUFFIX:-$ACCOUNT_ID}"
fi

echo ""
echo "  Stack name    : $STACK_NAME"
echo "  Bucket suffix : $BUCKET_SUFFIX"
echo "  Template      : $TEMPLATE_FILE"
echo ""
read -rp "Proceed with deployment? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# --- Deploy CloudFormation stack ---

echo ""
echo -e "${YELLOW}Deploying CloudFormation stack...${NC}"
aws cloudformation deploy \
  --stack-name "$STACK_NAME" \
  --template-file "$TEMPLATE_FILE" \
  --parameter-overrides \
    BucketSuffix="$BUCKET_SUFFIX" \
    Environment=dev \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "$REGION"

# --- Upload Glue scripts ---

echo ""
echo -e "${YELLOW}Retrieving bucket name from stack outputs...${NC}"
BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text)
echo "  Bucket: $BUCKET_NAME"

echo ""
echo -e "${YELLOW}Uploading Glue scripts to S3...${NC}"
for script in bronze_ingestion.py silver_transformation.py gold_aggregation.py; do
  echo "  Uploading $script..."
  aws s3 cp "${SCRIPTS_DIR}/${script}" "s3://${BUCKET_NAME}/scripts/${script}" --region "$REGION"
done

# --- Show stack outputs ---

echo ""
echo -e "${GREEN}Stack outputs:${NC}"
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[*].[OutputKey, OutputValue]' \
  --output table

WORKFLOW_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`WorkflowName`].OutputValue' \
  --output text)

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Deployment complete!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "To run the medallion pipeline:"
echo ""
echo "  aws glue start-workflow-run --name $WORKFLOW_NAME --region $REGION"
echo ""
