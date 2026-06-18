#!/bin/bash
set -e

# Start Frontend - Run React development server
# This script starts the frontend dev server with hot reload

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

log_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Configuration
FRONTEND_PORT="${FRONTEND_PORT:-3000}"
FRONTEND_HOST="${FRONTEND_HOST:-localhost}"

# Main execution
log_header "FRONTEND START"

# Navigate to frontend directory
cd "$PROJECT_ROOT/frontend"
log_info "Working directory: $(pwd)"

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
  log_info "Dependencies not installed. Installing..."
  npm install || log_error "Failed to install dependencies"
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
  log_info "Creating .env file..."
  cat > .env << EOF
# Backend API endpoint (Flask server running on port 5000)
REACT_APP_API_ENDPOINT=http://localhost:5000
REACT_APP_DEBUG=false
EOF
  log_info "✓ .env file created"
fi

# Check port availability
log_info "Checking if port $FRONTEND_PORT is available..."
if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  log_error "Port $FRONTEND_PORT is already in use. Set FRONTEND_PORT=3001 npm start"
fi
log_info "✓ Port $FRONTEND_PORT is available"

# Start development server
log_header "STARTING REACT DEV SERVER"

echo "Frontend server starting on http://$FRONTEND_HOST:$FRONTEND_PORT"
echo ""
echo "Features:"
echo "  ✓ Hot Module Reload (HMR) - Changes auto-load"
echo "  ✓ Source maps - Easy debugging"
echo "  ✓ TypeScript/ESLint - Code quality"
echo ""
echo "Stop with: Ctrl+C"
echo ""
echo "Demo credentials:"
echo "  Email:    demo@example.com"
echo "  Password: Demo@123456"
echo ""
echo "Browser will open automatically..."
echo ""

# Start the development server
BROWSER=none npm start
