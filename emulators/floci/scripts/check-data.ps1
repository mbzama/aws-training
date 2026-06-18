#Requires -Version 5.0

$FlocaEndpoint = 'http://localhost:4566'

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "============================================" -ForegroundColor Blue
}

$env:AWS_ACCESS_KEY_ID = 'test'
$env:AWS_SECRET_ACCESS_KEY = 'test'
$env:AWS_DEFAULT_REGION = 'us-east-1'
$env:AWS_ENDPOINT_URL = $FlocaEndpoint

# DYNAMODB
Write-Header "DYNAMODB - Events Table"
Write-Host ""
aws dynamodb scan --table-name Events --endpoint-url $FlocaEndpoint --output table

Write-Header "DYNAMODB - Bookings Table"
Write-Host ""
aws dynamodb scan --table-name Bookings --endpoint-url $FlocaEndpoint --output table

# S3
Write-Header "S3 - Tickets Bucket Contents"
Write-Host ""
aws s3 ls s3://event-tickets-000000000000 --recursive --endpoint-url $FlocaEndpoint

Write-Header "S3 - Frontend Bucket Contents"
Write-Host ""
aws s3 ls s3://event-booking-frontend-000000000000 --recursive --endpoint-url $FlocaEndpoint

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
