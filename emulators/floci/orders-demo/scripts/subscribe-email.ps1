#Requires -Version 5.0
param(
    [string]$Email = 'lreddy1@evoketechnologies.com',
    [string]$Region = 'us-east-1'
)

$FlocaEndpoint = 'http://localhost:4566'

function Write-Log {
    param([string]$Message, [string]$Level = 'Info')
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colors = @{'Info'='Green'; 'Error'='Red'; 'Success'='Cyan'; 'Warning'='Yellow'}
    Write-Host "[$timestamp] [$Level]" -ForegroundColor $colors[$Level] -NoNewline
    Write-Host " $Message"
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Blue
Write-Host "SNS Email Subscription Setup" -ForegroundColor Blue
Write-Host "==========================================" -ForegroundColor Blue
Write-Host ""

$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_ENDPOINT_URL = $FlocaEndpoint

Write-Log "Getting SNS topic ARN..." 'Info'
$topicArn = & aws sns list-topics --endpoint-url $FlocaEndpoint --query "Topics[?contains(TopicArn, 'BookingNotifications')].TopicArn" --output text 2>$null

if (-not $topicArn) {
    Write-Log "Topic ARN not found. Stack may not be deployed." 'Error'
    exit 1
}

Write-Log "Topic ARN: $topicArn" 'Success'

Write-Log "Subscribing $Email to topic..." 'Info'
$result = & aws sns subscribe `
    --topic-arn $topicArn `
    --protocol email `
    --notification-endpoint $Email `
    --endpoint-url $FlocaEndpoint 2>&1

Write-Log "Subscription created" 'Success'
Write-Host ""
Write-Host "⚠️  Important: Check your email at $Email for a subscription confirmation" -ForegroundColor Yellow
Write-Host "   You must confirm the subscription to receive booking notifications" -ForegroundColor Yellow
Write-Host ""
