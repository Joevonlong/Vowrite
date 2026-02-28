#!/bin/bash
#
# Vowrite Release Script
# Usage: ./ops/scripts/release.sh v0.1.6.0 "Short release description"
#
# Automates:
#   1. Version validation (4-segment format)
#   2. CHANGELOG.md: [Unreleased] → [X.Y.Z.W] — date
#   3. Info.plist + SettingsView version bump
#   4. Release build + code signing + DMG packaging
#   5. Git commit (v0.1.6.0: description) + annotated tag
#   6. Summary with next steps
#
set -e

# --- Config ---
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/VowriteApp"
APP_BUNDLE="$APP_DIR/Vowrite.app"
ENTITLEMENTS="$APP_DIR/Resources/Vowrite.entitlements"
INFO_PLIST="$APP_DIR/Resources/Info.plist"
SETTINGS_VIEW="$APP_DIR/Views/SettingsView.swift"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
VERSION_SWIFT="$APP_DIR/Core/Version.swift"
DMG_OUTPUT_DIR="$PROJECT_ROOT/releases"

# --- Args ---
VERSION="${1:?Usage: release.sh <version> <description> (e.g. v0.1.6.0 \"Bug fixes and improvements\")}"
DESCRIPTION="${2:-Release $VERSION}"
VERSION_NUM="${VERSION#v}" # Strip 'v' prefix

# --- Validate version format (X.Y.Z.W) ---
if ! echo "$VERSION_NUM" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Invalid version format: $VERSION"
    echo "   Must be 4-segment: vX.Y.Z.W (e.g. v0.1.6.0)"
    exit 1
fi

echo "═══════════════════════════════════════"
echo "  Vowrite Release: $VERSION"
echo "  $DESCRIPTION"
echo "═══════════════════════════════════════"

# --- Pre-checks ---
echo ""
echo "▶ Pre-flight checks..."

# Must be on main branch
CURRENT_BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "❌ Must be on 'main' branch to release. Currently on: $CURRENT_BRANCH"
    echo "   Run: git checkout main"
    exit 1
fi

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

# --- Step 1: Update CHANGELOG.md ---
echo ""
echo "▶ Step 1: Updating CHANGELOG.md..."

TODAY=$(date +%Y-%m-%d)

if grep -q '## \[Unreleased\]' "$CHANGELOG"; then
    # Check if [Unreleased] has content
    UNRELEASED_CONTENT=$(sed -n '/## \[Unreleased\]/,/## \[/p' "$CHANGELOG" | sed '1d;$d' | grep -v '^$' || true)
    if [ -z "$UNRELEASED_CONTENT" ]; then
        echo "  ⚠️  [Unreleased] section is empty."
        read -p "   Continue with empty changelog entry? (y/N) " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi

    # Replace [Unreleased] with version, add new [Unreleased]
    sed -i '' "s/## \[Unreleased\]/## [Unreleased]\n\n## [$VERSION_NUM] — $TODAY/" "$CHANGELOG"

    # Update comparison links at bottom
    # Add new unreleased link and version link
    PREV_VERSION=$(grep -oE '\[[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | head -2 | tail -1 | tr -d '[]')
    if [ -n "$PREV_VERSION" ]; then
        # Update [Unreleased] link
        sed -i '' "s|^\[Unreleased\]:.*|[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/$VERSION...HEAD|" "$CHANGELOG"
        # Add version comparison link if not exists
        if ! grep -q "^\[$VERSION_NUM\]:" "$CHANGELOG"; then
            sed -i '' "/^\[Unreleased\]:/a\\
[$VERSION_NUM]: https://github.com/Joevonlong/Vowrite/compare/v$PREV_VERSION...$VERSION" "$CHANGELOG"
        fi
    fi

    echo "  ✓ CHANGELOG.md updated: [Unreleased] → [$VERSION_NUM] — $TODAY"
else
    echo "  ⚠️  No [Unreleased] section found in CHANGELOG.md"
    echo "  Please add changelog entries manually."
fi

# --- Step 2: Update version in Info.plist ---
echo ""
echo "▶ Step 2: Updating version to $VERSION_NUM..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NUM" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_NUM" "$APP_BUNDLE/Contents/Info.plist"
echo "  ✓ App bundle Info.plist updated"
echo "  ✓ Info.plist updated"

# --- Step 3: Update version in SettingsView.swift ---
echo ""
echo "▶ Step 3: Updating Version.swift..."
sed -i '' "s/static let current = \"[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\"/static let current = \"$VERSION_NUM\"/" "$VERSION_SWIFT"
echo "  ✓ Version.swift updated"

# --- Step 4: Build Release ---
echo ""
echo "▶ Step 4: Building release..."
cd "$APP_DIR"
swift build -c release 2>&1
echo "  ✓ Release build complete"

# --- Step 5: Copy binary ---
echo ""
echo "▶ Step 5: Copying binary to app bundle..."
cp .build/arm64-apple-macosx/release/Vowrite "$APP_BUNDLE/Contents/MacOS/Vowrite"
echo "  ✓ Binary copied"

# --- Step 6: Code sign ---
echo ""
echo "▶ Step 6: Code signing..."

IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -n "$IDENTITY" ]; then
    echo "  Using Developer ID: $IDENTITY"
    codesign -fs "$IDENTITY" --deep --options runtime --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
    echo "  ✓ Signed with Developer ID"

    # Notarize
    echo ""
    echo "▶ Step 6b: Notarizing..."
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

# --- Step 7: Create DMG ---
echo ""
echo "▶ Step 7: Creating DMG..."
mkdir -p "$DMG_OUTPUT_DIR"
DMG_PATH="$DMG_OUTPUT_DIR/Vowrite-${VERSION}.dmg"

DMG_STAGING="/tmp/vowrite-dmg-$$"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "Vowrite $VERSION" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"
echo "  ✓ DMG created: $DMG_PATH"

# --- Step 8: Git commit + tag ---
echo ""
echo "▶ Step 8: Git commit and tag..."
cd "$PROJECT_ROOT"
git add -A
git commit -m "$VERSION_NUM: $DESCRIPTION" || echo "  (nothing to commit)"
git tag -a "$VERSION" -m "$VERSION — $DESCRIPTION" 2>/dev/null || {
    echo "  Tag $VERSION exists. Overwrite? (y/N)"
    read -p "   " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && git tag -fa "$VERSION" -m "$VERSION — $DESCRIPTION"
}
echo "  ✓ Committed and tagged $VERSION"

# --- Step 10: Summary ---
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Release $VERSION complete!"
echo "═══════════════════════════════════════"
echo ""
echo "  DMG:  $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  Next steps:"
echo "  1. Review:  git log --oneline -3 main"
echo "  2. Test:    open $DMG_PATH"
echo "  3. Push:    git push origin main --tags"
echo "  4. Release: gh release create $VERSION $DMG_PATH --title \"Vowrite $VERSION — $DESCRIPTION\" --notes-file <(sed -n '/## \\[$VERSION_NUM\\]/,/## \\[/p' CHANGELOG.md | sed '\$d')"
echo ""
