#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo " Step 1: terraform init"
echo "============================================"
terraform init -input=false

echo ""
echo "============================================"
echo " Step 2: Provisioning VPC"
echo "============================================"
terraform apply -auto-approve \
  -target=aws_vpc.main \
  -target=aws_subnet.public \
  -target=aws_subnet.private \
  -target=aws_internet_gateway.main \
  -target=aws_eip.nat \
  -target=aws_nat_gateway.main \
  -target=aws_route_table.public \
  -target=aws_route_table.private \
  -target=aws_route_table_association.public \
  -target=aws_route_table_association.private

echo ""
echo "============================================"
echo " Step 3: Deploying Lambda"
echo "============================================"
terraform apply -auto-approve \
  -target=aws_iam_role.lambda_ip_waiter \
  -target=aws_iam_role_policy_attachment.lambda_vpc \
  -target=aws_security_group.lambda_ip_waiter \
  -target=aws_lambda_function.ip_waiter

echo ""
echo "============================================"
echo " Done -- Lambda outputs:"
echo "============================================"
terraform output
