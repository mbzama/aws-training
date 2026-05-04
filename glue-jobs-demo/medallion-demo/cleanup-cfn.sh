#!/usr/bin/env bash
# Tear down the medallion demo CloudFormation stack.
# Empties the versioned S3 bucket before deleting the stack.
set -euo pipefail

STACK_NAME="medallion-demo"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}=============================================${NC}"
echo -e "${YELLOW}  Medallion Demo — CloudFormation Cleanup    ${NC}"
echo -e "${YELLOW}=============================================${NC}"

# --- Check the stack exists ---

if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
  echo ""
  echo "Stack '$STACK_NAME' does not exist. Nothing to clean up."
  exit 0
fi

# --- Get the bucket name before the stack is gone ---

BUCKET_NAME=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`S3BucketName`].OutputValue' \
  --output text 2>/dev/null || echo "")

echo ""
echo -e "${RED}WARNING: The following will be permanently deleted:${NC}"
echo "  CloudFormation stack : $STACK_NAME"
[ -n "$BUCKET_NAME" ] && echo "  S3 bucket + contents : $BUCKET_NAME"
echo ""
read -rp "Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "Cleanup cancelled."
  exit 0
fi

# --- Empty the versioned S3 bucket ---
# CloudFormation cannot delete a non-empty S3 bucket; versioned buckets require
# explicit deletion of all versions and delete markers.

if [ -n "$BUCKET_NAME" ]; then
  echo ""
  echo -e "${YELLOW}Emptying S3 bucket '$BUCKET_NAME'...${NC}"
  python3 - "$BUCKET_NAME" "$REGION" <<'EOF'
import sys
import json
import subprocess

bucket = sys.argv[1]
region = sys.argv[2]

def list_versions(bucket, region):
    result = subprocess.run(
        ["aws", "s3api", "list-object-versions",
         "--bucket", bucket, "--region", region, "--output", "json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return [], []
    data = json.loads(result.stdout or '{}')
    versions = data.get("Versions") or []
    markers = data.get("DeleteMarkers") or []
    return versions, markers

def delete_batch(bucket, region, objects):
    if not objects:
        return
    payload = json.dumps({"Objects": objects, "Quiet": True})
    subprocess.run(
        ["aws", "s3api", "delete-objects",
         "--bucket", bucket, "--region", region,
         "--delete", payload],
        check=True, capture_output=True
    )

versions, markers = list_versions(bucket, region)

version_keys = [{"Key": v["Key"], "VersionId": v["VersionId"]} for v in versions]
marker_keys  = [{"Key": m["Key"], "VersionId": m["VersionId"]} for m in markers]

# Delete in batches of 1000 (AWS limit)
for i in range(0, len(version_keys), 1000):
    delete_batch(bucket, region, version_keys[i:i+1000])
for i in range(0, len(marker_keys), 1000):
    delete_batch(bucket, region, marker_keys[i:i+1000])

print(f"  Deleted {len(version_keys)} object version(s) and {len(marker_keys)} delete marker(s)")
EOF
fi

# --- Delete the CloudFormation stack ---

echo ""
echo -e "${YELLOW}Deleting CloudFormation stack '$STACK_NAME'...${NC}"
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"

echo "Waiting for stack deletion to complete..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"

echo ""
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  Cleanup complete!${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo "To redeploy, run:  ./deploy-cfn.sh"
echo ""
