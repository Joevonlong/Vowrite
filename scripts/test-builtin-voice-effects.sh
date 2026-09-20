#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAC_DIR="$PROJECT_ROOT/VowriteMac"
BUILD_DIR="$MAC_DIR/.build/arm64-apple-macosx/debug"

if [ "${1:-}" != "--skip-build" ]; then
    (cd "$MAC_DIR" && swift test --build-system native --filter BuiltinVoiceEffectsTests)
    (cd "$MAC_DIR" && swift build --build-system native --product BuiltinVoiceEffectsHarness)
fi

TEMP_ROOT="$(mktemp -d /tmp/vowrite-builtin-effects.XXXXXX)"
APP="$TEMP_ROOT/BuiltinVoiceEffectsHarness.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/BuiltinVoiceEffectsHarness" "$APP/Contents/MacOS/BuiltinVoiceEffectsHarness"
cp "$MAC_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string BuiltinVoiceEffectsHarness "$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string com.vowrite.builtin-effects.packaged-smoke "$APP/Contents/Info.plist"
plutil -replace CFBundleName -string BuiltinVoiceEffectsHarness "$APP/Contents/Info.plist"

"$PROJECT_ROOT/ops/scripts/embed-builtin-voice-effects.sh" \
    "$BUILD_DIR/VowriteMac_BuiltinVoiceEffects.bundle" \
    "$APP"
codesign --force --deep --sign - "$APP" >/dev/null

(
    cd /tmp
    "$APP/Contents/MacOS/BuiltinVoiceEffectsHarness" \
        --smoke \
        --suite "com.vowrite.builtin-effects.packaged-smoke.$PPID"
)

MISSING_APP="$TEMP_ROOT/MissingResources.app"
mkdir -p "$MISSING_APP/Contents/MacOS" "$MISSING_APP/Contents/Resources"
cp "$BUILD_DIR/BuiltinVoiceEffectsHarness" "$MISSING_APP/Contents/MacOS/BuiltinVoiceEffectsHarness"
cp "$MAC_DIR/Resources/Info.plist" "$MISSING_APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string BuiltinVoiceEffectsHarness "$MISSING_APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string com.vowrite.builtin-effects.missing-resource-smoke "$MISSING_APP/Contents/Info.plist"
codesign --force --deep --sign - "$MISSING_APP" >/dev/null
if MISSING_OUTPUT="$(cd /tmp && "$MISSING_APP/Contents/MacOS/BuiltinVoiceEffectsHarness" --smoke 2>&1)"; then
    echo "❌ Missing-resource app unexpectedly loaded resources" >&2
    exit 1
fi
if ! grep -q "Packaged built-in resource bundle unavailable" <<<"$MISSING_OUTPUT"; then
    echo "❌ Missing-resource app did not fail through the safe resource locator" >&2
    echo "$MISSING_OUTPUT" >&2
    exit 1
fi

echo "✅ Built-in Voice Bar catalog, persistence, packaged resources, missing-resource fallback, and all 80 WK renders passed"
