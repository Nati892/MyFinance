#!/usr/bin/env bash
# Full build and deploy: Flutter APK + web app.
# Publishes the Flutter APK then rebuilds the web Docker image.
#
# Usage:
#   ./build_full.sh                  # bump version, build APK, upload, rebuild web
#   ./build_full.sh --no-build       # skip APK build, upload existing APK, rebuild web
#   ./build_full.sh --skip-bump      # skip version bump, build and upload APK, rebuild web
#
# Any flags are passed through to flutter_publish.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Step 1: Flutter APK"
echo "========================================"
bash "$SCRIPT_DIR/flutter_publish.sh" "$@"

echo ""
echo "========================================"
echo "  Step 2: Web app"
echo "========================================"
bash "$SCRIPT_DIR/build_web.sh"

echo ""
echo "========================================"
echo "  Full build complete."
echo "========================================"
