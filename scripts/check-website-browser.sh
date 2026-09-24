#!/usr/bin/env bash
# Serve docs/ on localhost and run the Playwright website suite.
#
#   scripts/check-website-browser.sh                 layout matrix, axe, interactions and motion
#   scripts/check-website-browser.sh --interactions  interactions and motion only
#   scripts/check-website-browser.sh --design DIR    side-by-side screenshots against an Open Design website/ folder
#   scripts/check-website-browser.sh --serve         keep a local preview running until interrupted
#   scripts/check-website-browser.sh --content       save the static content check as content-check.json
#   scripts/check-website-browser.sh --evidence DIR ...   write reports and screenshots to DIR (must come first)
#
# Needs Node, Python 3, Playwright and axe-core. Set WEBSITE_NODE_PATH to override module discovery;
# evidence goes to WEBSITE_EVIDENCE (default /tmp/vowrite-website-evidence).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${WEBSITE_PORT:-8781}"
DESIGN_PORT="${WEBSITE_DESIGN_PORT:-8782}"
if [[ "${1:-}" == "--evidence" ]]; then
    [[ -n "${2:-}" ]] || { echo "check-website-browser: --evidence needs a directory" >&2; exit 2; }
    WEBSITE_EVIDENCE="$2"; shift 2
fi
export WEBSITE_EVIDENCE="${WEBSITE_EVIDENCE:-/tmp/vowrite-website-evidence}"
mkdir -p "$WEBSITE_EVIDENCE"

module_dir() {
    local name="$1" candidate
    for candidate in \
        ${WEBSITE_NODE_PATH:+${WEBSITE_NODE_PATH//:/ }} \
        "$HOME"/.cache/codex-runtimes/*/dependencies/node/node_modules \
        "$HOME"/.npm/_npx/*/node_modules \
        /tmp/*/node_modules /private/tmp/*/node_modules; do
        if [[ -d "$candidate/$name" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

PLAYWRIGHT_DIR="$(module_dir playwright)" || { echo "check-website-browser: Playwright not found; set WEBSITE_NODE_PATH" >&2; exit 2; }
AXE_DIR="$(module_dir axe-core)" || { echo "check-website-browser: axe-core not found; set WEBSITE_NODE_PATH" >&2; exit 2; }
export NODE_PATH="$PLAYWRIGHT_DIR:$AXE_DIR"

PIDS=()
cleanup() { for pid in "${PIDS[@]:-}"; do [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT INT TERM

serve() {
    local port="$1" dir="$2" log="$3"
    python3 -m http.server "$port" --bind 127.0.0.1 --directory "$dir" >"$log" 2>&1 &
    PIDS+=("$!")
    for _ in $(seq 1 50); do
        curl -fsS -o /dev/null "http://127.0.0.1:$port/" 2>/dev/null && return 0
        sleep 0.1
    done
    echo "check-website-browser: server on port $port did not start" >&2
    exit 2
}

serve "$PORT" "$ROOT/docs" "$WEBSITE_EVIDENCE/server.log"
export WEBSITE_URL="http://127.0.0.1:$PORT"

ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --design)
            [[ -d "${2:-}" ]] || { echo "check-website-browser: --design needs the Open Design website/ folder" >&2; exit 2; }
            serve "$DESIGN_PORT" "$2" "$WEBSITE_EVIDENCE/design-server.log"
            export WEBSITE_DESIGN_URL="http://127.0.0.1:$DESIGN_PORT"
            ARGS+=(--design); shift 2 ;;
        --content)
            python3 "$ROOT/scripts/check-website.py" --json >"$WEBSITE_EVIDENCE/content-check.json"
            echo "Content check: $WEBSITE_EVIDENCE/content-check.json"; exit 0 ;;
        --serve)
            echo "Preview: $WEBSITE_URL/index.html (Ctrl-C to stop)"
            wait; exit 0 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done

node "$ROOT/scripts/test-website.cjs" ${ARGS[@]+"${ARGS[@]}"}
