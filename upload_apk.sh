#!/usr/bin/env bash
# Upload a Flutter-built APK to the household server.
# Usage:
#   ./upload_apk.sh                          # auto-finds the release APK
#   ./upload_apk.sh /path/to/app-release.apk # explicit path
#
# Environment variables (override defaults):
#   SERVER_URL      - e.g. http://5.189.161.010:1236
#   MANAGER_TOKEN   - manager API token (default: household-manager-api-token)

set -euo pipefail

SERVER_URL="${SERVER_URL:-http://5.189.161.010:1236}"
MANAGER_TOKEN="${MANAGER_TOKEN:-household-manager-api-token}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_APK="${SCRIPT_DIR}/household/build/app/outputs/flutter-apk/app-release.apk"
PUBSPEC="${SCRIPT_DIR}/household/pubspec.yaml"

APK_PATH="${1:-$DEFAULT_APK}"

APP_VERSION=$(grep '^version:' "$PUBSPEC" | head -1 | sed 's/version: *//;s/+.*//')

if [ ! -f "$APK_PATH" ]; then
  echo "Error: APK not found at: $APK_PATH"
  echo ""
  echo "Build first with:"
  echo "  cd household && flutter build apk --release"
  echo ""
  echo "Or provide the path explicitly:"
  echo "  ./upload_apk.sh /path/to/app-release.apk"
  exit 1
fi

echo "Uploading APK..."
echo "  File:    $APK_PATH"
echo "  Server:  $SERVER_URL"
echo "  Version: $APP_VERSION"
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

if [ "$HTTP_STATUS" = "201" ]; then
  echo ""
  echo "Upload successful!"
else
  echo ""
  echo "Upload failed with HTTP status $HTTP_STATUS"
  exit 1
fi
