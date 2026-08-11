#!/usr/bin/env bash
# Upload a custom terminology file to the running AWS Translate service.
#
# Usage:
#   ./upload.sh                              # uses test/fixtures/exclude-list-v1.csv
#   ./upload.sh path/to/other-terminology.csv
set -euo pipefail

PORT="${PORT:-3000}"
BASE_URL="http://localhost:${PORT}"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
TERMINOLOGY_FILE="${1:-$APP_DIR/test/fixtures/exclude-list-v1.csv}"

log() { echo "[upload] $*"; }
die() { echo "[error] $*" >&2; exit 1; }

[[ -f "$TERMINOLOGY_FILE" ]] || die "Terminology file not found: $TERMINOLOGY_FILE"

log "Uploading custom terminology from ${TERMINOLOGY_FILE}..."
body=$(curl -s -w '\n%{http_code}' -X POST "${BASE_URL}/terminology" -F "file=@${TERMINOLOGY_FILE}")
status="${body##*$'\n'}"; content="${body%$'\n'*}"

if [[ "$status" == "201" ]]; then
  log "PASS: POST /terminology (HTTP ${status})"
  echo "$content"
else
  die "POST /terminology failed (HTTP ${status}): ${content}"
fi
