#!/bin/bash
set -euo pipefail

# ── Vowrite DMG Builder ───────────────────────────────────
# Creates a DMG with Vowrite.app + Applications symlink
# Usage: ./scripts/create-dmg.sh

APP_NAME="Vowrite"
APP_PATH="VowriteApp/Vowrite.app"
VERSION=$(grep 'static let current' VowriteApp/Core/Version.swift | sed 's/.*"\(.*\)".*/\1/')
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_DIR="releases"
DMG_PATH="${DMG_DIR}/${DMG_NAME}"

echo "📦 Building DMG for ${APP_NAME} v${VERSION}..."

# ── Verify app exists ──────────────────────────────────────
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Build first: cd VowriteApp && swift build -c release"
    exit 1
fi

# ── Prepare staging directory ──────────────────────────────
STAGING=$(mktemp -d)/${APP_NAME}
mkdir -p "$STAGING"
echo "📁 Copying app to staging..."
cp -R "$APP_PATH" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"

# ── Ad-hoc code sign ──────────────────────────────────────
echo "🔏 Code signing (ad-hoc)..."
codesign --force --deep --sign - "${STAGING}/${APP_NAME}.app"

# ── Create compressed DMG ─────────────────────────────────
mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"
echo "💿 Creating DMG..."
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" > /dev/null

# ── Cleanup ───────────────────────────────────────────────
rm -rf "$(dirname "$STAGING")"

# ── Verify ────────────────────────────────────────────────
DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
echo ""
echo "✅ ${DMG_PATH} (${DMG_SIZE})"
echo "   Contents: ${APP_NAME}.app + Applications symlink"
echo "   Signed: ad-hoc"
