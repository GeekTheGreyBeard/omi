#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/run/media/gtgb/GTGB-Files/Developer/flutter/3.35.3/bin/flutter}"
ANDROID_HOME="${ANDROID_HOME:-/run/media/gtgb/GTGB-Files/Developer/android-sdk}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
API_BASE_URL="${API_BASE_URL:-https://omi.splat-i.io/}"
STAGING_API_URL="${STAGING_API_URL:-https://omi.splat-i.io/}"
LIVE_TRANSCRIPTION_WS_BASE_URL="${LIVE_TRANSCRIPTION_WS_BASE_URL:-ws://patriciai-ui-staging.gtgb.io/v4/listen}"
FLAVOR="${FLAVOR:-dev}"
BUILD_MODE="${BUILD_MODE:-debug}"

cd "$APP_DIR"
export ANDROID_HOME ANDROID_SDK_ROOT
export ORG_GRADLE_PROJECT_localBuildDisableCrashlyticsUpload=true
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

"$FLUTTER_BIN" build apk \
  --flavor "$FLAVOR" \
  "--$BUILD_MODE" \
  --build-number="${BUILD_NUMBER:-907}" \
  --dart-define="API_BASE_URL=$API_BASE_URL" \
  --dart-define="STAGING_API_URL=$STAGING_API_URL" \
  --dart-define="LIVE_TRANSCRIPTION_WS_BASE_URL=$LIVE_TRANSCRIPTION_WS_BASE_URL"

echo "Built Omi preproduction Android APK for $FLAVOR/$BUILD_MODE"
echo "API_BASE_URL=$API_BASE_URL"
echo "STAGING_API_URL=$STAGING_API_URL"
echo "LIVE_TRANSCRIPTION_WS_BASE_URL=$LIVE_TRANSCRIPTION_WS_BASE_URL"
