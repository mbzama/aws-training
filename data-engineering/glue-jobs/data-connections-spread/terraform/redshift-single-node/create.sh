#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VPC_DIR="$SCRIPT_DIR/../vpc"
REDSHIFT_DIR="$SCRIPT_DIR"

echo "============================================"
echo " Step 1: Provisioning VPC"
echo "============================================"
cd "$VPC_DIR"
terraform init -input=false
terraform apply -auto-approve

echo ""
echo "============================================"
echo " Step 2: Provisioning Redshift single-node"
echo "============================================"
cd "$REDSHIFT_DIR"
terraform init -input=false
terraform apply -auto-approve

echo ""
echo "============================================"
echo " Done — outputs:"
echo "============================================"
terraform output
