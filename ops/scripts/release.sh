#!/bin/bash
#
# Vowrite Release Script
# Usage: ./ops/scripts/release.sh v0.1.6.0 "Short release description"
#        ./ops/scripts/release.sh --beta v0.1.9.0-beta.1 "Beta description"
#
# Automates:
#   1. Version validation (4-segment format, with optional -beta.N suffix)
#   2. CHANGELOG.md: [Unreleased] → [X.Y.Z.W] — date (relaxed for beta)
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
APPCAST_STABLE="$PROJECT_ROOT/docs/appcast.xml"
APPCAST_BETA="$PROJECT_ROOT/docs/appcast-beta.xml"

# --- Parse --beta flag ---
IS_BETA=false
if [ "$1" = "--beta" ]; then
    IS_BETA=true
    shift
fi

# --- Args ---
VERSION="${1:?Usage: release.sh [--beta] <version> <description> (e.g. v0.1.6.0 \"Bug fixes and improvements\")}"
DESCRIPTION="${2:-Release $VERSION}"
VERSION_NUM="${VERSION#v}" # Strip 'v' prefix

# --- Detect beta from version string ---
if echo "$VERSION_NUM" | grep -qE '\-beta\.[0-9]+$'; then
    IS_BETA=true
fi

# --- Validate version format (X.Y.Z.W or X.Y.Z.W-beta.N) ---
if ! echo "$VERSION_NUM" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$'; then
    echo "❌ Invalid version format: $VERSION"
    echo "   Must be: vX.Y.Z.W (e.g. v0.1.6.0)"
    echo "        or: vX.Y.Z.W-beta.N (e.g. v0.1.9.0-beta.1)"
    exit 1
fi

# Extract base version (without -beta.N) for plist/swift updates
VERSION_BASE="${VERSION_NUM%%-beta*}"

if $IS_BETA; then
    RELEASE_TYPE="BETA"
else
    RELEASE_TYPE="STABLE"
fi

echo "═══════════════════════════════════════"
echo "  Vowrite Release: $VERSION [$RELEASE_TYPE]"
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

if $IS_BETA; then
    # Beta: changelog update is optional
    if grep -q '## \[Unreleased\]' "$CHANGELOG"; then
        UNRELEASED_CONTENT=$(sed -n '/## \[Unreleased\]/,/## \[/p' "$CHANGELOG" | sed '1d;$d' | grep -v '^$' || true)
        if [ -z "$UNRELEASED_CONTENT" ]; then
            echo "  ℹ️  [Unreleased] section is empty — skipping changelog update (beta)"
        else
            echo "  ℹ️  [Unreleased] has content but will not be renamed for beta release"
            echo "  Changelog entries will be included in the stable release"
        fi
    else
        echo "  ℹ️  No [Unreleased] section — skipping changelog update (beta)"
    fi
else
    # Stable: normal changelog flow
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
fi

# --- Step 2: Update version in Info.plist ---
echo ""
echo "▶ Step 2: Updating version to $VERSION_NUM..."
# Info.plist uses base version (no -beta suffix) for macOS compatibility
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_BASE" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION_BASE" "$APP_BUNDLE/Contents/Info.plist"
echo "  ✓ App bundle Info.plist updated"
echo "  ✓ Info.plist updated"

# --- Step 3: Update version in SettingsView.swift ---
echo ""
echo "▶ Step 3: Updating Version.swift..."
# Version.swift shows full version string including -beta.N
sed -i '' "s/static let current = \"[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\(-beta\.[0-9]*\)\{0,1\}\"/static let current = \"$VERSION_NUM\"/" "$VERSION_SWIFT"
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
echo "  ✅ Release $VERSION [$RELEASE_TYPE] complete!"
echo "═══════════════════════════════════════"
echo ""
echo "  DMG:  $DMG_PATH"
echo "  Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "  Next steps:"
echo "  1. Review:  git log --oneline -3 main"
echo "  2. Test:    open $DMG_PATH"
echo "  3. Push:    git push origin main --tags"
if $IS_BETA; then
echo "  4. Release: gh release create $VERSION $DMG_PATH --prerelease --title \"Vowrite $VERSION — $DESCRIPTION\""
echo ""
echo "  Note: This is a BETA release."
echo "  - Appcast: docs/appcast-beta.xml (update manually with edSignature)"
echo "  - To promote to stable: release again without -beta suffix"
else
echo "  4. Release: gh release create $VERSION $DMG_PATH --title \"Vowrite $VERSION — $DESCRIPTION\" --notes-file <(sed -n '/## \\[$VERSION_NUM\\]/,/## \\[/p' CHANGELOG.md | sed '\$d')"
fi
echo ""
