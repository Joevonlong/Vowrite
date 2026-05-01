#!/bin/bash
#
# Vowrite Website Validation
# Checks docs/ consistency before/after Track A/B/C commits.
# See ops/CHECKLIST_WEBSITE.md for the maintenance workflow.
#
# Exit codes:
#   0 — all green
#   1 — version drift (must fix)
#   2 — live URL broken (must fix)
#   3 — soft warning (>60 days stale). Non-blocking.
#
set -u

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOCS="$PROJECT_ROOT/docs"
KIT_VERSION_FILE="$PROJECT_ROOT/VowriteKit/Sources/VowriteKit/Version.swift"
INFO_PLIST="$PROJECT_ROOT/VowriteMac/Resources/Info.plist"
PRICING_HTML="$DOCS/pricing.html"
INDEX_HTML="$DOCS/index.html"

PASS=0
FAIL=0
WARN=0
EXIT_DRIFT=0
EXIT_LINK=0
EXIT_SOFT=0

pass() { printf "  \033[32m✅\033[0m %s\n" "$1"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m❌\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); }
warn() { printf "  \033[33m⚠️\033[0m  %s\n" "$1"; WARN=$((WARN+1)); }

echo "═══════════════════════════════════════"
echo "  Vowrite Website Check"
echo "═══════════════════════════════════════"

# ─────────────────────────────────────────────
# 1. Version-string consistency
# ─────────────────────────────────────────────
echo ""
echo "▶ Version-string consistency"

KIT_VER=$(grep -E 'static let current\s*=' "$KIT_VERSION_FILE" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/')
PLIST_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null)
JSONLD_VER=$(grep -E '"softwareVersion"' "$INDEX_HTML" 2>/dev/null | sed -E 's/.*"([0-9.]+)".*/\1/')
INDEX_FOOTER_VER=$(grep -E 'class="version[^"]*">v[0-9]' "$INDEX_HTML" 2>/dev/null | sed -E 's/.*v([0-9.]+).*/\1/' | head -1)
PRICING_FOOTER_VER=$(grep -E 'Last updated:.*v[0-9]' "$PRICING_HTML" 2>/dev/null | sed -E 's/.*v([0-9.]+).*/\1/')

echo "  VowriteKit/Version.swift     : ${KIT_VER:-MISSING}"
echo "  Info.plist CFBundleShort     : ${PLIST_VER:-MISSING}"
echo "  index.html JSON-LD           : ${JSONLD_VER:-MISSING}"
echo "  index.html visible footer    : ${INDEX_FOOTER_VER:-MISSING}"
echo "  pricing.html footer          : ${PRICING_FOOTER_VER:-MISSING}"

if [[ -z "$KIT_VER" ]]; then
    fail "Version.swift missing 'current' constant"
    EXIT_DRIFT=1
fi

# Truth = KIT_VER. Compare every other source against it.
check_match() {
    local label="$1" actual="$2"
    if [[ -z "$actual" ]]; then
        fail "$label is missing"
        EXIT_DRIFT=1
    elif [[ "$actual" == "$KIT_VER" ]]; then
        pass "$label matches Version.swift ($KIT_VER)"
    else
        fail "$label = $actual but Version.swift = $KIT_VER"
        EXIT_DRIFT=1
    fi
}

if [[ -n "$KIT_VER" ]]; then
    check_match "Info.plist" "$PLIST_VER"
    check_match "index.html JSON-LD" "$JSONLD_VER"
    check_match "index.html footer" "$INDEX_FOOTER_VER"
    check_match "pricing.html footer" "$PRICING_FOOTER_VER"
fi

# ─────────────────────────────────────────────
# 2. Live URL availability
# ─────────────────────────────────────────────
echo ""
echo "▶ Live URL check (vowrite.com)"

check_url() {
    local url="$1" label="$2"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 8 "$url" 2>/dev/null)
    if [[ "$code" == "200" ]]; then
        pass "$label → 200"
    else
        fail "$label → $code"
        EXIT_LINK=2
    fi
}

if command -v curl >/dev/null 2>&1; then
    check_url "https://vowrite.com/"            "/"
    check_url "https://vowrite.com/why"         "/why"
    check_url "https://vowrite.com/pricing"     "/pricing"
    check_url "https://vowrite.com/appcast.xml" "/appcast.xml"
else
    warn "curl unavailable — skipping live URL check"
fi

# ─────────────────────────────────────────────
# 3. Pricing freshness (>60 days warn)
# ─────────────────────────────────────────────
echo ""
echo "▶ Pricing freshness"

LAST_UPDATED_LINE=$(grep -E "Last updated:" "$PRICING_HTML" 2>/dev/null | head -1)
if [[ -z "$LAST_UPDATED_LINE" ]]; then
    fail "pricing.html has no 'Last updated:' footer"
    EXIT_DRIFT=1
else
    LAST_UPDATED_TEXT=$(echo "$LAST_UPDATED_LINE" | sed -E 's/.*Last updated: ([A-Za-z]+ [0-9]{4}).*/\1/')
    LAST_UPDATED_EPOCH=$(date -j -f "%B %Y" "$LAST_UPDATED_TEXT" "+%s" 2>/dev/null || echo 0)
    NOW_EPOCH=$(date "+%s")
    if [[ "$LAST_UPDATED_EPOCH" == "0" ]]; then
        warn "pricing.html: cannot parse 'Last updated' date '$LAST_UPDATED_TEXT'"
    else
        AGE_DAYS=$(( (NOW_EPOCH - LAST_UPDATED_EPOCH) / 86400 ))
        if [[ $AGE_DAYS -gt 60 ]]; then
            warn "pricing.html last audit was $AGE_DAYS days ago ($LAST_UPDATED_TEXT) — schedule Track A"
            EXIT_SOFT=3
        else
            pass "pricing.html audited $AGE_DAYS days ago ($LAST_UPDATED_TEXT)"
        fi
    fi
fi

# ─────────────────────────────────────────────
# 4. Nav consistency
# ─────────────────────────────────────────────
echo ""
echo "▶ Nav consistency"

for page in "$INDEX_HTML" "$DOCS/why.html" "$PRICING_HTML"; do
    name=$(basename "$page")
    if grep -q 'href="/pricing"' "$page" 2>/dev/null; then
        pass "$name has /pricing nav link"
    else
        fail "$name missing /pricing nav link"
        EXIT_DRIFT=1
    fi
    if grep -qE 'href="/why"' "$page" 2>/dev/null; then
        pass "$name has /why nav link"
    else
        fail "$name missing /why nav link"
        EXIT_DRIFT=1
    fi
done

# ─────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════"
echo "  Pass: $PASS · Fail: $FAIL · Warn: $WARN"
echo "═══════════════════════════════════════"

# Priority of exit codes: drift > link > soft.
if [[ $EXIT_DRIFT -ne 0 ]]; then
    exit 1
fi
if [[ $EXIT_LINK -ne 0 ]]; then
    exit 2
fi
if [[ $EXIT_SOFT -ne 0 ]]; then
    exit 3
fi
exit 0
