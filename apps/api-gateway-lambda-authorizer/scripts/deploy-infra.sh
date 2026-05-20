#!/usr/bin/env bash
# =============================================================================
# deploy-infra.sh  —  Terraform init → plan → apply
#
# Usage:
#   ./scripts/deploy-infra.sh [OPTIONS]
#
# Options:
#   -s, --secret    JWT HMAC secret (min 32 chars)    [REQUIRED]
#   -p, --plan-only Run terraform plan only, skip apply
#   -a, --auto      Skip interactive approval (terraform -auto-approve)
#   -h, --help      Show this help
#
# Environment variables (alternative to flags):
#   TF_VAR_jwt_secret — equivalent to -s
#
# Hardcoded values:
#   Region      : us-east-1
#   Environment : staging
#   S3 bucket   : api-bucket-demo-<random>  (created by Terraform)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform"

# ── Defaults ──────────────────────────────────────────────────────────────────
JWT_SECRET="${TF_VAR_jwt_secret:-}"
PLAN_ONLY=false
AUTO_APPROVE=false

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
    -s|--secret)    JWT_SECRET="$2"; shift 2 ;;
    -p|--plan-only) PLAN_ONLY=true;  shift   ;;
    -a|--auto)      AUTO_APPROVE=true; shift ;;
    -h|--help)      usage ;;
    *) die "Unknown option: $1  (run with --help for usage)" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
[[ -z "${JWT_SECRET}" ]] && die "JWT secret is required. Use -s / --secret or set TF_VAR_jwt_secret."
[[ ${#JWT_SECRET} -lt 32 ]] && warn "JWT secret is shorter than 32 characters — consider a longer value."

command -v terraform &>/dev/null || die "'terraform' not found in PATH."
command -v aws       &>/dev/null || die "'aws' not found in PATH."

# ── Main ──────────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}=== Lambda Authorizer — Infrastructure Deploy ===${RESET}"
log "Environment : staging"
log "Region      : us-east-1"
log "S3 bucket   : api-bucket-demo-<random>  (created by Terraform)"
log "Terraform   : $(terraform version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)["terraform_version"])' 2>/dev/null || terraform version | head -1)"
echo

cd "${TF_DIR}"

# ── terraform init ────────────────────────────────────────────────────────────
log "Running terraform init ..."
terraform init -upgrade
ok "Init complete."

# ── terraform plan ────────────────────────────────────────────────────────────
PLAN_FILE="/tmp/tfplan-staging"
log "Running terraform plan ..."
terraform plan \
  -var="jwt_secret=${JWT_SECRET}" \
  -out="${PLAN_FILE}"
ok "Plan saved to ${PLAN_FILE}"

if ${PLAN_ONLY}; then
  log "Plan-only mode — skipping apply."
  exit 0
fi

# ── terraform apply ───────────────────────────────────────────────────────────
APPLY_ARGS=()
${AUTO_APPROVE} && APPLY_ARGS+=("-auto-approve")

log "Running terraform apply ..."
terraform apply "${APPLY_ARGS[@]}" "${PLAN_FILE}"
ok "Apply complete."

# ── Show outputs ──────────────────────────────────────────────────────────────
echo
echo -e "${BOLD}=== Outputs ===${RESET}"
terraform output
