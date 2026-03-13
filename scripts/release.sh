#!/bin/bash
set -euo pipefail

# ══════════════════════════════════════════════════════════
# Vowrite Release Script
# ══════════════════════════════════════════════════════════
# One-command release: build → sign → package → commit → tag → push → GitHub Release
#
# Usage:
#   ./scripts/release.sh <version> [--dry-run]
#
# Examples:
#   ./scripts/release.sh 0.1.8.0
#   ./scripts/release.sh 0.2.0.0 --dry-run
#
# Prerequisites:
#   - gh CLI authenticated (gh auth status)
#   - Xcode command line tools (swift, codesign, hdiutil)
#   - Clean git working tree (no uncommitted changes)
# ══════════════════════════════════════════════════════════

APP_NAME="Vowrite"
APP_PACKAGE="VowriteApp"
APP_BUNDLE="${APP_PACKAGE}/Vowrite.app"
VERSION_FILE="${APP_PACKAGE}/Core/Version.swift"
PLIST_FILE="${APP_PACKAGE}/Resources/Info.plist"
CHANGELOG="CHANGELOG.md"
DMG_DIR="releases"

# ── Parse arguments ───────────────────────────────────────
NEW_VERSION="${1:-}"
DRY_RUN=false
if [[ "${2:-}" == "--dry-run" ]]; then DRY_RUN=true; fi

if [ -z "$NEW_VERSION" ]; then
    echo "Usage: ./scripts/release.sh <version> [--dry-run]"
    echo "  version format: MAJOR.MINOR.PATCH.BUILD (e.g. 0.1.8.0)"
    exit 1
fi

# Validate version format
if ! echo "$NEW_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "❌ Invalid version format: $NEW_VERSION"
    echo "   Expected: MAJOR.MINOR.PATCH.BUILD (e.g. 0.1.8.0)"
    exit 1
fi

CURRENT_VERSION=$(grep 'static let current' "$VERSION_FILE" | sed 's/.*"\(.*\)".*/\1/')
DMG_NAME="${APP_NAME}-v${NEW_VERSION}.dmg"
DMG_PATH="${DMG_DIR}/${DMG_NAME}"
TAG="v${NEW_VERSION}"

echo "══════════════════════════════════════════════════════"
echo "  ${APP_NAME} Release"
echo "  ${CURRENT_VERSION} → ${NEW_VERSION}"
if $DRY_RUN; then echo "  ⚠️  DRY RUN — no changes will be made"; fi
echo "══════════════════════════════════════════════════════"
echo ""

# ── Pre-flight checks ─────────────────────────────────────
echo "🔍 Pre-flight checks..."

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ gh CLI not found. Install: brew install gh"
    exit 1
fi

# Check git is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Working tree is dirty. Commit or stash changes first."
    git status --short
    exit 1
fi

# Check tag doesn't already exist
if git tag -l "$TAG" | grep -q "$TAG"; then
    echo "❌ Tag $TAG already exists."
    exit 1
fi

# Check CHANGELOG has entry for this version
if ! grep -q "\[${NEW_VERSION}\]" "$CHANGELOG"; then
    echo "⚠️  No CHANGELOG entry for ${NEW_VERSION}."
    echo "   Add a ## [${NEW_VERSION}] section to CHANGELOG.md first."
    exit 1
fi

echo "   ✅ gh CLI available"
echo "   ✅ Git working tree clean"
echo "   ✅ Tag $TAG is new"
echo "   ✅ CHANGELOG has entry for $NEW_VERSION"
echo ""

if $DRY_RUN; then
    echo "🏁 Dry run complete. No changes made."
    exit 0
fi

# ── Step 1: Update version numbers ────────────────────────
echo "📝 Step 1: Updating version to ${NEW_VERSION}..."
sed -i '' "s/static let current = \".*\"/static let current = \"${NEW_VERSION}\"/" "$VERSION_FILE"
# Update CFBundleShortVersionString in Info.plist
sed -i '' "/<key>CFBundleShortVersionString<\/key>/{n;s/<string>.*<\/string>/<string>${NEW_VERSION}<\/string>/;}" "$PLIST_FILE"

# ── Step 2: Build release binary ──────────────────────────
echo "🔨 Step 2: Building release binary..."
cd "$APP_PACKAGE"
swift build -c release 2>&1 | tail -3
cd ..

