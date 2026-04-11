#!/usr/bin/env bash
# Build the Flutter app and produce a release APK.
# Output: flutter_app/build/app/outputs/flutter-apk/app-release.apk

set -euo pipefail

export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
export ANDROID_HOME="/opt/android-sdk"
export ANDROID_SDK_ROOT="/opt/android-sdk"
export FLUTTER_ALLOW_ROOT=1
export PATH="$PATH:/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_APP_DIR="$SCRIPT_DIR/flutter_app"

echo "==> Building Flutter APK (release)..."
cd "$FLUTTER_APP_DIR"

flutter pub get
flutter build apk --release --no-tree-shake-icons

APK_PATH="$FLUTTER_APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "==> Build complete: $APK_PATH ($(du -h "$APK_PATH" | cut -f1))"
