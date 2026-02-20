#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Building Voxa..."
swift build

echo "Copying binary to app bundle..."
cp .build/arm64-apple-macosx/debug/Voxa Voxa.app/Contents/MacOS/Voxa

echo "Re-signing app bundle..."
codesign -fs - --deep --entitlements Resources/Voxa.entitlements Voxa.app

echo "Restarting Voxa..."
pkill -x Voxa 2>/dev/null || true
sleep 2
open Voxa.app

echo "✅ Done! Voxa is running."
echo "Note: You may need to re-grant Accessibility permission in System Settings."
