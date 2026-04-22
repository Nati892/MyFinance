#!/usr/bin/env bash
# Build Angular frontend, rebuild Docker image, and restart containers.
# If any step fails the running containers are left untouched.
#
# Usage:
#   ./build_web.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Building Angular frontend..."
cd "$SCRIPT_DIR/front_end"
npm install --silent
npm run build -- --configuration production

echo ""
echo "==> Building Docker image..."
cd "$SCRIPT_DIR"
docker-compose build

echo ""
echo "==> Restarting containers..."
docker-compose down
docker-compose up -d

echo ""
echo "==> Done! Web app is live."
