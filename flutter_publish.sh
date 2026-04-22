#!/usr/bin/env bash
# Upload the Flutter release APK to the server.
# Bumps the version in pubspec.yaml (1.0.x+x) then builds and uploads.
#
# Usage:
#   ./flutter_publish.sh                  # bump version, build, upload
#   ./flutter_publish.sh --no-build       # bump version, upload existing APK
#   ./flutter_publish.sh --skip-bump      # build and upload without bumping version
#   ./flutter_publish.sh --no-build --skip-bump  # upload existing APK as-is
#
# Environment variables (override defaults):
#   SERVER_URL      - e.g. http://5.189.161.010:1236
#   MANAGER_TOKEN   - manager API token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUBSPEC="$SCRIPT_DIR/household/pubspec.yaml"
APK_PATH="$SCRIPT_DIR/household/build/app/outputs/flutter-apk/app-release.apk"

SERVER_URL="${SERVER_URL:-http://5.189.161.10:1236}"
MANAGER_TOKEN="${MANAGER_TOKEN:-household-manager-api-token}"

NO_BUILD=0
SKIP_BUMP=0
for arg in "$@"; do
  [[ "$arg" == "--no-build" ]]  && NO_BUILD=1
  [[ "$arg" == "--skip-bump" ]] && SKIP_BUMP=1
done

# ── Version bump ──────────────────────────────────────────────────────────────
if [[ "$SKIP_BUMP" -eq 0 ]]; then
  current=$(grep '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//')
  # Parse 1.0.X+B
  patch=$(echo "$current" | sed 's/1\.0\.\([0-9]*\)+.*/\1/')
  build=$(echo "$current" | sed 's/.*+//')
  next=$(( patch > build ? patch + 1 : build + 1 ))
  new_version="1.0.${next}+${next}"
  sed -i "s/^version: .*/version: ${new_version}/" "$PUBSPEC"
  echo "==> Version: ${current} → ${new_version}"
fi

# Read the app version name (1.0.x) from pubspec — used as the server version string
APP_VERSION=$(grep '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//;s/+.*//')
echo "==> App version: $APP_VERSION"

if [[ "$NO_BUILD" -eq 0 ]]; then
  echo "==> Building..."
  bash "$SCRIPT_DIR/flutter_build.sh"
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "Error: APK not found at $APK_PATH"
  echo "Run ./flutter_build.sh first, or omit --no-build."
  exit 1
fi

echo ""
echo "==> Uploading APK to $SERVER_URL ..."
echo "    File: $APK_PATH ($(du -h "$APK_PATH" | cut -f1))"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X POST \
  -H "Authorization: Bearer $MANAGER_TOKEN" \
  -F "apk=@$APK_PATH" \
  -F "version=$APP_VERSION" \
  "$SERVER_URL/api/apk/upload")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | sed 's/HTTP_STATUS://')
BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS:")

echo "Response: $BODY"

if [[ "$HTTP_STATUS" == "201" ]]; then
  echo ""
  echo "==> Published successfully!"
else
  echo ""
  echo "==> Upload failed (HTTP $HTTP_STATUS)"
  exit 1
fi
