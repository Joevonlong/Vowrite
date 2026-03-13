#!/bin/bash
set -e
cd "$(dirname "$0")"

# If source icon exists but .icns hasn't been generated yet, auto-convert
if [ -f "Resources/AppIcon-source.png" ] && [ ! -f "Vowrite.app/Contents/Resources/AppIcon.icns" ]; then
  echo "🎨 New icon detected, auto-generating .icns..."
  ./scripts/generate-icon.sh
fi

echo "Building Vowrite..."
swift build

echo "Syncing Info.plist to app bundle..."
cp Resources/Info.plist Vowrite.app/Contents/Info.plist

echo "Copying binary to app bundle..."
mkdir -p Vowrite.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/Vowrite Vowrite.app/Contents/MacOS/Vowrite

echo "Re-signing app bundle..."
# F-024: Use stable self-signed cert for persistent permissions across updates
SIGN_ID="Vowrite Developer"
SIGN_KEYCHAIN="$HOME/Library/Keychains/vowrite-signing.keychain-db"

if [ -f "$SIGN_KEYCHAIN" ]; then
    security unlock-keychain -p "vowrite" "$SIGN_KEYCHAIN" 2>/dev/null
    codesign --force --deep --sign "$SIGN_ID" \
        --keychain "$SIGN_KEYCHAIN" \
        --entitlements Resources/Vowrite.entitlements Vowrite.app
    echo "   ✅ Signed with self-signed certificate: $SIGN_ID"
else
    echo "   ⚠️  Signing keychain not found. Using adhoc signing."
    echo "   Permissions may reset on update. See ops/SIGNING.md"
    codesign --force --deep --sign "-" --entitlements Resources/Vowrite.entitlements Vowrite.app
fi

echo "Restarting Vowrite..."
pkill -x Vowrite 2>/dev/null || true
sleep 2
open Vowrite.app

echo "✅ Done! Vowrite is running."
echo "Note: You may need to re-grant Accessibility permission in System Settings."
