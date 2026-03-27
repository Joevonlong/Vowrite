#!/bin/bash
# check-parity.sh — Detect iOS-macOS feature parity gaps
#
# Scans VowriteKit symbols used by VowriteMac but missing from VowriteIOS/VowriteKeyboard.
# Run manually or in CI: ./scripts/check-parity.sh
#
# Exit codes:
#   0 = no gaps found
#   1 = parity gaps detected (review report)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KIT="$REPO_ROOT/VowriteKit/Sources/VowriteKit"
MAC="$REPO_ROOT/VowriteMac/Sources"
IOS="$REPO_ROOT/VowriteIOS/Sources"
KBD="$REPO_ROOT/VowriteKeyboard/Sources"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "═══════════════════════════════════════════════════"
echo "  Vowrite iOS-macOS Feature Parity Check"
echo "═══════════════════════════════════════════════════"
echo ""

gaps=0

# ── Helper: check if a symbol is used in a directory ──
symbol_used_in() {
    local symbol="$1"
    local dir="$2"
    grep -rl "$symbol" "$dir" --include="*.swift" >/dev/null 2>&1
}

# ── Helper: check if used in Mac (VowriteMac + VowriteKit shared code) ──
symbol_used_on_mac() {
    local symbol="$1"
    symbol_used_in "$symbol" "$MAC" || symbol_used_in "$symbol" "$KIT"
}

# ── Helper: check if used on iOS (VowriteIOS + VowriteKeyboard + VowriteKit shared code) ──
symbol_used_on_ios() {
    local symbol="$1"
    symbol_used_in "$symbol" "$IOS" || symbol_used_in "$symbol" "$KBD"
}

# ── 1. Key VowriteKit classes/protocols that should be used on both platforms ──
# Format: "SymbolName|Description|mac-only-ok"
# mac-only-ok: if "yes", skip iOS check (platform-specific features)
SYMBOLS=(
    "PromptContext::Prompt context variable expansion::no"
    "SpeculativePolish::Pre-built Polish API request::no"
    "SoundFeedback::Audio feedback tones::no"
    "ModeEditorSheet::Mode/Scene creation and editing UI::no"
    "VW\.::Design tokens (VW.Spacing, VW.Colors)::no"
    "MacHotkeyManager::Global hotkey (Carbon)::yes"
    "MacTextInjector::CGEvent keystroke injection::yes"
    "MacOverlayController::Floating recording overlay::yes"
    "SPUUpdater::Sparkle auto-update::yes"
    "MenuBarView::macOS menu bar extra::yes"
)

echo "Checking key symbol usage across platforms..."
echo ""
printf "%-30s %-8s %-8s %-10s %s\n" "Symbol" "Mac" "iOS" "Keyboard" "Status"
echo "─────────────────────────────────────────────────────────────────────────"

for entry in "${SYMBOLS[@]}"; do
    IFS='::' read -r symbol _ desc _ mac_only <<< "$entry"

    mac_used="-"
    ios_used="-"
    kbd_used="-"
    status=""

    if symbol_used_on_mac "$symbol"; then mac_used="✓"; fi
    if symbol_used_on_ios "$symbol"; then ios_used="✓"; fi
    if symbol_used_in "$symbol" "$KBD"; then kbd_used="✓"; fi

    if [[ "$mac_only" == "yes" ]]; then
        status="${GREEN}mac-only (OK)${NC}"
    elif [[ "$mac_used" == "✓" && "$ios_used" == "-" && "$kbd_used" == "-" ]]; then
        status="${RED}⚠ MISSING on iOS${NC}"
        ((gaps++))
    elif [[ "$mac_used" == "✓" && "$ios_used" == "✓" ]]; then
        status="${GREEN}OK${NC}"
    elif [[ "$mac_used" == "-" ]]; then
        status="${YELLOW}not used on Mac${NC}"
    else
        status="${GREEN}OK${NC}"
    fi

    printf "%-30s %-8s %-8s %-10s " "$symbol" "$mac_used" "$ios_used" "$kbd_used"
    echo -e "$status"
done

echo ""

# ── 2. Check VowriteKit public types/functions referenced by Mac but not iOS ──
echo "Scanning VowriteKit public API usage patterns..."
echo ""

# Check specific integration patterns
check_pattern() {
    local pattern="$1"
    local desc="$2"

    local mac_count ios_count
    mac_count=$( (grep -rEc "$pattern" "$MAC" --include="*.swift" 2>/dev/null || true) | awk -F: '{s+=$2} END {print s+0}')
    ios_count=$( (grep -rEc "$pattern" "$IOS" --include="*.swift" 2>/dev/null || true) | awk -F: '{s+=$2} END {print s+0}')

    if [[ "$mac_count" -gt 0 && "$ios_count" -eq 0 ]]; then
        echo -e "  ${RED}⚠${NC} $desc"
        echo "     Mac: $mac_count refs, iOS: 0 refs"
        ((gaps++)) || true
    fi
}

# These patterns check iOS-specific integration (not shared DictationEngine code)
check_pattern "SoundFeedback\.(warmUp|play)" "SoundFeedback initialization and playback"
check_pattern "ModeManager.shared.*(addMode|updateMode|deleteMode)" "Mode CRUD operations (UI)"
check_pattern "VW\.(Spacing|Colors|Radius)" "Design token usage in views"

echo ""

# ── Summary ──
echo "═══════════════════════════════════════════════════"
if [[ "$gaps" -gt 0 ]]; then
    echo -e "  ${RED}Found $gaps parity gap(s)${NC}"
    echo "  Review the items above and decide if iOS needs them."
    echo ""
    echo "  Features that DON'T need iOS parity:"
    echo "    - MenuBar, Hotkey, Sparkle Update, MLX Server"
    echo "    - CGEvent text injection, floating overlay window"
    echo "═══════════════════════════════════════════════════"
    exit 1
else
    echo -e "  ${GREEN}No parity gaps found ✓${NC}"
    echo "═══════════════════════════════════════════════════"
    exit 0
fi
