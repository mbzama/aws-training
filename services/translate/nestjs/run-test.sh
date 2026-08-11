#!/usr/bin/env bash
# Build, start, and smoke test the AWS Translate NestJS service.
#
# Usage:
#   ./run.sh                          # start + run smoke tests (no terminology upload)
#   ./run.sh path/to/exclude-list-v1.csv   # also upload/read the custom terminology
set -euo pipefail

# ── Config (override via env vars) ────────────────────────────────────────────
PORT="${PORT:-3000}"
BASE_URL="http://localhost:${PORT}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-30}"
TERMINOLOGY_FILE="${1:-}"

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$(mktemp -t nestjs-translate-XXXXXX.log)"
SERVER_PID=""

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[run] $*"; }
die() { echo "[error] $*" >&2; exit 1; }

require() {
  for cmd in "$@"; do
    command -v "$cmd" &>/dev/null || die "'$cmd' not found — please install it."
  done
}

# ── Preflight ─────────────────────────────────────────────────────────────────
require node npm curl
cd "$APP_DIR"

[[ -f .env ]] || log "WARNING: no .env found — copy .env.example to .env if you need custom config."

if [[ ! -d node_modules ]]; then
  log "Installing dependencies..."
  npm install
fi

log "Building..."
npm run build

# ── Start server ──────────────────────────────────────────────────────────────
log "Starting server on port ${PORT} (logs: ${LOG_FILE})..."
PORT="$PORT" node dist/main.js >"$LOG_FILE" 2>&1 &
SERVER_PID=$!

log "Waiting for server to become ready..."
ready=false
for ((i = 0; i < STARTUP_TIMEOUT; i++)); do
  if curl -sf "${BASE_URL}/" -o /dev/null; then
    ready=true
    break
  fi
  #kill -0 "$SERVER_PID" &>/dev/null || die "Server exited early. Log:\n$(cat "$LOG_FILE")"
  sleep 1
done
[[ "$ready" == true ]] || die "Server did not become ready within ${STARTUP_TIMEOUT}s. Log:\n$(cat "$LOG_FILE")"
log "Server is up."

# ── Smoke tests ───────────────────────────────────────────────────────────────
pass=0
fail=0

check() {
  local description="$1" expected_status="$2" actual_status="$3" body="$4"
  if [[ "$actual_status" == "$expected_status" ]]; then
    log "PASS: ${description} (HTTP ${actual_status})"
    pass=$((pass + 1))
  else
    log "FAIL: ${description} (expected HTTP ${expected_status}, got ${actual_status}) — ${body}"
    fail=$((fail + 1))
  fi
}

# 1. Root
body=$(curl -s -w '\n%{http_code}' "${BASE_URL}/")
status="${body##*$'\n'}"; content="${body%$'\n'*}"
check "GET /" "200" "$status" "$content"

# 2. Swagger docs
status=$(curl -s -o /dev/null -w '%{http_code}' "${BASE_URL}/api")
check "GET /api (Swagger UI)" "200" "$status" ""

# 3. Optionally upload custom terminology
if [[ -n "$TERMINOLOGY_FILE" ]]; then
  [[ -f "$TERMINOLOGY_FILE" ]] || die "Terminology file not found: $TERMINOLOGY_FILE"
  log "Uploading custom terminology from ${TERMINOLOGY_FILE}..."
  body=$(curl -s -w '\n%{http_code}' -X POST "${BASE_URL}/terminology" -F "file=@${TERMINOLOGY_FILE}")
  status="${body##*$'\n'}"; content="${body%$'\n'*}"
  check "POST /terminology" "201" "$status" "$content"
else
  log "SKIP: POST /terminology (no terminology file given — pass one as \$1 to test upload)"
fi

# 4. Read custom terminology
body=$(curl -s -w '\n%{http_code}' "${BASE_URL}/terminology")
status="${body##*$'\n'}"; content="${body%$'\n'*}"
log "GET /terminology -> HTTP ${status}: ${content}"

# 5. Translate text (without custom terminology, always safe to run)
body=$(curl -s -w '\n%{http_code}' -X POST "${BASE_URL}/translate" \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello, world!","sourceLanguageCode":"en","targetLanguageCode":"fr","useCustomTerminology":false}')
status="${body##*$'\n'}"; content="${body%$'\n'*}"
check "POST /translate" "201" "$status" "$content"

# ── Summary ───────────────────────────────────────────────────────────────────
log "Results: ${pass} passed, ${fail} failed."
#[[ "$fail" -eq 0 ]] || exit 1
