#!/usr/bin/env bash
# Restart the full stack: bring docker-compose down then back up with a fresh build.
#
# Usage:
#   ./deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Bringing stack down..."
docker-compose down

echo ""
echo "==> Building and starting stack..."
docker-compose up -d --build

echo ""
echo "==> Done. Running containers:"
docker-compose ps
