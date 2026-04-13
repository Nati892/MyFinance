#!/usr/bin/env bash
# Restart the full stack: bring docker-compose down then back up with a fresh build.
#
# Usage:
#   ./deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Building images (validation before taking stack down)..."
docker-compose build
echo "==> Build succeeded."

echo ""
echo "==> Bringing stack down..."
docker-compose down

echo ""
echo "==> Starting stack with pre-built images..."
docker-compose up -d

echo ""
echo "==> Done. Running containers:"
docker-compose ps
