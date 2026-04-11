#!/usr/bin/env bash
# Upload the Flutter release APK to the server.
# Runs flutter_build.sh first unless --no-build is passed.
#
# Usage:
#   ./flutter_publish.sh                  # build then upload
#   ./flutter_publish.sh --no-build       # upload existing APK without building
#
# Environment variables (override defaults):
#   SERVER_URL      - e.g. http://5.189.161.010:1236
#   MANAGER_TOKEN   - manager API token

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APK_PATH="$SCRIPT_DIR/flutter_app/build/app/outputs/flutter-apk/app-release.apk"

SERVER_URL="${SERVER_URL:-http://5.189.161.10:1236}"
MANAGER_TOKEN="${MANAGER_TOKEN:-household-manager-api-token}"

NO_BUILD=0
for arg in "$@"; do
  [[ "$arg" == "--no-build" ]] && NO_BUILD=1
done

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
