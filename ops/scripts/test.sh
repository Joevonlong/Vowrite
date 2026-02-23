#!/bin/bash
#
# Voxa Automated Test Script
# Checks build, security, and basic functionality
#
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_DIR="$PROJECT_ROOT/VoxaApp"
PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════"
echo "  Voxa Test Suite"
echo "═══════════════════════════════════════"

# --- Build Test ---
echo ""
echo "▶ Build"

cd "$APP_DIR"
if swift build 2>&1 | grep -q "Build complete"; then
    pass "Debug build succeeds"
else
    fail "Debug build failed"
fi

if swift build -c release 2>&1 | grep -q "Build complete"; then
    pass "Release build succeeds"
else
    fail "Release build failed"
fi

# --- Code Quality ---
echo ""
echo "▶ Code Quality"

WARNING_COUNT=$(swift build 2>&1 | grep -c "warning:" || true)
if [ "$WARNING_COUNT" -eq 0 ]; then
    pass "No compiler warnings"
else
    warn "$WARNING_COUNT compiler warning(s)"
fi

TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX" "$APP_DIR" --include="*.swift" | grep -v ".build/" | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -eq 0 ]; then
    pass "No TODO/FIXME markers"
else
    warn "$TODO_COUNT TODO/FIXME marker(s) found"
fi

# --- Security ---
echo ""
echo "▶ Security"

# Check for hardcoded keys
if grep -rn 'sk-[a-zA-Z0-9]\{10,\}' "$APP_DIR" --include="*.swift" | grep -v ".build/" | grep -v "placeholder\|example\|Placeholder" | grep -q .; then
    fail "Possible hardcoded API key found!"
else
    pass "No hardcoded API keys"
fi

# Check gitignore
if grep -q "\.env" "$PROJECT_ROOT/.gitignore" && grep -q "Secrets" "$PROJECT_ROOT/.gitignore"; then
    pass ".gitignore covers secrets"
else
    warn ".gitignore may not cover all secret files"
fi

# Check git history for leaked keys
if git -C "$PROJECT_ROOT" log -p 2>/dev/null | grep -q 'sk-[a-zA-Z0-9]\{20,\}'; then
    fail "API key found in git history!"
else
    pass "No API keys in git history"
fi

# Check temp files cleanup
if ls /tmp/voxa_* 2>/dev/null | grep -q .; then
    warn "Temp audio files exist in /tmp"
else
    pass "No leftover temp files"
fi

# --- App Bundle ---
echo ""
echo "▶ App Bundle"

if [ -f "$APP_DIR/Voxa.app/Contents/Info.plist" ]; then
    pass "Info.plist exists"
else
    fail "Info.plist missing"
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_DIR/Voxa.app/Contents/Info.plist" 2>/dev/null)
if [ "$BUNDLE_ID" = "com.voxa.app" ]; then
    pass "Bundle ID: $BUNDLE_ID"
else
    fail "Unexpected bundle ID: $BUNDLE_ID"
fi

if [ -f "$APP_DIR/Resources/Voxa.entitlements" ]; then
    pass "Entitlements file exists"
else
    fail "Entitlements file missing"
fi

# --- File Structure ---
echo ""
echo "▶ File Structure"

REQUIRED_FILES=(
    "App/VoxaApp.swift"
    "App/AppState.swift"
    "Core/STT/WhisperService.swift"
    "Core/AI/AIPolishService.swift"
    "Core/TextInjection/TextInjector.swift"
    "Core/Audio/AudioEngine.swift"
    "Core/Hotkey/HotkeyManager.swift"
    "Core/Keychain/KeychainHelper.swift"
    "Package.swift"
)

for f in "${REQUIRED_FILES[@]}"; do
    if [ -f "$APP_DIR/$f" ]; then
        pass "$f"
    else
        fail "$f missing!"
    fi
done

# --- Summary ---
echo ""
echo "═══════════════════════════════════════"
TOTAL=$((PASS + FAIL + WARN))
echo "  Results: $PASS passed, $FAIL failed, $WARN warnings (of $TOTAL checks)"
echo "═══════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
    echo "  ❌ TESTS FAILED — fix issues before releasing"
    exit 1
else
    echo "  ✅ All critical checks passed"
    exit 0
fi
