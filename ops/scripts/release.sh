#!/bin/bash
#
# Vowrite Release Script (ops)
# Usage: ./ops/scripts/release.sh v0.1.6.0 "Short release description"
#        ./ops/scripts/release.sh --beta v0.1.9.0-beta.1 "Beta description"
#
# Automates:
#   1. Version validation (4-segment format, with optional -beta.N suffix)
#   2. CHANGELOG.md: [Unreleased] → [X.Y.Z.W] — date (relaxed for beta)
#   3. Info.plist (version + build number) + Version.swift bump
#   4. Release build + code signing + DMG packaging
#   5. EdDSA signing + appcast.xml update (Sparkle auto-updates)
#   6. Git commit + annotated tag
#   7. GitHub Release creation + DMG upload (interactive)
#   8. Summary with verification steps
#
set -e

# --- Config ---
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/VowriteMac"
APP_BUNDLE="$APP_DIR/Vowrite.app"
ENTITLEMENTS="$APP_DIR/Resources/Vowrite.entitlements"
INFO_PLIST="$APP_DIR/Resources/Info.plist"
VERSION_SWIFT="$PROJECT_ROOT/VowriteKit/Sources/VowriteKit/Version.swift"
CHANGELOG="$PROJECT_ROOT/CHANGELOG.md"
DMG_OUTPUT_DIR="$PROJECT_ROOT/releases"
APPCAST_STABLE="$PROJECT_ROOT/docs/appcast.xml"
APPCAST_BETA="$PROJECT_ROOT/docs/appcast-beta.xml"

# Sparkle EdDSA signing tools
SPARKLE_BIN="$APP_DIR/.build/artifacts/sparkle/Sparkle/bin"
SIGN_UPDATE="$SPARKLE_BIN/sign_update"

# GitHub
GITHUB_REPO="Joevonlong/Vowrite"
GITHUB_DOWNLOAD_BASE="https://github.com/$GITHUB_REPO/releases/download"

# Binary name produced by VowriteMac package
APP_BINARY_NAME="VowriteMac"

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

# Check required files
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "❌ Entitlements not found: $ENTITLEMENTS"
    exit 1
fi
if [ ! -f "$INFO_PLIST" ]; then
    echo "❌ Info.plist not found: $INFO_PLIST"
    exit 1
fi

# Check that release checklist has been reviewed
echo ""
echo "📋 Have you completed ops/CHECKLIST_RELEASE.md? (y/N)"
read -p "   " -n 1 -r
echo
[[ $REPLY =~ ^[Yy]$ ]] || { echo "Please complete the checklist first."; exit 1; }

# --- Preflight: classify commits since last tag by platform impact ---
# Helps the operator catch the case where a Mac release is being cut but the
# only commits since the last tag are iOS-only. Informational, not enforced —
# the third y/N gate gives final authority to the operator.
echo ""
echo "▶ Preflight: commits since last release tag..."

LAST_TAG=$(git -C "$PROJECT_ROOT" describe --tags --abbrev=0 --match='v[0-9]*' 2>/dev/null || echo "")
if [ -z "$LAST_TAG" ]; then
    echo "  ℹ️  No previous v* tag found — skipping preflight (initial release?)"
