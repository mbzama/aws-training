@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ============================================
echo  Step 1: terraform init
echo ============================================
terraform init -input=false
if errorlevel 1 ( echo ERROR: terraform init failed & exit /b 1 )

echo.
echo ============================================
echo  Step 2: Provisioning VPC
echo ============================================
terraform apply -auto-approve ^
  -target=aws_vpc.main ^
  -target=aws_subnet.public ^
  -target=aws_subnet.private ^
  -target=aws_internet_gateway.main ^
  -target=aws_eip.nat ^
  -target=aws_nat_gateway.main ^
  -target=aws_route_table.public ^
  -target=aws_route_table.private ^
  -target=aws_route_table_association.public ^
  -target=aws_route_table_association.private
if errorlevel 1 ( echo ERROR: VPC provisioning failed & exit /b 1 )

echo.
echo ============================================
echo  Step 3: Deploying Lambda
echo ============================================
terraform apply -auto-approve ^
  -target=aws_iam_role.lambda_ip_waiter ^
  -target=aws_iam_role_policy_attachment.lambda_vpc ^
  -target=aws_security_group.lambda_ip_waiter ^
  -target=aws_lambda_function.ip_waiter
if errorlevel 1 ( echo ERROR: Lambda deployment failed & exit /b 1 )

echo.
echo ============================================
echo  Done -- Lambda outputs:
echo ============================================
terraform output

endlocal
