#!/usr/bin/env bash
# Translate text from English into German, French, and Spanish.
#
# Usage:
#   ./test.sh "Text to translate"
set -euo pipefail

PORT="${PORT:-3000}"
BASE_URL="http://localhost:${PORT}"
USE_CUSTOM_TERMINOLOGY="${USE_CUSTOM_TERMINOLOGY:-true}"
TARGET_LANGUAGES=(de fr es)

TEXT="${1:-}"

log() { echo "[test] $*"; }
die() { echo "[error] $*" >&2; exit 1; }

[[ -n "$TEXT" ]] || die "Usage: $0 \"Text to translate\""

for target in "${TARGET_LANGUAGES[@]}"; do
  log "Translating to '${target}'..."
  body=$(curl -s -w '\n%{http_code}' -X POST "${BASE_URL}/translate" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"${TEXT}\",\"sourceLanguageCode\":\"en\",\"targetLanguageCode\":\"${target}\",\"useCustomTerminology\":${USE_CUSTOM_TERMINOLOGY}}")
  status="${body##*$'\n'}"; content="${body%$'\n'*}"

  if [[ "$status" == "201" ]]; then
    log "[${target}] ${content}"
  else
    log "[${target}] FAILED (HTTP ${status}): ${content}"
  fi
done
