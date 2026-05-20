#!/bin/bash

# Setup script for Next.js S3 + CloudFront infrastructure
# This script initializes and creates all AWS infrastructure using Terraform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"
PROJECT_ROOT="$SCRIPT_DIR"

# Functions
print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}\n"
}

print_error() {
    echo -e "${RED}✗ $1${NC}\n"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}\n"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}\n"
}

print_step() {
    echo -e "${BLUE}→ $1${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Visit: https://www.terraform.io/downloads"
    fi
    print_success "Terraform installed: $(terraform version -json 2>/dev/null | jq -r '.terraform_version' || terraform --version | head -1)"

    # Check if aws cli is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Visit: https://aws.amazon.com/cli/"
    fi
    print_success "AWS CLI installed"

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run: aws configure"
    fi
    print_success "AWS credentials configured"

    # Show AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    IAM_USER=$(aws sts get-caller-identity --query Arn --output text)
    print_info "AWS Account: $ACCOUNT_ID"
    print_info "IAM User: $IAM_USER"
}

# Verify prerequisites
verify_aws_resources() {
    print_header "Verifying AWS Resources"

    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found. Run: cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
    fi
    print_success "terraform.tfvars found"

    # Using external DNS provider (GoDaddy, etc.)
    print_info "Using external DNS provider (GoDaddy, etc.)"
    print_info "CloudFront URL will be provided after infrastructure creation"
    print_info "You will need to create a CNAME record in your DNS provider"

    # Check for ACM certificate (optional - may be in different region or imported)
    print_step "Looking for ACM certificate..."
    CERT_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?Domain=='*.zamait.in' || Domain=='zamait.in'].CertificateArn" --output text | head -1)
    if [ -z "$CERT_ARN" ]; then
        print_warning "No ACM certificate found for *.zamait.in in us-east-1"
        print_info "If you have imported a certificate, Terraform will locate it automatically"
        print_info "If not found during Terraform apply, please create one and re-run this script"
    else
        CERT_STATUS=$(aws acm describe-certificate --certificate-arn "$CERT_ARN" --region us-east-1 --query 'Certificate.Status' --output text)
        print_success "ACM certificate found: $CERT_ARN"
        print_info "Certificate Status: $CERT_STATUS"
    fi
}

# Initialize Terraform
init_terraform() {
    print_header "Initializing Terraform"

    cd "$TERRAFORM_DIR"

    print_step "Running terraform init..."
    if terraform init; then
        print_success "Terraform initialized"
    else
        print_error "Terraform init failed"
    fi

    cd "$PROJECT_ROOT"
}

# Validate Terraform
validate_terraform() {
    print_header "Validating Terraform Configuration"

    cd "$TERRAFORM_DIR"

    print_step "Running terraform validate..."
    if terraform validate; then
        print_success "Terraform configuration valid"
    else
        print_error "Terraform validation failed"
    fi

    print_step "Running terraform fmt check..."
    if terraform fmt -check -recursive; then
        print_success "Terraform formatting correct"
    else
        print_warning "Terraform formatting issues found. Run: terraform fmt -recursive"
    fi

    cd "$PROJECT_ROOT"
}

# Show terraform plan
show_plan() {
    print_header "Terraform Plan"

    cd "$TERRAFORM_DIR"

    print_step "Generating terraform plan..."
    if terraform plan -out=tfplan; then
        print_success "Terraform plan generated"
        
        # Count resources
        RESOURCE_COUNT=$(terraform plan tfplan 2>/dev/null | grep -c "^aws_" || echo "multiple")
        print_info "Resources to create: $RESOURCE_COUNT"
    else
        print_error "Terraform plan failed"
    fi

    cd "$PROJECT_ROOT"
}

