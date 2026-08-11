#!/usr/bin/env bash
# Build and start the AWS Translate NestJS service.
set -euo pipefail

PORT="${PORT:-3000}"
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$APP_DIR"

[[ -f .env ]] || echo "[run] WARNING: no .env found — copy .env.example to .env if you need custom config."

if [[ ! -d node_modules ]]; then
  echo "[run] Installing dependencies..."
  npm install
fi

echo "[run] Building..."
npm run build

echo "[run] Application URL: http://localhost:${PORT}"
echo "[run] Swagger UI:      http://localhost:${PORT}/api"
echo "[run] Starting server (Ctrl+C to stop)..."

exec env PORT="$PORT" node dist/main.js
