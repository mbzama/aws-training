#!/usr/bin/env bash
# start.sh — Start all micro-frontend apps for local development
#
# Apps started:
#   landing  → http://localhost:3000  (proxies /users and /movies to below)
#   users    → http://localhost:3001/users
#   movies   → http://localhost:3002/movies
#
# Usage:
#   ./start.sh                       # start all three apps
#   ./start.sh users                 # start a single app
#   ./start.sh landing users movies  # explicit list

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS="${*:-landing users movies}"

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Port lookup (bash 3 compatible) ──────────────────────────────────────────
get_port() {
  case "$1" in
    landing) echo 3000 ;;
    users)   echo 3001 ;;
    movies)  echo 3002 ;;
    *)       echo "" ;;
  esac
}

PIDS=()

cleanup() {
  echo ""
  echo -e "${YELLOW}Stopping all apps...${RESET}"
  for PID in "${PIDS[@]}"; do
    kill "$PID" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  echo -e "${GREEN}All apps stopped.${RESET}"
}
trap cleanup EXIT INT TERM

# ── Install deps if missing ───────────────────────────────────────────────────
for APP in $APPS; do
  APP_DIR="${REPO_ROOT}/${APP}"
  if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}[ERROR] Directory '${APP}' not found — skipping.${RESET}"
    continue
  fi
  if [ ! -d "${APP_DIR}/node_modules" ]; then
    echo -e "${CYAN}[${APP}]${RESET} Installing dependencies..."
    (cd "$APP_DIR" && npm install --silent)
  fi
done

echo ""
echo -e "${BOLD}Starting apps...${RESET}"
echo ""

# ── Launch each app in the background ────────────────────────────────────────
LOG_DIR="${REPO_ROOT}/.logs"
mkdir -p "$LOG_DIR"

for APP in $APPS; do
  APP_DIR="${REPO_ROOT}/${APP}"
  [ -d "$APP_DIR" ] || continue

  LOG_FILE="${LOG_DIR}/${APP}.log"
  : > "$LOG_FILE"   # truncate log from previous run

  (cd "$APP_DIR" && npm run dev > "$LOG_FILE" 2>&1) &
  PID=$!
  PIDS+=("$PID")
  echo -e "  ${CYAN}[${APP}]${RESET} started (PID ${PID}) — logs: .logs/${APP}.log"
done

# ── Wait for servers to be ready ─────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Waiting for servers to be ready...${RESET}"

for APP in $APPS; do
  [ -d "${REPO_ROOT}/${APP}" ] || continue
  PORT_NUM="$(get_port "$APP")"
  [ -n "$PORT_NUM" ] || continue

  RETRIES=30
  until curl -s "http://localhost:${PORT_NUM}" > /dev/null 2>&1; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -le 0 ]; then
      echo -e "  ${RED}[${APP}] timed out waiting on port ${PORT_NUM}${RESET}"
      echo -e "  Check .logs/${APP}.log for errors."
      break
    fi
    sleep 1
  done

  if [ "$RETRIES" -gt 0 ]; then
    echo -e "  ${GREEN}[${APP}]${RESET} ready on port ${PORT_NUM}"
  fi
done

# ── Print URLs ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}──────────────────────────────────────────${RESET}"
echo -e "${BOLD} Local URLs${RESET}"
echo -e "${BOLD}──────────────────────────────────────────${RESET}"
for APP in $APPS; do
  [ -d "${REPO_ROOT}/${APP}" ] || continue
  PORT_NUM="$(get_port "$APP")"
  if [ "$APP" = "landing" ]; then
    echo -e "  ${GREEN}landing${RESET}  →  http://localhost:${PORT_NUM}/"
  else
    echo -e "  ${GREEN}${APP}${RESET}     →  http://localhost:${PORT_NUM}/${APP}"
    echo -e "             (via landing proxy: http://localhost:3000/${APP})"
  fi
done
echo -e "${BOLD}──────────────────────────────────────────${RESET}"
echo ""
echo -e "Press ${BOLD}Ctrl+C${RESET} to stop all apps."
echo ""

# ── Keep script alive until Ctrl+C ───────────────────────────────────────────
wait
