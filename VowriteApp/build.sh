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
codesign -fs - --deep --entitlements Resources/Vowrite.entitlements Vowrite.app

echo "Restarting Vowrite..."
pkill -x Vowrite 2>/dev/null || true
sleep 2
open Vowrite.app

echo "✅ Done! Vowrite is running."
echo "Note: You may need to re-grant Accessibility permission in System Settings."
