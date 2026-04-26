#!/usr/bin/env bash
# Build a debug APK of the tempus flavor. AGP auto-signs debug builds with
# ~/.android/debug.keystore, so no explicit signing step is needed.
#
# Output: app/build/outputs/apk/tempus/debug/*.apk
# Package: me.keeton.tempus.debug (installs side-by-side with release)
#
# Usage: scripts/build-debug.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="app/build/outputs/apk/tempus/debug"

echo ">> Building tempus debug (arm64-v8a only)"
./gradlew assembleTempusDebug

APK="$(ls -1 "$OUT_DIR"/app-tempus-arm64-v8a-debug.apk 2>/dev/null || true)"
if [[ -z "$APK" ]]; then
    echo "ERROR: expected debug APK not found in $OUT_DIR" >&2
    exit 1
fi

SIZE="$(ls -lh "$APK" | awk '{print $5}')"
echo ""
echo "Built: $APK ($SIZE)"
echo "Install: adb install -r \"$APK\""