else
    COMMIT_RANGE="${LAST_TAG}..HEAD"
    COMMITS=$(git -C "$PROJECT_ROOT" log --pretty=format:'%h %s' "$COMMIT_RANGE")

    if [ -z "$COMMITS" ]; then
        echo "  ⚠️  No commits since $LAST_TAG. Nothing to release."
        exit 1
    fi

    # Tally per category
    MAC_ONLY=0; IOS_ONLY=0; SHARED=0; META=0; MIXED=0

    while IFS= read -r commit_line; do
        SHA=$(echo "$commit_line" | awk '{print $1}')
        SUBJECT=$(echo "$commit_line" | cut -d' ' -f2-)
        FILES=$(git -C "$PROJECT_ROOT" show --name-only --pretty=format: "$SHA" | grep -v '^$' || true)

        # Per-commit category counters
        has_mac=0; has_ios=0; has_kit=0; has_meta=0; has_other=0
        while IFS= read -r f; do
            [ -z "$f" ] && continue
            case "$f" in
                VowriteMac/*)                                  has_mac=1 ;;
                VowriteIOS/*|VowriteKeyboard/*)                has_ios=1 ;;
                VowriteKit/*)                                  has_kit=1 ;;
                docs/*|ops/*|scripts/*|*.md|.github/*|.gitignore|LICENSE) has_meta=1 ;;
                *)                                             has_other=1 ;;
            esac
        done <<< "$FILES"

        # Classify (priority: mixed > shared > mac > ios > meta)
        active=$((has_mac + has_ios + has_kit + has_other))
        if [ "$active" -gt 1 ]; then
            CATEGORY="mixed";    MIXED=$((MIXED + 1))
        elif [ "$has_kit" = 1 ]; then
            CATEGORY="shared";   SHARED=$((SHARED + 1))
        elif [ "$has_mac" = 1 ]; then
            CATEGORY="Mac-only"; MAC_ONLY=$((MAC_ONLY + 1))
        elif [ "$has_ios" = 1 ]; then
            CATEGORY="iOS-only"; IOS_ONLY=$((IOS_ONLY + 1))
        elif [ "$has_meta" = 1 ]; then
            CATEGORY="meta";     META=$((META + 1))
        else
            CATEGORY="other";    MIXED=$((MIXED + 1))
        fi

        printf "  %s  %-9s  %s\n" "$SHA" "[$CATEGORY]" "$SUBJECT"
    done <<< "$COMMITS"

    echo ""
    echo "  Summary: $MAC_ONLY Mac-only, $IOS_ONLY iOS-only, $SHARED shared, $MIXED mixed, $META meta"

    if [ "$MAC_ONLY" -eq 0 ] && [ "$SHARED" -eq 0 ] && [ "$MIXED" -eq 0 ]; then
        echo ""
        echo "  ⚠️  No Mac-touching commits since $LAST_TAG."
        echo "     Mac users will see no functional change in this release."
    fi

    echo ""
    echo "  ❓ Did you record iOS-only changes to CHANGELOG-IOS.md? (y/N)"
    read -p "     " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "  Release deferred. Update CHANGELOG-IOS.md and re-run."; exit 0; }

    echo "  ❓ Does CHANGELOG.md [Unreleased] contain only Mac-relevant entries? (y/N)"
    read -p "     " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "  Release deferred. Edit CHANGELOG.md and re-run."; exit 0; }

    echo "  ❓ Proceed with macOS release $VERSION? (y/N)"
    read -p "     " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || { echo "  Release deferred. No changes made."; exit 0; }
fi

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
        PREV_VERSION=$(grep -oE '\[[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" | head -2 | tail -1 | tr -d '[]')
        if [ -n "$PREV_VERSION" ]; then
            sed -i '' "s|^\[Unreleased\]:.*|[Unreleased]: https://github.com/Joevonlong/Vowrite/compare/$VERSION...HEAD|" "$CHANGELOG"
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

# Auto-increment CFBundleVersion (build number) — Sparkle uses this for version comparison
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
NEW_BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$INFO_PLIST"
echo "  ✓ Info.plist updated (CFBundleVersion: $CURRENT_BUILD → $NEW_BUILD)"

# --- Step 3: Update version in Version.swift ---
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

# --- Step 5: Copy binary + embed Sparkle ---
echo ""
echo "▶ Step 5: Copying binary to app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
# VowriteMac binary → rename to Vowrite in the app bundle
cp ".build/arm64-apple-macosx/release/${APP_BINARY_NAME}" "$APP_BUNDLE/Contents/MacOS/Vowrite"
cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
echo "  ✓ Binary and Info.plist copied"

# Embed Sparkle.framework into app bundle
SPARKLE_FW=".build/arm64-apple-macosx/release/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    echo "  Embedding Sparkle.framework..."
    mkdir -p "$APP_BUNDLE/Contents/Frameworks"
    rm -rf "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
    cp -a "$SPARKLE_FW" "$APP_BUNDLE/Contents/Frameworks/"
    install_name_tool -add_rpath @executable_path/../Frameworks \
        "$APP_BUNDLE/Contents/MacOS/Vowrite" 2>/dev/null || true
    echo "  ✓ Sparkle.framework embedded"
else
    echo "  ⚠️  Sparkle.framework not found — release may crash on launch!"
fi

# --- Step 6: Code sign (with entitlements) ---
echo ""

# F-024: Use stable self-signed cert for persistent permissions
SIGN_KEYCHAIN="$HOME/Library/Keychains/vowrite-signing.keychain-db"
if [ -f "$SIGN_KEYCHAIN" ]; then
    security unlock-keychain -p "vowrite" "$SIGN_KEYCHAIN" 2>/dev/null
    SIGN_IDENTITY="Vowrite Developer"
    KEYCHAIN_FLAG="--keychain ${SIGN_KEYCHAIN}"
    echo "🔏 Step 6: Code signing (self-signed certificate)..."
else
    SIGN_IDENTITY="-"
    KEYCHAIN_FLAG=""
    echo "🔏 Step 6: Code signing (ad-hoc — permissions may reset on update)..."
    echo "   💡 Tip: Set up self-signed cert to keep permissions across updates."
    echo "   See ops/SIGNING.md for instructions."
fi
codesign --force --deep --sign "${SIGN_IDENTITY}" ${KEYCHAIN_FLAG} --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
codesign --verify "$APP_BUNDLE"
echo "  ✓ Code signed and verified"

# --- Step 7: Create DMG ---
echo ""
echo "▶ Step 7: Creating DMG..."
mkdir -p "$DMG_OUTPUT_DIR"
DMG_PATH="$DMG_OUTPUT_DIR/Vowrite-${VERSION}.dmg"

DMG_STAGING="/tmp/vowrite-dmg-$$"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/Vowrite.app"
# Re-sign the copy with entitlements (ensures DMG copy is properly signed)
codesign --force --deep --sign "${SIGN_IDENTITY}" ${KEYCHAIN_FLAG} --entitlements "$ENTITLEMENTS" "$DMG_STAGING/Vowrite.app"
ln -s /Applications "$DMG_STAGING/Applications"
# Include install script for easy updates (quit → replace → relaunch)
if [ -f "$PROJECT_ROOT/scripts/install.sh" ]; then
    cp "$PROJECT_ROOT/scripts/install.sh" "$DMG_STAGING/Install Vowrite.command"
    chmod +x "$DMG_STAGING/Install Vowrite.command"
fi

hdiutil create -volname "Vowrite $VERSION" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"
echo "  ✓ DMG created: $DMG_PATH"

# --- Step 8: EdDSA sign DMG + update appcast ---
echo ""
echo "▶ Step 8: EdDSA signing and appcast update..."

if [ -x "$SIGN_UPDATE" ]; then
    SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)

    if [ -z "$SIGN_OUTPUT" ]; then
        echo "  ❌ sign_update produced no output — check Keychain for EdDSA key"
        echo "  Skipping appcast update."
    else
        echo "  ✓ DMG signed: $SIGN_OUTPUT"

        # Extract edSignature and length from sign_update output
        ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -oE 'sparkle:edSignature="[^"]+"')
        ED_LENGTH=$(echo "$SIGN_OUTPUT" | grep -oE 'length="[^"]+"')

        # Select target appcast
        if $IS_BETA; then
            TARGET_APPCAST="$APPCAST_BETA"
        else
            TARGET_APPCAST="$APPCAST_STABLE"
        fi

        DOWNLOAD_URL="${GITHUB_DOWNLOAD_BASE}/${VERSION}/Vowrite-${VERSION}.dmg"
        PUB_DATE=$(date "+%a, %d %b %Y %H:%M:%S %z")

        # Extract release notes from CHANGELOG → simple HTML
        RELEASE_NOTES=""
        if [ -f "$CHANGELOG" ] && ! $IS_BETA; then
            CHANGELOG_SECTION=$(sed -n "/## \[$VERSION_NUM\]/,/## \[/p" "$CHANGELOG" | sed '1d;$d' | sed '/^$/d')
            if [ -n "$CHANGELOG_SECTION" ]; then
                RELEASE_NOTES="<h2>What's New in $VERSION_NUM</h2><ul>"
                while IFS= read -r line; do
                    ITEM=$(echo "$line" | sed -E 's/^- \*\*([^*]+)\*\*(.*)/<li><b>\1<\/b>\2<\/li>/')
                    ITEM=$(echo "$ITEM" | sed 's/^- /<li>/' | sed 's/^###.*/<\/ul><h3>&<\/h3><ul>/')
                    RELEASE_NOTES="${RELEASE_NOTES}${ITEM}"
                done <<< "$CHANGELOG_SECTION"
                RELEASE_NOTES="${RELEASE_NOTES}</ul>"
            fi
        fi
        if [ -z "$RELEASE_NOTES" ]; then
            RELEASE_NOTES="<p>$DESCRIPTION</p>"
        fi

        # Build new appcast: keep header up to -->, replace items with latest only
        TEMP_APPCAST="/tmp/vowrite-appcast-$$"
        sed -n '1,/-->/p' "$TARGET_APPCAST" > "$TEMP_APPCAST"
        cat >> "$TEMP_APPCAST" << APPCAST_EOF
    <item>
      <title>Vowrite $VERSION_NUM</title>
      <description><![CDATA[$RELEASE_NOTES]]></description>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$NEW_BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION_NUM</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <enclosure
        url="$DOWNLOAD_URL"
        type="application/octet-stream"
        $ED_SIGNATURE
        $ED_LENGTH
      />
    </item>
  </channel>
