#!/usr/bin/env bash
# Build and sign a release APK of the tempus flavor with the local Android
# debug keystore. Output: app/build/outputs/apk/tempus/release/*-debugsigned.apk
#
# Usage: scripts/build-release.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="app/build/outputs/apk/tempus/release"
KEYSTORE="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"

if [[ ! -f "$KEYSTORE" ]]; then
    echo "ERROR: debug keystore not found at $KEYSTORE" >&2
    echo "Run any debug build once to let AGP generate it, or set ANDROID_DEBUG_KEYSTORE." >&2
    exit 1
fi

SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/android-sdk}}"
APKSIGNER="$(ls -1 "$SDK_ROOT"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -n1)"
if [[ -z "$APKSIGNER" ]]; then
    echo "ERROR: apksigner not found under $SDK_ROOT/build-tools/*" >&2
    exit 1
fi

echo ">> Building tempus release (arm64-v8a only)"
./gradlew assembleTempusRelease

UNSIGNED="$(ls -1 "$OUT_DIR"/app-tempus-arm64-v8a-release-unsigned.apk 2>/dev/null || true)"
if [[ -z "$UNSIGNED" ]]; then
    echo "ERROR: expected unsigned APK not found in $OUT_DIR" >&2
    exit 1
fi

SIGNED="${UNSIGNED/-unsigned/-debugsigned}"
echo ">> Signing with debug keystore"
"$APKSIGNER" sign \
    --ks "$KEYSTORE" \
    --ks-pass pass:android \
    --ks-key-alias androiddebugkey \
    --key-pass pass:android \
    --out "$SIGNED" \
    "$UNSIGNED"

echo ">> Verifying signature"
"$APKSIGNER" verify "$SIGNED" >/dev/null

SIZE="$(ls -lh "$SIGNED" | awk '{print $5}')"
echo ""
echo "Built: $SIGNED ($SIZE)"
echo "Install: adb install -r \"$SIGNED\""
