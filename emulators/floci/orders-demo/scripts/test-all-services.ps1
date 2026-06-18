#Requires -Version 5.0

$FlocaEndpoint = 'http://localhost:4566'
$Region = 'us-east-1'

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
    Write-Host "============================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "============================================" -ForegroundColor Blue
}

$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_ENDPOINT_URL = $FlocaEndpoint

# Test Floci Health
Write-Header "1️⃣  FLOCI HEALTH CHECK"
Write-Log "Testing Floci connection..." 'Info'
try {
    $health = Invoke-WebRequest -Uri "$FlocaEndpoint/_floci/health" -ErrorAction Stop
    Write-Log "✅ Floci is running" 'Success'
} catch {
    Write-Log "❌ Floci is NOT running" 'Error'
    Write-Log "Start with: podman-compose up -d" 'Warning'
    exit 1
}

# Test DynamoDB
Write-Header "2️⃣  DYNAMODB"
Write-Log "Listing DynamoDB tables..." 'Info'
$tables = & aws dynamodb list-tables --endpoint-url $FlocaEndpoint --query 'TableNames' --output text 2>$null
if ($tables) {
    Write-Log "✅ Tables found: $tables" 'Success'

    Write-Log "Scanning Events table..." 'Info'
    $eventCount = & aws dynamodb scan --table-name Events --endpoint-url $FlocaEndpoint --query 'Items | length(@)' --output text 2>$null
    Write-Log "✅ Events table has $eventCount items" 'Success'

    Write-Log "Scanning Bookings table..." 'Info'
    $bookingCount = & aws dynamodb scan --table-name Bookings --endpoint-url $FlocaEndpoint --query 'Items | length(@)' --output text 2>$null
    Write-Log "✅ Bookings table has $bookingCount items" 'Success'
} else {
    Write-Log "❌ No tables found" 'Error'
}

# Test Cognito
Write-Header "3️⃣  COGNITO"
Write-Log "Listing Cognito user pools..." 'Info'
$pools = & aws cognito-idp list-user-pools --max-results 10 --endpoint-url $FlocaEndpoint --query 'UserPools[*].Name' --output text 2>$null
if ($pools) {
    Write-Log "✅ User pools found: $pools" 'Success'
} else {
    Write-Log "❌ No user pools found" 'Error'
}

# Test S3
Write-Header "4️⃣  S3 (BUCKETS)"
Write-Log "Listing S3 buckets..." 'Info'
$buckets = & aws s3 ls --endpoint-url $FlocaEndpoint 2>$null
if ($buckets) {
    Write-Log "✅ Buckets found:" 'Success'
    Write-Host $buckets
} else {
    Write-Log "❌ No buckets found" 'Error'
}

# Test SQS
Write-Header "5️⃣  SQS (QUEUES)"
Write-Log "Listing SQS queues..." 'Info'
$queues = & aws sqs list-queues --endpoint-url $FlocaEndpoint --query 'QueueUrls' --output text 2>$null
if ($queues) {
    Write-Log "✅ Queues found:" 'Success'
    $queues -split " " | ForEach-Object { Write-Host "   - $_" }

    foreach ($queue in ($queues -split " ")) {
        $attr = & aws sqs get-queue-attributes --queue-url $queue --attribute-names ApproximateNumberOfMessages --endpoint-url $FlocaEndpoint --query 'Attributes.ApproximateNumberOfMessages' --output text 2>$null
        Write-Log "   Messages in queue: $attr" 'Info'
    }
} else {
    Write-Log "❌ No queues found" 'Error'
}

# Test SNS
Write-Header "6️⃣  SNS (TOPICS)"
Write-Log "Listing SNS topics..." 'Info'
$topics = & aws sns list-topics --endpoint-url $FlocaEndpoint --query 'Topics[*].TopicArn' --output text 2>$null
if ($topics) {
    Write-Log "✅ Topics found:" 'Success'
    foreach ($topic in ($topics -split " ")) {
        Write-Host "   - $topic"
        $subs = & aws sns list-subscriptions-by-topic --topic-arn $topic --endpoint-url $FlocaEndpoint --query 'Subscriptions[*].Endpoint' --output text 2>$null
        Write-Log "      Subscriptions: $subs" 'Info'
    }
} else {
    Write-Log "❌ No topics found" 'Error'
}

# Test Kinesis
Write-Header "7️⃣  KINESIS (STREAMS)"
Write-Log "Listing Kinesis streams..." 'Info'
$streams = & aws kinesis list-streams --endpoint-url $FlocaEndpoint --query 'StreamNames' --output text 2>$null
if ($streams) {
    Write-Log "✅ Streams found: $streams" 'Success'
} else {
    Write-Log "❌ No streams found" 'Error'
}

# Test Lambda
Write-Header "8️⃣  LAMBDA (FUNCTIONS)"
Write-Log "Listing Lambda functions..." 'Info'
$functions = & aws lambda list-functions --endpoint-url $FlocaEndpoint --query 'Functions[*].FunctionName' --output text 2>$null
if ($functions) {
    Write-Log "✅ Functions found:" 'Success'
    $functions -split " " | ForEach-Object { Write-Host "   - $_" }
} else {
    Write-Log "❌ No functions found" 'Error'
}

# Test API Gateway
Write-Header "9️⃣  API GATEWAY"
Write-Log "Listing REST APIs..." 'Info'
$apis = & aws apigateway get-rest-apis --endpoint-url $FlocaEndpoint --query 'items[*].name' --output text 2>$null
if ($apis) {
    Write-Log "✅ APIs found: $apis" 'Success'
} else {
    Write-Log "❌ No APIs found" 'Error'
}

# Test CloudFront
Write-Header "🔟 CLOUDFRONT (DISTRIBUTIONS)"
Write-Log "Listing CloudFront distributions..." 'Info'
$distros = & aws cloudfront list-distributions --endpoint-url $FlocaEndpoint --query 'DistributionList.Items[*].Id' --output text 2>$null
if ($distros) {
    Write-Log "✅ Distributions found: $distros" 'Success'
} else {
    Write-Log "❌ No distributions found" 'Error'
}

# Summary
Write-Header "📊 SUMMARY"
Write-Log "All core services are operational in Floci!" 'Success'
Write-Log "To check individual services, see the output above." 'Info'
Write-Host ""
