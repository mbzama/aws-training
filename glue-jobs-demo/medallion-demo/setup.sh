#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
section() { echo -e "\n${CYAN}──── $* ────${NC}"; }

# ── Preflight checks ──────────────────────────────────────────────────────────

section "Preflight"

if ! command -v terraform &>/dev/null; then
  error "terraform not found in PATH. Install it from https://developer.hashicorp.com/terraform/downloads"
  exit 1
fi
info "Terraform $(terraform version -json | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)"

if ! command -v aws &>/dev/null; then
  error "AWS CLI not found in PATH. Install it from https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html"
  exit 1
fi

if ! aws sts get-caller-identity &>/dev/null; then
  error "AWS credentials not configured or expired. Run: aws configure"
  exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
info "AWS account: $ACCOUNT_ID"

# ── Resolve bucket_suffix ─────────────────────────────────────────────────────

section "Configuration"

# Accept account ID as first argument; fall back to interactive prompt.
if [[ -n "${1:-}" ]]; then
  BUCKET_SUFFIX="$1"
  info "Using bucket suffix from argument: $BUCKET_SUFFIX"
else
  echo ""
  echo -n "  Enter bucket suffix (press Enter to use account ID [$ACCOUNT_ID]): "
  read -r INPUT
  BUCKET_SUFFIX="${INPUT:-$ACCOUNT_ID}"
fi

if [[ -z "$BUCKET_SUFFIX" ]]; then
  error "bucket_suffix cannot be empty."
  exit 1
fi
info "bucket_suffix = $BUCKET_SUFFIX"

# ── Write terraform.tfvars ────────────────────────────────────────────────────

cd "$TF_DIR"

if [[ ! -f terraform.tfvars ]]; then
  info "Creating terraform.tfvars from example template..."
  cp terraform.tfvars.example terraform.tfvars
fi

# Inject the resolved bucket_suffix (replaces any existing value or placeholder).
sed -i.bak "s/bucket_suffix *= *\"[^\"]*\"/bucket_suffix = \"$BUCKET_SUFFIX\"/" terraform.tfvars
rm -f terraform.tfvars.bak

info "terraform.tfvars ready (bucket_suffix = \"$BUCKET_SUFFIX\")."

# ── Init ──────────────────────────────────────────────────────────────────────

section "terraform init"
terraform init -upgrade

# ── Validate ──────────────────────────────────────────────────────────────────

section "terraform validate"
terraform validate
info "Configuration is valid."

# ── Plan ──────────────────────────────────────────────────────────────────────

section "terraform plan"
terraform plan -var-file=terraform.tfvars -out=tfplan

# ── Apply ─────────────────────────────────────────────────────────────────────

section "terraform apply"
echo ""
warn "Review the plan above. Apply to AWS account $ACCOUNT_ID? [y/N]"
read -r REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  info "Apply cancelled. The plan file (tfplan) is saved if you want to apply later:"
  echo "    cd terraform && terraform apply tfplan"
  exit 0
fi

terraform apply tfplan
rm -f tfplan

# ── Summary ───────────────────────────────────────────────────────────────────

section "Done"
echo ""
terraform output
echo ""
info "Setup complete. To run the full pipeline:"
WORKFLOW=$(terraform output -raw workflow_name 2>/dev/null || echo "medallion-demo-workflow")
REGION=$(terraform output -raw run_workflow_command 2>/dev/null | grep -o '\-\-region [^ ]*' | awk '{print $2}' || echo "us-east-1")
echo ""
echo "  aws glue start-workflow-run --name $WORKFLOW --region $REGION"
echo ""
