# Event Booking Platform Setup Script (Windows PowerShell)

Write-Host "🚀 Starting Event Booking Platform Setup..." -ForegroundColor Green

# Get the root project directory
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "📍 Working directory: $projectRoot" -ForegroundColor Gray

# Step 1: Start Floci
Write-Host "📦 Starting Floci..." -ForegroundColor Cyan
podman-compose up -d
Write-Host "⏳ Waiting for Floci to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 2: Deploy infrastructure
Write-Host "🏗️ Deploying infrastructure with Terraform..." -ForegroundColor Cyan
$terraformDir = Join-Path $projectRoot "terraform"
Set-Location $terraformDir
terraform init
terraform apply -auto-approve

# Step 3: Get Terraform outputs and update frontend .env
Write-Host "📝 Updating frontend .env with Terraform outputs..." -ForegroundColor Cyan
try {
    $userPoolId = & terraform output -raw user_pool_id 2>$null
    $clientId = & terraform output -raw user_pool_client_id 2>$null
} catch {
    Write-Host "⚠️ Could not retrieve Terraform outputs, using placeholders" -ForegroundColor Yellow
    $userPoolId = "us-east-1_XXXXXXXXX"
    $clientId = "xxxxxxxxxxxxxxxxxxxxx"
}

$frontendDir = Join-Path $projectRoot "frontend"
$envPath = Join-Path $frontendDir ".env"

$envContent = @"
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_COGNITO_REGION=us-east-1
REACT_APP_COGNITO_USER_POOL_ID=$userPoolId
REACT_APP_COGNITO_CLIENT_ID=$clientId
"@

$envContent | Out-File -FilePath $envPath -Encoding utf8 -Force
Write-Host "✅ Frontend .env updated at: $envPath" -ForegroundColor Green
Write-Host ""
Get-Content $envPath

# Step 4: Seed events
Write-Host ""
Write-Host "🌱 Seeding DynamoDB with events..." -ForegroundColor Cyan
Set-Location $projectRoot
python seed_events.py

Write-Host ""
Write-Host "✅ Setup complete! Now run these in separate terminals:" -ForegroundColor Green
Write-Host ""
Write-Host "Terminal 2 (from $projectRoot):" -ForegroundColor Yellow
Write-Host "  python app.py" -ForegroundColor Cyan
Write-Host ""
Write-Host "Terminal 3 (from $projectRoot):" -ForegroundColor Yellow
Write-Host "  python worker.py" -ForegroundColor Cyan
Write-Host ""
Write-Host "Terminal 4 (from $projectRoot):" -ForegroundColor Yellow
Write-Host "  cd frontend && npm install && npm start" -ForegroundColor Cyan
Write-Host ""
