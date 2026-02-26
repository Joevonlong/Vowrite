#!/bin/bash
#
# Vowrite Release Script
# Usage: ./ops/scripts/release.sh v0.2
#
set -e

# --- Config ---
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/VowriteApp"
APP_BUNDLE="$APP_DIR/Vowrite.app"
ENTITLEMENTS="$APP_DIR/Resources/Vowrite.entitlements"
INFO_PLIST="$APP_DIR/Resources/Info.plist"
DMG_OUTPUT_DIR="$PROJECT_ROOT/releases"

# --- Args ---
VERSION="${1:?Usage: release.sh <version> (e.g. v0.2)}"
VERSION_NUM="${VERSION#v}" # Strip 'v' prefix for plist

echo "═══════════════════════════════════════"
echo "  Vowrite Release: $VERSION"
echo "═══════════════════════════════════════"

# --- Pre-checks ---
echo ""
echo "▶ Pre-flight checks..."

if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain)" ]; then
    echo "⚠️  Working directory has uncommitted changes."
    read -p "   Continue anyway? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

# Check that release checklist has been reviewed
echo ""
echo "📋 Have you completed ops/CHECKLIST_RELEASE.md? (y/N)"
read -p "   " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Please complete the checklist first."; exit 1; }

# --- Step 1: Update version in Info.plist ---
echo ""
echo "▶ Step 1: Updating version to $VERSION_NUM..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NUM" "$INFO_PLIST"
echo "  ✓ Info.plist updated"

# --- Step 2: Build Release ---
echo ""
echo "▶ Step 2: Building release..."
cd "$APP_DIR"
swift build -c release 2>&1
echo "  ✓ Release build complete"

# --- Step 3: Copy binary ---
echo ""
echo "▶ Step 3: Copying binary to app bundle..."
cp .build/arm64-apple-macosx/release/Vowrite "$APP_BUNDLE/Contents/MacOS/Vowrite"
echo "  ✓ Binary copied"

# --- Step 4: Code sign ---
echo ""
echo "▶ Step 4: Code signing..."

# Check for Developer ID
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -n "$IDENTITY" ]; then
    echo "  Using Developer ID: $IDENTITY"
    codesign -fs "$IDENTITY" --deep --options runtime --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "  ✓ Signed with Developer ID"
    
    # Notarize
    echo ""
    echo "▶ Step 4b: Notarizing..."
    DMG_TEMP="/tmp/Vowrite-notarize.zip"
    ditto -c -k --keepParent "$APP_BUNDLE" "$DMG_TEMP"
    xcrun notarytool submit "$DMG_TEMP" --keychain-profile "AC_PASSWORD" --wait || echo "  ⚠️  Notarization failed (may need credentials)"
    xcrun stapler staple "$APP_BUNDLE" 2>/dev/null || echo "  ⚠️  Stapling skipped"
    rm -f "$DMG_TEMP"
else
    echo "  No Developer ID found, using ad-hoc signing"
    codesign -fs - --deep --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "  ✓ Ad-hoc signed"
fi

# --- Step 5: Create DMG ---
echo ""
echo "▶ Step 5: Creating DMG..."
mkdir -p "$DMG_OUTPUT_DIR"
DMG_PATH="$DMG_OUTPUT_DIR/Vowrite-${VERSION}.dmg"

# Create a temporary directory for DMG contents
DMG_STAGING="/tmp/voxa-dmg-$$"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Create DMG
hdiutil create -volname "Vowrite $VERSION" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"
echo "  ✓ DMG created: $DMG_PATH"

# --- Step 6: Git commit + tag ---
echo ""
echo "▶ Step 6: Git commit and tag..."
cd "$PROJECT_ROOT"
git add -A
git commit -m "release: $VERSION" || echo "  (nothing to commit)"
git tag -a "$VERSION" -m "$VERSION" 2>/dev/null || {
    echo "  Tag $VERSION exists. Overwrite? (y/N)"
    read -p "   " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && git tag -fa "$VERSION" -m "$VERSION"
}
echo "  ✓ Tagged $VERSION"

# --- Step 7: Summary ---
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Release $VERSION complete!"
echo "═══════════════════════════════════════"
echo ""
echo "  DMG: $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  Next steps:"
echo "  1. Test the DMG: open $DMG_PATH"
echo "  2. Create GitHub Release: gh release create $VERSION $DMG_PATH"
echo "  3. Update official website download link"
echo "  4. Push: git push origin main --tags"
echo ""
