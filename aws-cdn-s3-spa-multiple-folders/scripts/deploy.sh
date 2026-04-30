#!/usr/bin/env bash
# deploy.sh — Build and deploy landing, users, and movies SPAs to S3
#
# Required env vars:
#   BUCKET_NAME        — S3 bucket name (e.g. my-spa-apps-bucket)
#   DISTRIBUTION_ID    — CloudFront distribution ID for cache invalidation
#
# Optional:
#   APPS               — space-separated list of apps to deploy
#                        (default: "landing users movies")
#
# Usage:
#   BUCKET_NAME=my-bucket DISTRIBUTION_ID=EXXXXX ./scripts/deploy.sh
#   BUCKET_NAME=my-bucket DISTRIBUTION_ID=EXXXXX APPS="users movies" ./scripts/deploy.sh

set -euo pipefail

BUCKET_NAME="${BUCKET_NAME:?BUCKET_NAME env var is required}"
DISTRIBUTION_ID="${DISTRIBUTION_ID:-}"
APPS="${APPS:-landing users movies}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Deploying to s3://${BUCKET_NAME}"
echo "==> Apps: ${APPS}"
echo ""

INVALIDATION_PATHS=()

for APP in $APPS; do
  APP_DIR="${REPO_ROOT}/${APP}"

  if [ ! -d "$APP_DIR" ]; then
    echo "[WARN] Directory ${APP_DIR} not found, skipping."
    continue
  fi

  echo "──────────────────────────────────────────"
  echo " Building: ${APP}"
  echo "──────────────────────────────────────────"
  cd "$APP_DIR"
  npm install --silent
  npm run build

  # Landing deploys to the bucket root; other apps deploy to their own prefix
  if [ "$APP" = "landing" ]; then
    S3_PREFIX=""
    echo " Uploading: landing → s3://${BUCKET_NAME}/ (root)"
  else
    S3_PREFIX="${APP}/"
    echo " Uploading: ${APP} → s3://${BUCKET_NAME}/${APP}/"
  fi

  # All assets with hashed filenames get long-term immutable caching
  aws s3 sync dist/ "s3://${BUCKET_NAME}/${S3_PREFIX}" \
    --delete \
    --cache-control "public,max-age=31536000,immutable" \
    --exclude "index.html" \
    --exclude "remoteEntry.js"

  # index.html — no caching so browsers always fetch the latest entry point
  aws s3 cp dist/index.html "s3://${BUCKET_NAME}/${S3_PREFIX}index.html" \
    --cache-control "no-cache,no-store,must-revalidate" \
    --content-type "text/html"

  # remoteEntry.js — short TTL so the host container picks up new versions quickly
  if [ -f dist/remoteEntry.js ]; then
    aws s3 cp dist/remoteEntry.js "s3://${BUCKET_NAME}/${S3_PREFIX}remoteEntry.js" \
      --cache-control "public,max-age=60" \
      --content-type "application/javascript"
  fi

  if [ "$APP" = "landing" ]; then
    INVALIDATION_PATHS+=("/index.html")
  else
    INVALIDATION_PATHS+=("/${APP}/*")
  fi

  echo " Done: ${APP}"
  echo ""
done

# Invalidate CloudFront so CDN edges serve the new files immediately
if [ -n "$DISTRIBUTION_ID" ] && [ ${#INVALIDATION_PATHS[@]} -gt 0 ]; then
  echo "──────────────────────────────────────────"
  echo " Invalidating CloudFront cache"
  echo " Distribution: ${DISTRIBUTION_ID}"
  echo " Paths: ${INVALIDATION_PATHS[*]}"
  echo "──────────────────────────────────────────"

  aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "${INVALIDATION_PATHS[@]}"

  echo " Cache invalidation submitted."
else
  echo "[INFO] Skipping cache invalidation (DISTRIBUTION_ID not set)."
fi

echo ""
echo "==> Deployment complete!"

if [ -n "$DISTRIBUTION_ID" ]; then
  CF_DOMAIN=$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" \
    --query 'Distribution.DomainName' --output text 2>/dev/null || echo "<cloudfront-domain>")
  echo ""
  echo " Landing:  https://${CF_DOMAIN}/"
  for APP in $APPS; do
    if [ "$APP" != "landing" ]; then
      echo " ${APP}:  https://${CF_DOMAIN}/${APP}"
    fi
  done
fi
