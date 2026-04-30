#!/bin/bash

# Deploy script for Next.js application to S3 + CloudFront
# This script builds the Next.js app and uploads changes to S3, then invalidates CloudFront cache

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
BUILD_DIR="$PROJECT_ROOT/out"
SOURCE_DIR="${1:-.}"  # Optional: specify different source directory

# Progress counter
TOTAL_STEPS=5
CURRENT_STEP=0

# Functions
increment_step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
}

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}[$CURRENT_STEP/$TOTAL_STEPS] $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}\n"
}

print_error() {
    echo -e "${RED}✗ $1${NC}\n"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}\n"
}

print_step() {
    echo -e "${MAGENTA}→ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    increment_step
    print_header "Checking Prerequisites"

    # Check if aws cli is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI installed"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    print_success "AWS credentials configured"

    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform not found in PATH (will try to get outputs anyway)"
    fi
}

# Build Next.js application
build_nextjs() {
    increment_step
    print_header "Building Next.js Application"

    cd "$PROJECT_ROOT"

    # Check if out directory exists (skip build if --skip-build flag)
    if [ "$1" = "--skip-build" ]; then
        print_info "Skipping build (--skip-build flag)"
        if [ ! -d "$BUILD_DIR" ]; then
            print_error "Build directory not found: $BUILD_DIR"
        fi
        print_success "Using existing build at $BUILD_DIR"
        return
    fi

    # Install dependencies if needed
    if [ ! -d "$PROJECT_ROOT/node_modules" ]; then
        print_step "Installing dependencies..."
        npm install
        print_success "Dependencies installed"
    fi

    # Build the application
    print_step "Building Next.js application..."
    npm run build
    
    if [ ! -d "$BUILD_DIR" ]; then
        print_error "Build output directory not found at $BUILD_DIR"
    fi

    FILE_COUNT=$(find "$BUILD_DIR" -type f | wc -l)
    BUILD_SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    print_success "Next.js application built successfully"
    print_info "Files: $FILE_COUNT | Size: $BUILD_SIZE"
}

# Get Terraform outputs
get_terraform_outputs() {
    increment_step
    print_header "Retrieving Infrastructure Details"

    cd "$TERRAFORM_DIR"

    print_step "Getting S3 bucket name..."
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
    if [ -z "$S3_BUCKET" ]; then
        print_error "Could not retrieve S3 bucket name. Run: setup.sh"
    fi
    print_success "S3 Bucket: $S3_BUCKET"

    print_step "Getting CloudFront distribution ID..."
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)
    if [ -z "$CLOUDFRONT_ID" ]; then
        print_error "Could not retrieve CloudFront distribution ID. Run: setup.sh"
    fi
    print_success "CloudFront Distribution: $CLOUDFRONT_ID"

    AWS_REGION="us-east-1"
    print_success "AWS Region: $AWS_REGION"
}

# Upload to S3 with intelligent caching
upload_to_s3() {
    increment_step
    print_header "Uploading to S3"

    cd "$PROJECT_ROOT"

    print_info "Target bucket: s3://$S3_BUCKET"
    
    # Function to upload files with cache header
    upload_with_cache() {
        local pattern=$1
        local cache_control=$2
        local content_type=$3
        local description=$4
        
        print_step "$description..."
        
        local file_count=0
        while IFS= read -r file; do
            if [ -z "$file" ]; then
                continue
            fi
            
            relative_path="${file#$BUILD_DIR/}"
            
            # Skip if empty
            if [ -z "$relative_path" ]; then
                continue
            fi
            
            if [ -n "$content_type" ]; then
                aws s3 cp "$file" "s3://$S3_BUCKET/$relative_path" \
                    --cache-control "$cache_control" \
                    --content-type "$content_type" \
                    --region "$AWS_REGION" \
                    --no-progress 2>/dev/null || true
            else
                aws s3 cp "$file" "s3://$S3_BUCKET/$relative_path" \
                    --cache-control "$cache_control" \
                    --region "$AWS_REGION" \
                    --no-progress 2>/dev/null || true
            fi
            
            file_count=$((file_count + 1))
        done <<< "$(find "$BUILD_DIR" -name "$pattern" -type f 2>/dev/null)"
        
        if [ $file_count -gt 0 ]; then
            echo "   Uploaded $file_count files"
        fi
    }

    print_info "Uploading with intelligent cache headers...\n"

    # HTML files - short cache (user-facing content)
    upload_with_cache "*.html" "public, max-age=3600, must-revalidate" "text/html" "1. HTML files (1 hour cache)"

    # JavaScript files in _next - long cache (immutable)
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi
        relative_path="${file#$BUILD_DIR/}"
        aws s3 cp "$file" "s3://$S3_BUCKET/$relative_path" \
            --cache-control "public, max-age=31536000, immutable" \
            --content-type "application/javascript" \
            --region "$AWS_REGION" \
            --no-progress 2>/dev/null || true
    done <<< "$(find "$BUILD_DIR/_next" -name "*.js" -type f 2>/dev/null)"
    echo "   Uploaded JavaScript files"

    # CSS files - long cache (immutable)
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi
        relative_path="${file#$BUILD_DIR/}"
        aws s3 cp "$file" "s3://$S3_BUCKET/$relative_path" \
            --cache-control "public, max-age=31536000, immutable" \
            --content-type "text/css" \
            --region "$AWS_REGION" \
            --no-progress 2>/dev/null || true
    done <<< "$(find "$BUILD_DIR/_next" -name "*.css" -type f 2>/dev/null)"
    echo "   Uploaded CSS files"

    # Font files - long cache
    while IFS= read -r file; do
        if [ -z "$file" ]; then
            continue
        fi
        relative_path="${file#$BUILD_DIR/}"
        
        if [[ $file == *.woff2 ]]; then
            content_type="font/woff2"
        elif [[ $file == *.woff ]]; then
            content_type="font/woff"
        else
            content_type="application/octet-stream"
        fi
        
        aws s3 cp "$file" "s3://$S3_BUCKET/$relative_path" \
            --cache-control "public, max-age=31536000, immutable" \
            --content-type "$content_type" \
            --region "$AWS_REGION" \
            --no-progress 2>/dev/null || true
    done <<< "$(find "$BUILD_DIR/_next" -name "*.woff*" -type f 2>/dev/null)"
    echo "   Uploaded font files"

    # Images and other assets - 24 hour cache
    upload_with_cache "*.jpg" "public, max-age=86400" "image/jpeg" "2. Images (24 hour cache)"
    upload_with_cache "*.jpeg" "public, max-age=86400" "image/jpeg" ""
    upload_with_cache "*.png" "public, max-age=86400" "image/png" ""
    upload_with_cache "*.gif" "public, max-age=86400" "image/gif" ""
    upload_with_cache "*.svg" "public, max-age=86400" "image/svg+xml" ""
    upload_with_cache "*.webp" "public, max-age=86400" "image/webp" ""
    upload_with_cache "*.json" "public, max-age=86400" "application/json" ""

    print_success "All files uploaded to S3"
}