# Copy release binary into app bundle
cp "${APP_PACKAGE}/.build/arm64-apple-macosx/release/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "$PLIST_FILE" "${APP_BUNDLE}/Contents/Info.plist"

# ── Step 3: Code sign (with entitlements) ─────────────────
ENTITLEMENTS="${APP_PACKAGE}/Resources/Vowrite.entitlements"
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "❌ Entitlements file not found: $ENTITLEMENTS"
    exit 1
fi

# F-024: Use stable self-signed cert for persistent permissions
SIGN_KEYCHAIN="$HOME/Library/Keychains/vowrite-signing.keychain-db"
if [ -f "$SIGN_KEYCHAIN" ]; then
    security unlock-keychain -p "vowrite" "$SIGN_KEYCHAIN" 2>/dev/null
    SIGN_IDENTITY="Vowrite Developer"
    KEYCHAIN_FLAG="--keychain ${SIGN_KEYCHAIN}"
    echo "🔏 Step 3: Code signing (self-signed certificate)..."
else
    SIGN_IDENTITY="-"
    KEYCHAIN_FLAG=""
    echo "🔏 Step 3: Code signing (ad-hoc — permissions may reset on update)..."
    echo "   💡 Tip: Set up self-signed cert to keep permissions across updates."
    echo "   See ops/SIGNING.md for instructions."
fi
codesign --force --deep --sign "${SIGN_IDENTITY}" ${KEYCHAIN_FLAG} --entitlements "$ENTITLEMENTS" "${APP_BUNDLE}"
codesign --verify "${APP_BUNDLE}"

# ── Step 4: Create DMG ────────────────────────────────────
echo "💿 Step 4: Creating DMG..."
STAGING=$(mktemp -d)/${APP_NAME}
mkdir -p "$STAGING"
cp -R "${APP_BUNDLE}" "${STAGING}/${APP_NAME}.app"
# Re-sign the copy with entitlements (ensures DMG copy is properly signed)
codesign --force --deep --sign "${SIGN_IDENTITY}" ${KEYCHAIN_FLAG} --entitlements "$ENTITLEMENTS" "${STAGING}/${APP_NAME}.app"
ln -s /Applications "${STAGING}/Applications"
# Include install script for easy updates (quit → replace → relaunch)
cp scripts/install.sh "${STAGING}/Install ${APP_NAME}.command"
chmod +x "${STAGING}/Install ${APP_NAME}.command"

mkdir -p "$DMG_DIR"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH" > /dev/null

rm -rf "$(dirname "$STAGING")"

# Verify DMG
DMG_SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
echo "   Created: $DMG_PATH ($DMG_SIZE)"

# ── Step 5: Git commit + tag ──────────────────────────────
echo "🏷️  Step 5: Committing and tagging..."
git add -A
git commit -m "release: v${NEW_VERSION}"
git tag -a "$TAG" -m "Release ${TAG}"

# ── Step 6: Push ──────────────────────────────────────────
echo "🚀 Step 6: Pushing to GitHub..."
git push
git push --tags

# ── Step 7: Create GitHub Release ─────────────────────────
echo "📦 Step 7: Creating GitHub Release..."

# Extract release notes from CHANGELOG (everything between this version and the next ## header)
RELEASE_NOTES=$(awk "/^## \[${NEW_VERSION}\]/{found=1; next} /^## \[/{if(found) exit} found{print}" "$CHANGELOG")

# Add install instructions
RELEASE_NOTES="${RELEASE_NOTES}

---

### 📦 Installation (macOS)

1. Download \`${DMG_NAME}\`
2. Open the DMG and drag \`${APP_NAME}.app\` to **Applications**
3. **First launch:** Right-click the app → **Open** → click **Open** in the dialog
   - This is only needed once (the app is ad-hoc signed, not yet Apple notarized)
   - If you still see a \"damaged\" error: \`xattr -cr /Applications/${APP_NAME}.app\`"

gh release create "$TAG" \
    "$DMG_PATH" \
    --title "${TAG}" \
    --notes "$RELEASE_NOTES"

# ── Done ──────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  ✅ ${APP_NAME} ${TAG} released!"
echo ""
echo "  📦 DMG:     ${DMG_PATH} (${DMG_SIZE})"
echo "  🏷️  Tag:     ${TAG}"
echo "  🔗 Release: https://github.com/Joevonlong/Vowrite/releases/tag/${TAG}"
echo "══════════════════════════════════════════════════════"
