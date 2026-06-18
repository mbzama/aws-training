#!/bin/bash

REFRESH_INTERVAL=${1:-3}  # Default 3 seconds

while true; do
  clear

  echo ""
  echo "╔════════════════════════════════════════════════════════════════╗"
  echo "║                   S3 Buckets - Real-Time Viewer                ║"
  echo "║                    (Refreshing every ${REFRESH_INTERVAL}s)                      ║"
  echo "╚════════════════════════════════════════════════════════════════╝"
  echo ""
  echo "⏱️  Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  bash "$(dirname "${BASH_SOURCE[0]}")/show-s3.sh" 2>/dev/null

  echo ""
  echo "Press Ctrl+C to stop watching..."
  sleep $REFRESH_INTERVAL
done