# Invalidate CloudFront cache
invalidate_cloudfront() {
    increment_step
    print_header "Invalidating CloudFront Cache"

    print_info "Creating invalidation for distribution: $CLOUDFRONT_ID"

    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_ID" \
        --paths "/*" \
        --region "$AWS_REGION" \
        --query 'Invalidation.Id' \
        --output text)

    if [ -z "$INVALIDATION_ID" ]; then
        print_error "Failed to create CloudFront invalidation"
    fi

    print_success "Invalidation created: $INVALIDATION_ID"
    print_step "Waiting for invalidation to complete..."

    # Wait for invalidation (up to 5 minutes)
    for i in {1..30}; do
        STATUS=$(aws cloudfront get-invalidation \
            --distribution-id "$CLOUDFRONT_ID" \
            --id "$INVALIDATION_ID" \
            --region "$AWS_REGION" \
            --query 'Invalidation.Status' \
            --output text 2>/dev/null)

        if [ "$STATUS" = "Completed" ]; then
            print_success "Invalidation completed"
            return 0
        fi

        echo -ne "   Status: $STATUS (${i}0 seconds)...\r"
        sleep 10
    done

    print_warning "Invalidation still in progress (will complete in background)"
}

# Display deployment summary
display_summary() {
    increment_step
    print_header "Deployment Complete! ✓"

    # Get app URL
    APP_URL="https://app-dev.zamait.in"
    
    # Try to get real URL from terraform
    if command -v terraform &> /dev/null 2>/dev/null; then
        TERRAFORM_URL=$(cd "$TERRAFORM_DIR" && terraform output -raw application_url 2>/dev/null)
        if [ -n "$TERRAFORM_URL" ]; then
            APP_URL="$TERRAFORM_URL"
        fi
    fi

    echo -e "${CYAN}Deployment Details:${NC}\n"

    echo "Application URL:"
    echo -e "  ${GREEN}$APP_URL${NC}\n"

    echo "Infrastructure:"
    echo -e "  S3 Bucket: ${MAGENTA}$S3_BUCKET${NC}"
    echo -e "  CloudFront: ${MAGENTA}$CLOUDFRONT_ID${NC}\n"

    echo "Next steps:"
    echo "  1. Wait 1-2 minutes for cache invalidation to fully propagate"
    echo "  2. Open: $APP_URL"
    echo "  3. Verify all assets load correctly"
    echo "  4. Clear browser cache if needed (Ctrl+Shift+Delete)\n"

    echo "Useful commands:"
    echo "  • ./deploy.sh --skip-build   - Deploy without rebuilding"
    echo "  • make invalidate            - Manually invalidate cache"
    echo "  • make url                   - Show application URL"
    echo -e "  • make outputs               - Show infrastructure details\n"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy Next.js application to S3 + CloudFront"
    echo ""
    echo "Options:"
    echo "  (no args)         Build and deploy (default)"
    echo "  --skip-build      Deploy existing build without rebuilding"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh                    # Build and deploy"
    echo "  ./deploy.sh --skip-build       # Deploy existing build"
}

# Main execution
main() {
    # Parse arguments
    case "${1:-}" in
        --help)
            show_usage
            exit 0
            ;;
        --skip-build)
            SKIP_BUILD=true
            ;;
        *)
            SKIP_BUILD=false
            ;;
    esac

    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Next.js Application Deployment to S3 + CloudFront        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}\n"

    check_prerequisites
    
    if [ "$SKIP_BUILD" = true ]; then
        build_nextjs --skip-build
    else
        build_nextjs
    fi
    
    get_terraform_outputs
    upload_to_s3
    invalidate_cloudfront
    display_summary

    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Deployment succeeded! 🚀${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}\n"

    exit 0
}

# Handle errors
trap 'print_error "Deployment failed at line $LINENO"; exit 1' ERR

# Run main function
main "$@"
