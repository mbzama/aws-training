@echo off
setlocal EnableDelayedExpansion

REM ---------------------------------------------------------------------------
REM Required env vars (set before running, or apply terraform/lambda first):
REM   LAMBDA_ROLE_ARN   - IAM role ARN the functions will assume
REM   SUBNET_ID         - Subnet ID passed to check-ips and clean-ips
REM                       (defaults to private-subnet-2 from terraform/lambda output)
REM
REM Optional:
REM   POC_TAG_VALUE     - Tag value for PoC ENIs (default: subnet-exhaustion-test)
REM   REGION            - AWS region (default: us-east-2)
REM   RUNTIME           - Python runtime (default: python3.12)
REM ---------------------------------------------------------------------------

IF NOT DEFINED REGION    SET "REGION=us-east-1"
IF NOT DEFINED RUNTIME   SET "RUNTIME=python3.12"
IF NOT DEFINED POC_TAG_VALUE SET "POC_TAG_VALUE=subnet-exhaustion-test"
SET "LAMBDA_DIR=lambda"
SET "BUILD_DIR=.build"
SET "TF_DIR=%~dp0terraform\lambda"

IF DEFINED LAMBDA_ROLE_ARN GOTO :check_subnet
FOR /F "usebackq delims=" %%i IN (`powershell -NoProfile -Command "terraform -chdir='%TF_DIR%' output -raw lambda_role_arn"`) DO SET "LAMBDA_ROLE_ARN=%%i"
IF NOT DEFINED LAMBDA_ROLE_ARN echo ERROR: LAMBDA_ROLE_ARN not set and could not be read from %TF_DIR% & exit /b 1

:check_subnet
IF DEFINED SUBNET_ID GOTO :pre_build
FOR /F "usebackq delims=" %%i IN (`powershell -NoProfile -Command "terraform -chdir='%TF_DIR%' output -raw private_subnet_2_id"`) DO SET "SUBNET_ID=%%i"
IF NOT DEFINED SUBNET_ID echo ERROR: SUBNET_ID not set and could not be read from %TF_DIR% & exit /b 1

:pre_build

IF NOT EXIST "%BUILD_DIR%" mkdir "%BUILD_DIR%"

CALL :deploy_function "check-ips"
IF ERRORLEVEL 1 exit /b 1

CALL :deploy_function "clean-ips"
IF ERRORLEVEL 1 exit /b 1

CALL :deploy_function "create-ips"
IF ERRORLEVEL 1 exit /b 1

CALL :deploy_function "create-eni"
IF ERRORLEVEL 1 exit /b 1

rmdir /s /q "%BUILD_DIR%"
echo All functions deployed.
exit /b 0

:deploy_function
SET "FN_NAME=%~1"
SET "FN_SOURCE=%LAMBDA_DIR%\%FN_NAME%.py"
SET "FN_ZIP=%BUILD_DIR%\%FN_NAME%.zip"
SET "FN_HANDLER=%FN_NAME%.lambda_handler"

echo --- Packaging %FN_NAME%...
IF EXIST "%FN_ZIP%" del /f /q "%FN_ZIP%"
powershell -NoProfile -Command "Compress-Archive -LiteralPath '%FN_SOURCE%' -DestinationPath '%FN_ZIP%' -Force"
IF ERRORLEVEL 1 (
    echo ERROR: Failed to create zip for %FN_NAME%
    exit /b 1
)

REM Build environment variables JSON (\"...\" is AWS CLI v2 Windows quoting)
IF "%FN_NAME%"=="check-ips" (
    SET "FN_ENV={\"Variables\":{\"SUBNET_ID\":\"%SUBNET_ID%\"}}"
) ELSE IF "%FN_NAME%"=="clean-ips" (
    SET "FN_ENV={\"Variables\":{\"SUBNET_ID\":\"%SUBNET_ID%\",\"POC_TAG_VALUE\":\"%POC_TAG_VALUE%\"}}"
) ELSE IF "%FN_NAME%"=="create-ips" (
    SET "FN_ENV={\"Variables\":{}}"
) ELSE IF "%FN_NAME%"=="create-eni" (
    SET "FN_ENV={\"Variables\":{\"SUBNET_ID\":\"%SUBNET_ID%\",\"POC_TAG_VALUE\":\"%POC_TAG_VALUE%\"}}"
)

REM Check if function exists
aws lambda get-function --function-name "%FN_NAME%" --region "%REGION%" >nul 2>&1
IF ERRORLEVEL 1 (
    echo --- Creating %FN_NAME%...
    aws lambda create-function ^
        --function-name "%FN_NAME%" ^
        --runtime "%RUNTIME%" ^
        --role "%LAMBDA_ROLE_ARN%" ^
        --handler "%FN_HANDLER%" ^
        --zip-file "fileb://%FN_ZIP%" ^
        --environment %FN_ENV% ^
        --timeout 60 ^
        --memory-size 128 ^
        --region "%REGION%" ^
        --output text --query "FunctionArn"
    IF ERRORLEVEL 1 exit /b 1
) ELSE (
    echo --- Updating %FN_NAME%...
    aws lambda update-function-code ^
        --function-name "%FN_NAME%" ^
        --zip-file "fileb://%FN_ZIP%" ^
        --region "%REGION%" ^
        --output text --query "FunctionArn"
    IF ERRORLEVEL 1 exit /b 1

    aws lambda update-function-configuration ^
        --function-name "%FN_NAME%" ^
        --environment %FN_ENV% ^
        --region "%REGION%" ^
        --output text --query "FunctionArn"
    IF ERRORLEVEL 1 exit /b 1
)

echo --- Waiting for %FN_NAME% to be active...
aws lambda wait function-active --function-name "%FN_NAME%" --region "%REGION%"
IF ERRORLEVEL 1 exit /b 1
echo --- %FN_NAME% deployed.
echo.
exit /b 0
