# Full Pipeline - Complete end-to-end deployment (PowerShell version for Windows)
# This script runs all stages to get from zero to running application

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR

# Colors
$GREEN = "`e[32m"
$RED = "`e[31m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$NC = "`e[0m"

function Log-Info($message) {
    Write-Host "${GREEN}[INFO]${NC} $message"
}

function Log-Error($message) {
    Write-Host "${RED}[ERROR]${NC} $message"
    exit 1
}

function Log-Header($message) {
    Write-Host ""
    Write-Host "${BLUE}========================================${NC}"
    Write-Host "${BLUE}$message${NC}"
    Write-Host "${BLUE}========================================${NC}"
    Write-Host ""
}

function Log-Stage($message) {
    Write-Host ""
    Write-Host "${BLUE}──────────────────────────────────────${NC}"
    Write-Host "${BLUE}Stage: $message${NC}"
    Write-Host "${BLUE}──────────────────────────────────────${NC}"
    Write-Host ""
}

function Run-Script($scriptPath, $scriptName) {
    if (-not (Test-Path $scriptPath)) {
        Log-Error "$scriptName not found at $scriptPath"
    }

    & bash $scriptPath
    if ($LASTEXITCODE -ne 0) {
        Log-Error "$scriptName failed"
    }
}

# Main execution
Log-Header "FLOCI FULL PIPELINE"

Write-Host "This script will run all stages to set up your application:"
Write-Host "  1. Setup Floci"
Write-Host "  2. Deploy Infrastructure"
Write-Host "  3. Seed Data"
Write-Host "  4. Build Frontend"
Write-Host "  5. Deploy Frontend"
Write-Host ""
Write-Host "Estimated time: 3-5 minutes"
Write-Host ""

# Stage 1: Setup Floci
Log-Stage "1. Setup Floci"
Run-Script "$SCRIPT_DIR\setup-floci.sh" "Floci setup"
Log-Info "✓ Floci setup complete"

# Stage 2: Deploy Infrastructure
Log-Stage "2. Deploy Infrastructure"
Run-Script "$SCRIPT_DIR\deploy-infrastructure.sh" "Infrastructure deployment"
Log-Info "✓ Infrastructure deployed"

# Source outputs for later stages
$ENV_FILE = "$PROJECT_ROOT\.env.floci"
if (Test-Path $ENV_FILE) {
    Get-Content $ENV_FILE | ForEach-Object {
        if ($_ -match '(.+?)=(.*)') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
        }
    }
}

# Stage 3: Seed Data
Log-Stage "3. Seed Data"
Run-Script "$SCRIPT_DIR\seed-data.sh" "Data seeding"
Log-Info "✓ Data seeded"

# Stage 4: Build Frontend
Log-Stage "4. Build Frontend"
Run-Script "$SCRIPT_DIR\build-frontend.sh" "Frontend build"
Log-Info "✓ Frontend built"

# Stage 5: Deploy Frontend
Log-Stage "5. Deploy Frontend"
Run-Script "$SCRIPT_DIR\deploy-frontend.sh" "Frontend deployment"
Log-Info "✓ Frontend deployed"

# Summary
Log-Header "PIPELINE COMPLETE"

Write-Host "All stages completed successfully!"
Write-Host ""
Write-Host "Your application is ready to use."
Write-Host ""
Write-Host "Access Information:"
Write-Host "  URL:      http://localhost:3000"
Write-Host "  Email:    demo@example.com"
Write-Host "  Password: Demo@123456"
Write-Host ""
Write-Host "What's running:"
Write-Host "  ✓ Floci (LocalStack) on port 4566"
Write-Host "  ✓ Cognito User Pool"
Write-Host "  ✓ API Gateway"
Write-Host "  ✓ 4 Lambda functions"
Write-Host "  ✓ DynamoDB (Bookings & Events tables)"
Write-Host "  ✓ S3 (Frontend & Tickets)"
Write-Host "  ✓ SQS/SNS (Async messaging)"
Write-Host ""
Write-Host "Next step:"
Write-Host "  bash $SCRIPT_DIR\start-frontend.sh"
Write-Host ""
Write-Host "Or in another terminal:"
Write-Host "  cd $PROJECT_ROOT\frontend"
Write-Host "  npm start"
Write-Host ""
Write-Host "To view Floci logs:"
Write-Host "  podman-compose logs -f floci"
Write-Host ""
Write-Host "To run tests:"
Write-Host "  bash $SCRIPT_DIR\test-apis.sh"
Write-Host ""
Write-Host "To cleanup:"
Write-Host "  bash $SCRIPT_DIR\cleanup.sh"
Write-Host ""

Log-Info "Full pipeline complete! Ready to start frontend development server."