</rss>
APPCAST_EOF
        mv "$TEMP_APPCAST" "$TARGET_APPCAST"
        echo "  ✓ Appcast updated: $TARGET_APPCAST"
        echo "  ✓ Download URL: $DOWNLOAD_URL"
    fi
else
    echo "  ⚠️  sign_update not found at $SIGN_UPDATE"
    echo "  Run 'swift build' in $APP_DIR first to fetch Sparkle tools."
    echo "  Skipping appcast update."
fi

# --- Step 9: Git commit + tag ---
echo ""
echo "▶ Step 9: Git commit and tag..."
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

# --- Step 10: GitHub Release (interactive) ---
echo ""
echo "▶ Step 10: GitHub Release..."

if command -v gh &> /dev/null; then
    echo "  Create GitHub Release and upload DMG? (Y/n)"
    read -p "   " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        GH_FLAGS=""
        if $IS_BETA; then
            GH_FLAGS="--prerelease"
        fi

        # Extract release notes from CHANGELOG for the body
        GH_NOTES=""
        if [ -f "$CHANGELOG" ] && ! $IS_BETA; then
            GH_NOTES=$(sed -n "/## \[$VERSION_NUM\]/,/## \[/p" "$CHANGELOG" | sed '1d;$d')
        fi

        if [ -n "$GH_NOTES" ]; then
            echo "$GH_NOTES" | gh release create "$VERSION" "$DMG_PATH" \
                --repo "$GITHUB_REPO" \
                --title "Vowrite $VERSION — $DESCRIPTION" \
                --notes-file - \
                $GH_FLAGS
        else
            gh release create "$VERSION" "$DMG_PATH" \
                --repo "$GITHUB_REPO" \
                --title "Vowrite $VERSION — $DESCRIPTION" \
                --notes "$DESCRIPTION" \
                $GH_FLAGS
        fi

        echo "  ✓ GitHub Release created: https://github.com/$GITHUB_REPO/releases/tag/$VERSION"
    else
        echo "  Skipped. Create manually:"
        echo "  gh release create $VERSION $DMG_PATH --title \"Vowrite $VERSION — $DESCRIPTION\""
    fi
