#Requires -Version 5.0
param(
    [string]$Environment = 'local',
    [string]$Region = 'us-east-1'
)

$ErrorActionPreference = 'Stop'
$StackName = 'event-booking-platform'
$FlocaEndpoint = 'http://localhost:4566'

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{'Info'='Green'; 'Error'='Red'; 'Success'='Cyan'; 'Warning'='Yellow'; 'Header'='Blue'}
    Write-Host "[$timestamp] [$Level]" -ForegroundColor $colors[$Level] -NoNewline
    Write-Host " $Message"
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "===========================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "===========================================" -ForegroundColor Blue
    Write-Host ""
}

Write-Header "Event Ticket Booking Platform - Floci Deployment"

Write-Log "Verifying Floci is running..." 'Info'
try {
    $health = Invoke-WebRequest -Uri "$FlocaEndpoint/_localstack/health" -ErrorAction Stop
    Write-Log "Floci is running" 'Success'
}
catch {
    Write-Log "Floci is not running. Start it with: docker-compose up -d" 'Error'
    exit 1
}

Write-Log "Setting AWS credentials..." 'Info'
$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_ENDPOINT_URL = $FlocaEndpoint
Write-Log "AWS credentials configured" 'Success'

Write-Log "Deploying CloudFormation stack..." 'Info'
$templatePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'backend/template.yaml'
$templateBody = Get-Content -Path $templatePath -Raw

try {
    $existingStack = & aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $Region `
        --endpoint-url $FlocaEndpoint 2>$null

    if ($existingStack) {
        Write-Log "Stack exists, updating..." 'Info'
        & aws cloudformation update-stack `
            --template-body $templateBody `
            --stack-name $StackName `
            --region $Region `
            --parameters ParameterKey=Environment,ParameterValue=$Environment `
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
            --endpoint-url $FlocaEndpoint 2>&1 | ForEach-Object { Write-Log $_ 'Info' }
    }
    else {
        Write-Log "Creating new stack..." 'Info'
        & aws cloudformation create-stack `
            --template-body $templateBody `
            --stack-name $StackName `
            --region $Region `
            --parameters ParameterKey=Environment,ParameterValue=$Environment `
            --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM `
            --endpoint-url $FlocaEndpoint 2>&1 | ForEach-Object { Write-Log $_ 'Info' }
    }

    Write-Log "CloudFormation stack deployed" 'Success'
}
catch {
    Write-Log "CloudFormation deployment failed: $_" 'Error'
    exit 1
}

Write-Log "Retrieving stack outputs..." 'Info'
$stackOutputs = & aws cloudformation describe-stacks `
    --stack-name $StackName `
    --region $Region `
    --endpoint-url $FlocaEndpoint `
    --query "Stacks[0].Outputs" 2>$null | ConvertFrom-Json

$UserPoolId = ($stackOutputs | Where-Object { $_.OutputKey -eq 'UserPoolId' } | Select-Object -ExpandProperty OutputValue)
$ClientId = ($stackOutputs | Where-Object { $_.OutputKey -eq 'UserPoolClientId' } | Select-Object -ExpandProperty OutputValue)
$ApiEndpoint = ($stackOutputs | Where-Object { $_.OutputKey -eq 'ApiEndpoint' } | Select-Object -ExpandProperty OutputValue)
$FrontendBucket = ($stackOutputs | Where-Object { $_.OutputKey -eq 'FrontendBucketName' } | Select-Object -ExpandProperty OutputValue)

