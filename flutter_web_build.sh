#!/usr/bin/env bash
# Build the Flutter web app and copy it to public/flutter/.
# The build is served at /app/* by the backend.
#
# Usage:
#   ./flutter_web_build.sh

set -euo pipefail

export FLUTTER_ALLOW_ROOT=1
export PATH="$PATH:/opt/flutter/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_APP_DIR="$SCRIPT_DIR/household"
OUTPUT_DIR="$SCRIPT_DIR/public/flutter"

echo "==> Building Flutter web (base href: /app/)..."
cd "$FLUTTER_APP_DIR"

flutter pub get
flutter build web --base-href /app/ --release --no-tree-shake-icons --no-wasm-dry-run

echo ""
echo "==> Copying build to $OUTPUT_DIR ..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -r "$FLUTTER_APP_DIR/build/web/." "$OUTPUT_DIR/"

echo ""
echo "==> Flutter web build complete: $OUTPUT_DIR"
