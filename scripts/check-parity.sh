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

# ── 1. Key VowriteKit classes/protocols that should be used on both platforms ──
# Format: "SymbolName|Description|mac-only-ok"
# mac-only-ok: if "yes", skip iOS check (platform-specific features)
SYMBOLS=(
    "PromptContext|Prompt context variable expansion ({selected}/{clipboard})|no"
    "SpeculativePolish|Pre-built Polish API request for faster response|no"
    "SoundFeedback|Audio feedback tones (start/success/error)|no"
    "ModeEditorSheet|Mode/Scene creation and editing UI|no"
    "DesignTokens\|VW\.|Design tokens (VW.Spacing, VW.Colors, etc.)|no"
    "HotkeyManager\|MacHotkeyManager|Global hotkey registration (Carbon)|yes"
    "MacTextInjector|CGEvent keystroke injection|yes"
    "MacOverlayController|Floating recording overlay window|yes"
    "MacUpdateManager\|SPUUpdater|Sparkle auto-update|yes"
    "MenuBarView|macOS menu bar extra|yes"
)

echo "Checking key symbol usage across platforms..."
echo ""
printf "%-30s %-8s %-8s %-10s %s\n" "Symbol" "Mac" "iOS" "Keyboard" "Status"
echo "─────────────────────────────────────────────────────────────────────────"

for entry in "${SYMBOLS[@]}"; do
    IFS='|' read -r symbol desc mac_only <<< "$entry"

    mac_used="-"
    ios_used="-"
    kbd_used="-"
    status=""

    if symbol_used_in "$symbol" "$MAC"; then mac_used="✓"; fi
    if symbol_used_in "$symbol" "$IOS"; then ios_used="✓"; fi
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

# Key integration points to verify
PATTERNS=(
    "promptContext|PromptContext capture/usage in recording flow"
    "speculativePolish\|SpeculativePolish()|Speculative Polish in recording flow"
    "SoundFeedback.warmUp\|SoundFeedback.play|SoundFeedback initialization and playback"
    "ModeManager.shared.*addMode\|ModeManager.shared.*updateMode\|ModeManager.shared.*deleteMode|Mode CRUD operations"
    "totalDictationTime\|totalWords\|totalDictations|Stats display (all 3 metrics)"
    "VW.Spacing\|VW.Colors\|VW.Radius|Design token usage"
)

for entry in "${PATTERNS[@]}"; do
    IFS='|' read -r pattern desc <<< "$entry"
    # Get the last field as description (handles patterns with | in them)
    desc="${entry##*|}"
    # Get everything before the last | as the pattern
    pattern="${entry%|*}"

    mac_count=$(grep -rc "$pattern" "$MAC" --include="*.swift" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
    ios_count=$(grep -rc "$pattern" "$IOS" --include="*.swift" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')

    if [[ "$mac_count" -gt 0 && "$ios_count" -eq 0 ]]; then
        echo -e "  ${RED}⚠${NC} $desc"
        echo "     Mac: $mac_count references, iOS: 0 references"
        ((gaps++)) || true
    fi
done

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