else
    echo "  ⚠️  gh CLI not installed. Create release manually:"
    echo "  gh release create $VERSION $DMG_PATH --title \"Vowrite $VERSION — $DESCRIPTION\""
fi

# --- Step 11: Summary ---
echo ""
echo "═══════════════════════════════════════"
echo "  ✅ Release $VERSION [$RELEASE_TYPE] complete!"
echo "═══════════════════════════════════════"
echo ""
echo "  DMG:     $DMG_PATH"
echo "  Size:    $(du -h "$DMG_PATH" | cut -f1)"
echo "  Build:   $NEW_BUILD"
echo ""
echo "  Next steps:"
echo "  1. Review:  git log --oneline -3 main"
echo "  2. Test:    open $DMG_PATH"
echo "  3. Push:    git push origin main --tags"
echo "  4. Verify:  curl -s https://vowrite.com/appcast.xml | head -5"
echo ""
if [[ "$RELEASE_TYPE" == "STABLE" ]]; then
    echo "  🌐 Website Track B (release sync) reminder:"
    echo "     • Bump version refs in docs/index.html + docs/pricing.html footer to $VERSION"
    echo "     • See ops/CHECKLIST_WEBSITE.md → Track B"
    echo "     • Validate: ops/scripts/website-check.sh"
    echo ""
fi