Write-Log "Creating demo Cognito user..." 'Info'
if ($UserPoolId) {
    $ErrorActionPreference = 'SilentlyContinue'
    & aws cognito-idp admin-create-user `
        --user-pool-id $UserPoolId `
        --username demo@example.com `
        --temporary-password TempPassword123! `
        --endpoint-url $FlocaEndpoint 2>$null

    & aws cognito-idp admin-set-user-password `
        --user-pool-id $UserPoolId `
        --username demo@example.com `
        --password Demo@123456 `
        --permanent `
        --endpoint-url $FlocaEndpoint 2>$null

    $ErrorActionPreference = 'Stop'
    Write-Log "Demo user: demo@example.com / Demo@123456" 'Success'
}

Write-Log "Seeding DynamoDB with sample events..." 'Info'

$events = @(
    '{"eventId":{"S":"event-001"},"name":{"S":"Summer Music Festival 2026"},"description":{"S":"Three-day electronic music festival featuring top international DJs"},"category":{"S":"Music"},"date":{"S":"2026-07-15"},"location":{"S":"Central Park, New York"},"capacity":{"N":"5000"},"ticketPrice":{"N":"99.99"}}'
    '{"eventId":{"S":"event-002"},"name":{"S":"Tech Conference 2026"},"description":{"S":"Annual technology conference with keynote speakers"},"category":{"S":"Technology"},"date":{"S":"2026-09-20"},"location":{"S":"San Francisco Convention Center"},"capacity":{"N":"3000"},"ticketPrice":{"N":"299.99"}}'
    '{"eventId":{"S":"event-003"},"name":{"S":"Food Carnival 2026"},"description":{"S":"Street food festival with cuisines from around the world"},"category":{"S":"Food"},"date":{"S":"2026-08-10"},"location":{"S":"Golden Gate Park, San Francisco"},"capacity":{"N":"2000"},"ticketPrice":{"N":"49.99"}}'
    '{"eventId":{"S":"event-004"},"name":{"S":"Basketball Championship 2026"},"description":{"S":"Championship playoff game featuring top basketball teams"},"category":{"S":"Sports"},"date":{"S":"2026-06-15"},"location":{"S":"Madison Square Garden, New York"},"capacity":{"N":"20000"},"ticketPrice":{"N":"150.00"}}'
)

$tempDir = [System.IO.Path]::GetTempPath()
foreach ($json in $events) {
    $tempFile = Join-Path $tempDir "item-$([guid]::NewGuid()).json"
    [System.IO.File]::WriteAllText($tempFile, $json)
    & aws dynamodb put-item --table-name Events --item file://$tempFile --endpoint-url $FlocaEndpoint 2>$null
    Remove-Item -Path $tempFile -Force
}
Write-Log "DynamoDB seeded with 4 events" 'Success'

Write-Log "Configuring frontend..." 'Info'
$frontendPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'frontend'
Push-Location $frontendPath

$envLines = @(
    "REACT_APP_COGNITO_USER_POOL_ID=$UserPoolId",
    "REACT_APP_COGNITO_CLIENT_ID=$ClientId",
    "REACT_APP_API_ENDPOINT=$ApiEndpoint",
    "REACT_APP_COGNITO_REGION=$Region",
    "REACT_APP_DEBUG=false"
)
$envContent = $envLines -join "`n"
$envContent | Out-File -FilePath '.env' -Encoding UTF8 -Force
Write-Log "Frontend .env created" 'Success'

Write-Log "Note: Frontend build requires: npm install && npm run build" 'Warning'

Pop-Location

Write-Log "Setting up SNS email subscription..." 'Info'
if ($BookingTopicArn) {
    $topicArn = ($stackOutputs | Where-Object { $_.OutputKey -eq 'BookingTopicArn' } | Select-Object -ExpandProperty OutputValue)
    $email = 'lreddy1@evoketechnologies.com'

    & aws sns subscribe `
        --topic-arn $topicArn `
        --protocol email `
        --notification-endpoint $email `
        --endpoint-url $FlocaEndpoint 2>$null

    Write-Log "SNS subscription created for $email" 'Success'
}

Write-Header "DEPLOYMENT COMPLETE"
Write-Host "Stack Resources:" -ForegroundColor Green
if ($stackOutputs) {
    $stackOutputs | Format-Table -Property OutputKey, OutputValue -AutoSize
}

Write-Header "NEXT STEPS"
Write-Host "1. Start the frontend development server:"
Write-Host "   cd frontend"
Write-Host "   npm start"
Write-Host ""
Write-Host "2. Open browser to: http://localhost:3000"
Write-Host ""
Write-Host "3. Login with:"
Write-Host "   Email: demo@example.com"
Write-Host "   Password: Demo@123456"

Write-Log "Deployment completed successfully!" 'Success'
