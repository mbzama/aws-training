#!/usr/bin/env bash
# =============================================================================
# destroy-infra.sh  —  Terraform destroy (tears down all managed resources)
#
# Usage:
#   ./scripts/destroy-infra.sh [OPTIONS]
#
# Options:
#   -s, --secret    JWT secret used at deploy time    [REQUIRED]
#   -f, --force     Skip confirmation prompt
#   -h, --help      Show this help
#
# Hardcoded values:
#   Region      : us-east-1
#   Environment : staging
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

# ── Defaults ──────────────────────────────────────────────────────────────────
JWT_SECRET="${TF_VAR_jwt_secret:-}"
FORCE=false

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()   { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
die()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }

usage() {
  sed -n '/^# Usage/,/^# ====/{ /^# ====/d; s/^# \{0,1\}//; p }' "$0"
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--secret) JWT_SECRET="$2"; shift 2 ;;
    -f|--force)  FORCE=true;      shift   ;;
    -h|--help)   usage ;;
    *) die "Unknown option: $1  (run with --help for usage)" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "${JWT_SECRET}" ]] && die "JWT secret is required. Use -s / --secret or set TF_VAR_jwt_secret."

command -v terraform &>/dev/null || die "'terraform' not found in PATH."

# ── Confirmation ──────────────────────────────────────────────────────────────
echo -e "\n${RED}${BOLD}=== WARNING: Terraform Destroy ===${RESET}"
warn "This will PERMANENTLY delete all infrastructure in environment 'staging' (region: us-east-1)."
warn "Resources deleted: S3 bucket, Lambda functions, API Gateway, IAM roles, CloudWatch log groups."

if ! ${FORCE}; then
  echo
  read -rp "Type 'staging' to confirm destruction: " CONFIRM
  [[ "${CONFIRM}" != "staging" ]] && die "Confirmation did not match. Aborting."
fi

# ── Main ──────────────────────────────────────────────────────────────────────
cd "${TF_DIR}"

log "Running terraform init ..."
terraform init -upgrade

log "Running terraform destroy ..."
terraform destroy \
  -auto-approve \
  -var="jwt_secret=${JWT_SECRET}"

ok "Destroy complete — all resources removed."
