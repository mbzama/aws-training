#!/usr/bin/env bash
set -euo pipefail

# ── Config (override via env vars) ────────────────────────────────────────────
RELEASE_NAME="${RELEASE_NAME:-aws-secrets-app}"
NAMESPACE="${NAMESPACE:-default}"
IMAGE_REPO="${IMAGE_REPO:-nextjs-web}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-app_web}"
IRSA_ROLE_ARN="${IRSA_ROLE_ARN:-}"           # recommended for EKS
REGISTRY="${REGISTRY:-}"                      # e.g. 123456789.dkr.ecr.us-east-1.amazonaws.com

CHART_DIR="$(cd "$(dirname "$0")/helm/aws-secrets-app" && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[deploy] $*"; }
die() { echo "[error]  $*" >&2; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "'$cmd' not found — please install it."
  done
}

# ── Preflight ─────────────────────────────────────────────────────────────────
require docker kubectl helm

log "Building Docker image ${IMAGE_REPO}:${IMAGE_TAG}..."
docker build -t "${IMAGE_REPO}:${IMAGE_TAG}" "$(dirname "$0")"

# Push to registry if one is specified
if [[ -n "$REGISTRY" ]]; then
  FULL_IMAGE="${REGISTRY}/${IMAGE_REPO}:${IMAGE_TAG}"
  log "Tagging and pushing to ${FULL_IMAGE}..."
  docker tag "${IMAGE_REPO}:${IMAGE_TAG}" "$FULL_IMAGE"
  docker push "$FULL_IMAGE"
  IMAGE_REPO="$FULL_IMAGE"
  IMAGE_TAG="" # already included in FULL_IMAGE — override tag to avoid duplication
fi

# ── Namespace ─────────────────────────────────────────────────────────────────
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  log "Creating namespace '$NAMESPACE'..."
  kubectl create namespace "$NAMESPACE"
fi

# ── Helm values ───────────────────────────────────────────────────────────────
HELM_ARGS=(
  upgrade --install "$RELEASE_NAME" "$CHART_DIR"
  --namespace "$NAMESPACE"
  --set "image.repository=${IMAGE_REPO}"
  --set "image.tag=${IMAGE_TAG:-latest}"
  --set "aws.region=${AWS_REGION}"
  --set "aws.secretName=${SECRET_NAME}"
)

# IRSA (production — no credentials needed in the chart)
if [[ -n "$IRSA_ROLE_ARN" ]]; then
  log "Using IRSA role: ${IRSA_ROLE_ARN}"
  HELM_ARGS+=(--set "aws.irsaRoleArn=${IRSA_ROLE_ARN}")

# Explicit credentials fallback (dev/local only)
elif [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  log "WARNING: Using explicit AWS credentials (not recommended for production)."
  HELM_ARGS+=(
    --set "awsCredentials.accessKeyId=${AWS_ACCESS_KEY_ID}"
    --set "awsCredentials.secretAccessKey=${AWS_SECRET_ACCESS_KEY}"
  )
  if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
    HELM_ARGS+=(--set "awsCredentials.sessionToken=${AWS_SESSION_TOKEN}")
  fi

else
  die "No AWS credentials found. Set IRSA_ROLE_ARN (EKS) or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY."
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
log "Running: helm ${HELM_ARGS[*]}"
helm "${HELM_ARGS[@]}"

log "Waiting for deployment to be ready..."
kubectl rollout status deployment/"${RELEASE_NAME}-aws-secrets-app" \
  --namespace "$NAMESPACE" \
  --timeout=120s

log "Done. Pods:"
kubectl get pods --namespace "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE_NAME}"
