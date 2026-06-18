#Requires -Version 5.0

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
Write-Host "SNS Messages Checker" -ForegroundColor Blue
Write-Host "==========================================" -ForegroundColor Blue
Write-Host ""

$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_ENDPOINT_URL = $FlocaEndpoint

Write-Log "Listing SNS topics..." 'Info'
$topics = & aws sns list-topics --endpoint-url $FlocaEndpoint --query 'Topics[*].TopicArn' --output text 2>$null

if ($topics) {
    Write-Log "Found topics: $topics" 'Success'

    foreach ($topic in $topics.Split()) {
        Write-Host ""
        Write-Log "Topic: $topic" 'Info'

        Write-Log "Listing subscriptions..." 'Info'
        & aws sns list-subscriptions-by-topic --topic-arn $topic --endpoint-url $FlocaEndpoint --query 'Subscriptions[*].[Endpoint,SubscriptionArn]' --output table 2>$null
    }
} else {
    Write-Log "No SNS topics found" 'Warning'
}

Write-Host ""
Write-Log "Note: Floci doesn't send real emails. But SNS messages are being published to the topic." 'Info'
Write-Log "To verify: Check if the booking was stored in DynamoDB and SNS message was queued." 'Info'

Write-Host ""
Write-Log "Checking Bookings in DynamoDB..." 'Info'
& aws dynamodb scan --table-name Bookings --endpoint-url $FlocaEndpoint --query 'Items[*]' --output table 2>$null

Write-Host ""
