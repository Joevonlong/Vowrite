#!/bin/bash
# Check tracked launch metadata; optionally validate an assembled app before signing.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP=""
if [ "$#" -ne 0 ]; then
    if [ "$#" -ne 2 ] || [ "$1" != "--app" ]; then
        echo "Usage: $0 [--app /path/to/Vowrite.app]" >&2
        exit 2
    fi
    APP="$2"
fi

check_plist() {
    local plist="$1" executable
    executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null || true)
    if [ "$executable" != "Vowrite" ]; then
        echo "ERROR: $plist must declare CFBundleExecutable = Vowrite (found: ${executable:-missing})" >&2
        return 1
    fi
}

check_plist "$ROOT/VowriteMac/Resources/Info.plist"
check_plist "$ROOT/VowriteMac/Vowrite.app/Contents/Info.plist"
if [ -n "$APP" ]; then
    check_plist "$APP/Contents/Info.plist"
    if [ ! -f "$APP/Contents/MacOS/Vowrite" ] || [ ! -x "$APP/Contents/MacOS/Vowrite" ]; then
        echo "ERROR: $APP/Contents/MacOS/Vowrite is missing or not executable" >&2
        exit 1
    fi
fi
echo "Mac app launch metadata OK${APP:+; executable present}"
