#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Required env vars (export before running, or apply terraform/lambda first):
#   LAMBDA_ROLE_ARN   — IAM role ARN the functions will assume
#   SUBNET_ID         — Subnet ID passed to check-ips and clean-ips
#                       (defaults to private-subnet-2 from terraform/lambda output)
#
# Optional:
#   POC_TAG_VALUE     — Tag value for PoC ENIs (default: subnet-exhaustion-test)
#   REGION            — AWS region (default: us-east-2)
#   RUNTIME           — Python runtime (default: python3.12)
# ---------------------------------------------------------------------------

REGION="${REGION:-us-east-1}"
RUNTIME="${RUNTIME:-python3.12}"
POC_TAG_VALUE="${POC_TAG_VALUE:-subnet-exhaustion-test}"
LAMBDA_DIR="lambda"
BUILD_DIR=".build"
TF_DIR="terraform/lambda"

LAMBDA_ROLE_ARN="${LAMBDA_ROLE_ARN:-$(terraform -chdir="$TF_DIR" output -raw lambda_role_arn 2>/dev/null)}"
SUBNET_ID="${SUBNET_ID:-$(terraform -chdir="$TF_DIR" output -raw private_subnet_2_id 2>/dev/null)}"

: "${LAMBDA_ROLE_ARN:?LAMBDA_ROLE_ARN must be set (or run: terraform -chdir=$TF_DIR apply)}"
: "${SUBNET_ID:?SUBNET_ID must be set (or run: terraform -chdir=$TF_DIR apply)}"

mkdir -p "$BUILD_DIR"

deploy_function() {
    local name="$1"
    local source_file="$LAMBDA_DIR/$name.py"
    local zip_file="$BUILD_DIR/$name.zip"
    local handler="$name.lambda_handler"

    echo ">>> Packaging $name..."
    rm -f "$zip_file"
    zip -j "$zip_file" "$source_file"

    # Build environment variables JSON for this function
    local env_vars
    case "$name" in
        check-ips)
            env_vars="{\"Variables\":{\"SUBNET_ID\":\"$SUBNET_ID\"}}"
            ;;
        clean-ips)
            env_vars="{\"Variables\":{\"SUBNET_ID\":\"$SUBNET_ID\",\"POC_TAG_VALUE\":\"$POC_TAG_VALUE\"}}"
            ;;
        create-ips)
            env_vars="{\"Variables\":{}}"
            ;;
        create-eni)
            env_vars="{\"Variables\":{\"SUBNET_ID\":\"$SUBNET_ID\",\"POC_TAG_VALUE\":\"$POC_TAG_VALUE\"}}"
            ;;
    esac

    # Check if function exists
    if aws lambda get-function --function-name "$name" --region "$REGION" &>/dev/null; then
        echo ">>> Updating $name..."
        aws lambda update-function-code \
            --function-name "$name" \
            --zip-file "fileb://$zip_file" \
            --region "$REGION" \
            --output text --query 'FunctionArn'

        aws lambda update-function-configuration \
            --function-name "$name" \
            --environment "$env_vars" \
            --region "$REGION" \
            --output text --query 'FunctionArn'
    else
        echo ">>> Creating $name..."
        aws lambda create-function \
            --function-name "$name" \
            --runtime "$RUNTIME" \
            --role "$LAMBDA_ROLE_ARN" \
            --handler "$handler" \
            --zip-file "fileb://$zip_file" \
            --environment "$env_vars" \
            --timeout 60 \
            --memory-size 128 \
            --region "$REGION" \
            --output text --query 'FunctionArn'
    fi

    echo ">>> Waiting for $name to be active..."
    aws lambda wait function-active --function-name "$name" --region "$REGION"
    echo ">>> $name deployed."
    echo
}

deploy_function "check-ips"
deploy_function "clean-ips"
deploy_function "create-ips"
deploy_function "create-eni"

rm -rf "$BUILD_DIR"
echo "All functions deployed."
