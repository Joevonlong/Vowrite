#!/bin/bash
#
# Vowrite Beta Build Script
# Usage: ./ops/scripts/beta-build.sh
#
# Quick release-config build for cross-device testing.
# Outputs: releases/Vowrite-dev.dmg (overwritten each time)
#
# Does NOT commit, tag, or push.
#
set -e

# --- Config ---
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/VowriteApp"
APP_BUNDLE="$APP_DIR/Vowrite.app"
ENTITLEMENTS="$APP_DIR/Resources/Vowrite.entitlements"
DMG_OUTPUT_DIR="$PROJECT_ROOT/releases"
DMG_PATH="$DMG_OUTPUT_DIR/Vowrite-dev.dmg"

echo "═══════════════════════════════════════"
echo "  Vowrite Beta Build (dev DMG)"
echo "═══════════════════════════════════════"

# --- Step 1: Release build ---
echo ""
echo "▶ Step 1: Building (release config)..."
cd "$APP_DIR"
swift build -c release 2>&1
echo "  ✓ Release build complete"

# --- Step 2: Copy binary + resources ---
echo ""
echo "▶ Step 2: Copying binary to app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp .build/arm64-apple-macosx/release/Vowrite "$APP_BUNDLE/Contents/MacOS/Vowrite"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
echo "  ✓ Binary and Info.plist copied"

# --- Step 3: Embed Sparkle ---
echo ""
echo "▶ Step 3: Embedding Sparkle.framework..."
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_SRC=".build/arm64-apple-macosx/release/Sparkle.framework"
if [ -d "$SPARKLE_SRC" ]; then
    rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    cp -a "$SPARKLE_SRC" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath @executable_path/../Frameworks \
        "$APP_BUNDLE/Contents/MacOS/Vowrite" 2>/dev/null || true
    echo "  ✓ Sparkle.framework embedded"
else
    echo "  ⚠️  Sparkle.framework not found at $SPARKLE_SRC — skipping"
fi

# --- Step 4: Code sign ---
echo ""
echo "▶ Step 4: Code signing..."

SIGN_ID="Vowrite Developer"
SIGN_KEYCHAIN="$HOME/Library/Keychains/vowrite-signing.keychain-db"

if [ -f "$SIGN_KEYCHAIN" ]; then
    security unlock-keychain -p "vowrite" "$SIGN_KEYCHAIN" 2>/dev/null
    codesign --force --deep --sign "$SIGN_ID" \
        --keychain "$SIGN_KEYCHAIN" \
        --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "  ✓ Signed with self-signed certificate: $SIGN_ID"
else
    echo "  ⚠️  Signing keychain not found. Using adhoc signing."
    codesign --force --deep --sign "-" --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
fi

# --- Step 5: Create DMG ---
echo ""
echo "▶ Step 5: Creating DMG..."
mkdir -p "$DMG_OUTPUT_DIR"

DMG_STAGING="/tmp/vowrite-beta-dmg-$$"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/Vowrite.app"
# Re-sign the copy
if [ -f "$SIGN_KEYCHAIN" ]; then
    codesign --force --deep --sign "$SIGN_ID" \
        --keychain "$SIGN_KEYCHAIN" \
        --entitlements "$ENTITLEMENTS" "$DMG_STAGING/Vowrite.app"
else
    codesign --force --deep --sign "-" --entitlements "$ENTITLEMENTS" "$DMG_STAGING/Vowrite.app"
fi
ln -s /Applications "$DMG_STAGING/Applications"
# Include install script if available
if [ -f "$PROJECT_ROOT/scripts/install.sh" ]; then
    cp "$PROJECT_ROOT/scripts/install.sh" "$DMG_STAGING/Install Vowrite.command"
    chmod +x "$DMG_STAGING/Install Vowrite.command"
fi

hdiutil create -volname "Vowrite Dev" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Beta build complete!"
echo "═══════════════════════════════════════"
echo ""
echo "  DMG:  $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  Copy to another device for testing:"
echo "  airdrop / scp / shared folder"
echo ""
