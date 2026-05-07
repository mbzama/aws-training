@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set VPC_DIR=%SCRIPT_DIR%..\vpc
set REDSHIFT_DIR=%SCRIPT_DIR%

echo ============================================
echo  Step 1: Provisioning VPC
echo ============================================
cd /d "%VPC_DIR%"
terraform init -input=false
if errorlevel 1 ( echo ERROR: terraform init failed for VPC & exit /b 1 )
terraform apply -auto-approve
if errorlevel 1 ( echo ERROR: terraform apply failed for VPC & exit /b 1 )

echo.
echo ============================================
echo  Step 2: Provisioning Redshift single-node
echo ============================================
cd /d "%REDSHIFT_DIR%"
terraform init -input=false
if errorlevel 1 ( echo ERROR: terraform init failed for Redshift & exit /b 1 )
terraform apply -auto-approve
if errorlevel 1 ( echo ERROR: terraform apply failed for Redshift & exit /b 1 )

echo.
echo ============================================
echo  Done -- outputs:
echo ============================================
terraform output

endlocal
