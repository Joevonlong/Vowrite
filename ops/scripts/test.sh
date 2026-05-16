#!/bin/bash
#
# Vowrite Automated Test Script
# Checks build, security, and basic functionality
#
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KIT_DIR="$PROJECT_ROOT/VowriteKit"
MAC_DIR="$PROJECT_ROOT/VowriteMac"
PASS=0
FAIL=0
WARN=0

pass() { echo "  ✅ $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ $1"; FAIL=$((FAIL+1)); }
warn() { echo "  ⚠️  $1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════"
echo "  Vowrite Test Suite"
echo "═══════════════════════════════════════"

# --- Build Test ---
echo ""
echo "▶ Build — VowriteKit (Core)"

cd "$KIT_DIR"
if swift build 2>&1 | grep -q "Build complete"; then
    pass "VowriteKit debug build succeeds"
else
    fail "VowriteKit debug build failed"
fi

echo ""
echo "▶ Tests — VowriteKit"
if (cd "$KIT_DIR" && swift test 2>&1 | tail -10 | grep -qE "Test Suite 'All tests' passed"); then
    pass "VowriteKit unit tests pass"
else
    fail "VowriteKit unit tests failed"
fi

echo ""
echo "▶ Build — VowriteMac"

cd "$MAC_DIR"
if swift build 2>&1 | grep -q "Build complete"; then
    pass "VowriteMac debug build succeeds"
else
    fail "VowriteMac debug build failed"
fi

if swift build -c release 2>&1 | grep -q "Build complete"; then
    pass "VowriteMac release build succeeds"
else
    fail "VowriteMac release build failed"
fi

# --- Code Quality ---
echo ""
echo "▶ Code Quality"

WARNING_COUNT=$(cd "$MAC_DIR" && swift build 2>&1 | grep -c "warning:" || true)
if [ "$WARNING_COUNT" -eq 0 ]; then
    pass "No compiler warnings"
else
    warn "$WARNING_COUNT compiler warning(s)"
fi

TODO_COUNT=$(grep -rn "TODO\|FIXME\|HACK\|XXX" "$KIT_DIR/Sources" "$MAC_DIR/Sources" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
if [ "$TODO_COUNT" -eq 0 ]; then
    pass "No TODO/FIXME markers"
else
    warn "$TODO_COUNT TODO/FIXME marker(s) found"
fi

# --- Security ---
echo ""
echo "▶ Security"

# Check for hardcoded keys
if grep -rn 'sk-[a-zA-Z0-9]\{10,\}' "$KIT_DIR/Sources" "$MAC_DIR/Sources" --include="*.swift" | grep -v "placeholder\|example\|Placeholder" | grep -q .; then
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
if ls /tmp/vowrite_* 2>/dev/null | grep -q .; then
    warn "Temp audio files exist in /tmp"
else
    pass "No leftover temp files"
fi

# --- App Bundle ---
echo ""
echo "▶ App Bundle (VowriteMac)"

if [ -f "$MAC_DIR/Vowrite.app/Contents/Info.plist" ]; then
    pass "Info.plist exists"
else
    fail "Info.plist missing"
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$MAC_DIR/Vowrite.app/Contents/Info.plist" 2>/dev/null)
if [ "$BUNDLE_ID" = "com.vowrite.app" ]; then
    pass "Bundle ID: $BUNDLE_ID"
else
    fail "Unexpected bundle ID: $BUNDLE_ID"
fi

if [ -f "$MAC_DIR/Resources/Vowrite.entitlements" ]; then
    pass "Entitlements file exists"
else
    fail "Entitlements file missing"
fi

# --- F-076: iOS Keyboard Dictation Mic Suppression ---
echo ""
echo "▶ iOS Keyboard — F-076 Dictation Mic Suppression"

KB_PLIST="$PROJECT_ROOT/VowriteKeyboard/Info.plist"
LANG_VAL=$(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionAttributes:PrimaryLanguage" "$KB_PLIST" 2>/dev/null || echo MISSING)
ASCII_VAL=$(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionAttributes:IsASCIICapable" "$KB_PLIST" 2>/dev/null || echo MISSING)
if [ "$LANG_VAL" = "mul" ] && [ "$ASCII_VAL" = "true" ]; then
    pass "F-076 plist mic-suppression intact (PrimaryLanguage=mul, IsASCIICapable=true)"
else
    fail "F-076 regressed: PrimaryLanguage='$LANG_VAL' IsASCIICapable='$ASCII_VAL' (must be mul/true) — re-exposes the system dictation mic"
fi

# --- File Structure ---
echo ""
echo "▶ File Structure — VowriteKit"

KIT_REQUIRED=(
    "Sources/VowriteKit/Audio/AudioEngine.swift"
    "Sources/VowriteKit/Engine/DictationEngine.swift"
    "Sources/VowriteKit/Services/WhisperService.swift"
    "Sources/VowriteKit/Services/AIPolishService.swift"
    "Sources/VowriteKit/Config/APIConfig.swift"
    "Sources/VowriteKit/Config/KeyVault.swift"
    "Package.swift"
)

for f in "${KIT_REQUIRED[@]}"; do
    if [ -f "$KIT_DIR/$f" ]; then
        pass "Kit: $f"
    else
        fail "Kit: $f missing!"
    fi
done

echo ""
echo "▶ File Structure — VowriteMac"

MAC_REQUIRED=(
    "Sources/App/VowriteApp.swift"
    "Sources/App/AppState.swift"
    "Sources/Platform/MacTextInjector.swift"
    "Sources/Platform/MacHotkeyManager.swift"
    "Sources/Platform/MacFeedback.swift"
    "Package.swift"
)

for f in "${MAC_REQUIRED[@]}"; do
    if [ -f "$MAC_DIR/$f" ]; then
        pass "Mac: $f"
    else
        fail "Mac: $f missing!"
    fi
done

# --- Legacy Check ---
echo ""
echo "▶ Legacy Cleanup"

if [ -d "$PROJECT_ROOT/VowriteApp" ]; then
    fail "VowriteApp (legacy) directory still exists — should be removed"
else
    pass "VowriteApp (legacy) removed ✓"
fi

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
