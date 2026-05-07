#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/terraform"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Preflight ─────────────────────────────────────────────────────────────────

if ! command -v terraform &>/dev/null; then
  error "terraform not found in PATH. Install it from https://developer.hashicorp.com/terraform/downloads"
  exit 1
fi

cd "$TF_DIR"

# ── Optionally destroy live AWS resources ─────────────────────────────────────

if [[ -f terraform.tfstate ]] && [[ -f terraform.tfvars ]]; then
  warn "Active state file detected. Destroy AWS resources before wiping state? [y/N]"
  read -r REPLY
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    info "Running terraform destroy..."
    terraform destroy -var-file=terraform.tfvars
    info "AWS resources destroyed."
  else
    warn "Skipping destroy — state files will be removed but AWS resources may still exist."
  fi
elif [[ -f terraform.tfstate ]] && [[ ! -f terraform.tfvars ]]; then
  warn "State file found but no terraform.tfvars — skipping destroy (no variables to run with)."
  warn "Remove AWS resources manually if they still exist."
fi

# ── Wipe local Terraform state and cache ─────────────────────────────────────

info "Removing Terraform state and cache..."

rm -f  terraform.tfstate
rm -f  terraform.tfstate.backup
rm -f  .terraform.lock.hcl
rm -rf .terraform

info "Cleanup complete. Directory is ready for a fresh 'terraform init'."
echo ""
echo "  Next step: run ./setup.sh"