# Apply terraform
apply_terraform() {
    print_header "Deploying Infrastructure"

    cd "$TERRAFORM_DIR"

    print_step "Review the plan output above carefully!"
    print_info "Resources to be created:"
    print_info "  • S3 Bucket (private, encrypted, versioned)"
    print_info "  • CloudFront Distribution (global CDN)"
    print_info "  • Route53 DNS Records (A and AAAA)"
    print_info "  • CloudFront Cache Policies"
    print_info "  • CloudFront Functions (URL rewriting)"
    echo ""

    read -p "Do you want to apply these changes? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_warning "Infrastructure deployment cancelled"
        cd "$PROJECT_ROOT"
        return 1
    fi

    print_step "Applying terraform configuration..."
    if terraform apply tfplan; then
        print_success "Infrastructure deployed successfully!"
        
        # Show outputs
        print_header "Infrastructure Details"
        terraform output
        
    else
        print_error "Terraform apply failed"
    fi

    cd "$PROJECT_ROOT"
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Infrastructure"

    cd "$TERRAFORM_DIR"

    # Get outputs
    S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)
    APP_URL=$(terraform output -raw application_url 2>/dev/null)

    print_step "Verifying S3 bucket..."
    if aws s3 ls "s3://$S3_BUCKET" --region us-east-1 &> /dev/null; then
        print_success "S3 bucket created: $S3_BUCKET"
    else
        print_error "S3 bucket verification failed"
    fi

    print_step "Verifying CloudFront distribution..."
    DISTRIB_STATUS=$(aws cloudfront get-distribution --id "$CLOUDFRONT_ID" --query 'Distribution.Status' --output text 2>/dev/null)
    if [ -z "$DISTRIB_STATUS" ]; then
        print_error "CloudFront distribution not found"
    else
        print_success "CloudFront distribution created: $CLOUDFRONT_ID"
        print_info "Status: $DISTRIB_STATUS (may show 'InProgress' - will complete in 15-20 minutes)"
    fi

    print_step "DNS Configuration for GoDaddy..."
    CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null)
    print_info "CloudFront domain: $CLOUDFRONT_DOMAIN"
    print_info "Create CNAME record in GoDaddy:"
    print_info "  • Name: app-dev (or your subdomain)"
    print_info "  • Type: CNAME"
    print_info "  • Value: $CLOUDFRONT_DOMAIN"
    print_info "  • TTL: 3600 (or default)"

    cd "$PROJECT_ROOT"
}

# Show next steps
show_next_steps() {
    print_header "Setup Complete! ✓"

    echo -e "${CYAN}Next Steps:${NC}\n"

    echo "1. Wait for CloudFront deployment (15-20 minutes)"
    echo "   Check status: cd terraform && terraform output\n"

    echo "2. Create CNAME record in GoDaddy:"
    echo "   • Get CloudFront domain: cd terraform && terraform output cloudfront_domain_name"
    echo "   • Create CNAME: app-dev.zamait.in → [CloudFront domain above]"
    echo "   • Wait for DNS propagation (5-60 minutes)\n"

    echo "3. Build and deploy your Next.js application:"
    echo "   npm run build"
    echo "   ./deploy.sh\n"

    echo "4. Access your application:"
    echo "   https://app-dev.zamait.in\n"

    echo "Useful commands:"
    echo "  • make url              - Show application URL"
    echo "  • make outputs          - Show all infrastructure details"
    echo "  • ./deploy.sh           - Deploy application to S3"
    echo "  • make invalidate       - Clear CloudFront cache"
    echo "  • make destroy          - Delete all AWS resources (careful!)\n"

    echo -e "${CYAN}Documentation:${NC}"
    echo "  • QUICKSTART.md         - 5-minute guide"
    echo "  • ARCHITECTURE.md       - System design"
    echo "  • TROUBLESHOOTING.md    - Common issues & solutions\n"
}

# Main execution
main() {
    print_header "Next.js S3 + CloudFront Infrastructure Setup"
    echo -e "${CYAN}This script will create AWS infrastructure using Terraform${NC}\n"

    check_prerequisites
    verify_aws_resources
    init_terraform
    validate_terraform
    show_plan
    
    if apply_terraform; then
        verify_deployment
        show_next_steps
        exit 0
    else
        print_error "Setup failed"
    fi
}

# Run main function
main "$@"
