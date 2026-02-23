#!/bin/bash
set -e
cd "$(dirname "$0")"

# 如果有源图标但还没生成 .icns，自动转换
if [ -f "Resources/AppIcon-source.png" ] && [ ! -f "Voxa.app/Contents/Resources/AppIcon.icns" ]; then
  echo "🎨 检测到新图标，自动生成 .icns..."
  ./scripts/generate-icon.sh
fi

echo "Building Voxa..."
swift build

echo "Syncing Info.plist to app bundle..."
cp Resources/Info.plist Voxa.app/Contents/Info.plist

echo "Copying binary to app bundle..."
mkdir -p Voxa.app/Contents/MacOS
cp .build/arm64-apple-macosx/debug/Voxa Voxa.app/Contents/MacOS/Voxa

echo "Re-signing app bundle..."
codesign -fs - --deep --entitlements Resources/Voxa.entitlements Voxa.app

echo "Restarting Voxa..."
pkill -x Voxa 2>/dev/null || true
sleep 2
open Voxa.app

echo "✅ Done! Voxa is running."
echo "Note: You may need to re-grant Accessibility permission in System Settings."
