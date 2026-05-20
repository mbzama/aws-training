#!/usr/bin/env bash
# =============================================================================
# deploy-lambda.sh  —  Deploy Lambda code changes via Helm
#
# Runs `helm upgrade --install` which triggers the post-upgrade Job that
# zips source code, uploads to S3, and calls lambda:UpdateFunctionCode.
#
# Usage:
#   ./scripts/deploy-lambda.sh [OPTIONS]
#
# Options:
#   -n, --namespace        Kubernetes namespace         (default: default)
#   -R, --release          Helm release name            (default: lambda-deploy)
#   -p, --project          Project prefix in fn names   (default: lambda-authorizer)
#      --irsa-role         IRSA IAM role ARN (eks.amazonaws.com/role-arn annotation)
#      --dry-run           Helm dry-run (template rendering only, no cluster apply)
#      --skip-authorizer   Skip deploying the authorizer Lambda
#      --skip-backend      Skip deploying the backend Lambda
#   -h, --help             Show this help
#
# Hardcoded values:
#   Region      : us-east-1
#   Environment : staging
#   S3 bucket   : read from `terraform output -raw bucket_name`
#
# Environment variables (alternative to flags):
#   HELM_NAMESPACE, IRSA_ROLE_ARN
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${REPO_ROOT}/helm/lambda-authorizer"
TF_DIR="${REPO_ROOT}/terraform"

# ── Hardcoded ─────────────────────────────────────────────────────────────────
REGION="us-east-1"
ENV="staging"

# ── Defaults ──────────────────────────────────────────────────────────────────
NAMESPACE="${HELM_NAMESPACE:-default}"
RELEASE="${HELM_RELEASE:-lambda-deploy}"
PROJECT="${PROJECT_NAME:-lambda-authorizer}"
IRSA_ROLE="${IRSA_ROLE_ARN:-}"
DRY_RUN=false
SKIP_AUTHORIZER=false
SKIP_BACKEND=false

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
    -n|--namespace)       NAMESPACE="$2"; shift 2 ;;
    -R|--release)         RELEASE="$2";   shift 2 ;;
    -p|--project)         PROJECT="$2";   shift 2 ;;
       --irsa-role)       IRSA_ROLE="$2"; shift 2 ;;
       --dry-run)         DRY_RUN=true;   shift   ;;
       --skip-authorizer) SKIP_AUTHORIZER=true; shift ;;
       --skip-backend)    SKIP_BACKEND=true;    shift ;;
    -h|--help)            usage ;;
    *) die "Unknown option: $1  (run with --help for usage)" ;;
  esac
done

# ── Validation ────────────────────────────────────────────────────────────────
command -v helm      &>/dev/null || die "'helm' not found in PATH."
command -v kubectl   &>/dev/null || die "'kubectl' not found in PATH. Needed to stream Job logs."
command -v terraform &>/dev/null || die "'terraform' not found in PATH. Needed to read bucket name."

[[ -d "${CHART_DIR}" ]] || die "Helm chart not found at ${CHART_DIR}"
[[ -d "${TF_DIR}" ]]    || die "Terraform directory not found at ${TF_DIR}"

# ── Read bucket name from Terraform state ─────────────────────────────────────
log "Reading S3 bucket name from terraform output ..."
S3_BUCKET=$(cd "${TF_DIR}" && terraform output -raw bucket_name 2>/dev/null) \
  || die "Could not read 'bucket_name' from Terraform output. Run deploy-infra.sh first."

[[ -z "${S3_BUCKET}" ]] && die "Terraform output 'bucket_name' is empty. Run deploy-infra.sh first."
ok "Bucket: ${S3_BUCKET}"

# ── Derived values ────────────────────────────────────────────────────────────
AUTHORIZER_FN="${PROJECT}-${ENV}-authorizer"
BACKEND_FN="${PROJECT}-${ENV}-backend"

# ── Build helm set args ───────────────────────────────────────────────────────
HELM_ARGS=(
  upgrade --install "${RELEASE}" "${CHART_DIR}"
  --namespace "${NAMESPACE}"
  --create-namespace
  --set "awsRegion=${REGION}"
  --set "s3.bucket=${S3_BUCKET}"
  --set "functions.authorizer.functionName=${AUTHORIZER_FN}"
  --set "functions.authorizer.enabled=$(${SKIP_AUTHORIZER} && echo false || echo true)"
  --set "functions.backend.functionName=${BACKEND_FN}"
  --set "functions.backend.enabled=$(${SKIP_BACKEND} && echo false || echo true)"
)

if [[ -n "${IRSA_ROLE}" ]]; then
  HELM_ARGS+=(--set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${IRSA_ROLE}")
fi

if ${DRY_RUN}; then
  HELM_ARGS+=(--dry-run)
fi

# ── Print plan ────────────────────────────────────────────────────────────────
echo -e "\n${BOLD}=== Lambda Authorizer — Code Deploy ===${RESET}"
log "Environment      : ${ENV}"
log "Region           : ${REGION}"
log "S3 bucket        : ${S3_BUCKET}"
log "Namespace        : ${NAMESPACE}"
log "Helm release     : ${RELEASE}"
log "Authorizer fn    : ${AUTHORIZER_FN}  (enabled: $(${SKIP_AUTHORIZER} && echo no || echo yes))"
log "Backend fn       : ${BACKEND_FN}  (enabled: $(${SKIP_BACKEND} && echo no || echo yes))"
[[ -n "${IRSA_ROLE}" ]] && log "IRSA role        : ${IRSA_ROLE}"
${DRY_RUN} && warn "DRY-RUN mode — no changes will be applied to the cluster."
echo

# ── Run helm upgrade ──────────────────────────────────────────────────────────
log "Running helm upgrade ..."
helm "${HELM_ARGS[@]}"

if ${DRY_RUN}; then
  ok "Dry-run complete."
  exit 0
fi

ok "Helm upgrade complete — Job queued."

# ── Tail Job logs ─────────────────────────────────────────────────────────────
log "Waiting for the deploy Job to start ..."

JOB_LABEL="app.kubernetes.io/instance=${RELEASE},app.kubernetes.io/component=deployer"
TIMEOUT=120

ELAPSED=0
POD=""
while [[ -z "${POD}" && ${ELAPSED} -lt ${TIMEOUT} ]]; do
  POD=$(kubectl get pods -n "${NAMESPACE}" \
    -l "${JOB_LABEL}" \
    --sort-by=.metadata.creationTimestamp \
    -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)
  [[ -z "${POD}" ]] && { sleep 3; ELAPSED=$((ELAPSED + 3)); }
done

if [[ -z "${POD}" ]]; then
  warn "Deploy pod did not appear within ${TIMEOUT}s. Check manually:"
  warn "  kubectl get jobs -n ${NAMESPACE} -l ${JOB_LABEL}"
  exit 1
fi

log "Streaming logs from pod: ${POD}"
echo "──────────────────────────────────────────"
kubectl logs -n "${NAMESPACE}" "${POD}" --follow || true
echo "──────────────────────────────────────────"

# ── Check Job exit status ─────────────────────────────────────────────────────
EXIT_CODE=$(kubectl get pod -n "${NAMESPACE}" "${POD}" \
  -o jsonpath='{.status.containerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo "unknown")

if [[ "${EXIT_CODE}" == "0" ]]; then
  ok "Lambda deploy Job succeeded."
else
  die "Lambda deploy Job exited with code: ${EXIT_CODE}. Check logs above."
fi
