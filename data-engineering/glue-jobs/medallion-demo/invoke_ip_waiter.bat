@echo off
setlocal

set /p COUNT="How many Lambda invocations? "

if "%COUNT%"=="" (
    echo Error: please enter a number.
    exit /b 1
)

echo Invoking medallion-demo-ip-waiter %COUNT% time(s) asynchronously...
echo.

for /l %%i in (1,1,%COUNT%) do (
    echo [%%i/%COUNT%] Invoking...
    aws lambda invoke ^
        --function-name medallion-demo-ip-waiter ^
        --invocation-type Event ^
        --region us-east-1 ^
        response_%%i.json >nul 2>&1
    if errorlevel 1 (
        echo   FAILED - check your AWS credentials and region.
        exit /b 1
    )
    echo   OK
)

echo.
echo Done. %COUNT% invocation(s) fired. Each holds an ENI in PrivateSubnet1 for WAIT_SECONDS.
echo Now trigger the Bronze Glue job to observe IP exhaustion:
echo   aws glue start-job-run --job-name medallion-demo-bronze-ingestion --region us-east-1

endlocal
