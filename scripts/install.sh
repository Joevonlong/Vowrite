#!/bin/bash
# ── Vowrite Installer ─────────────────────────────────────
# Quit running Vowrite → copy to Applications → relaunch
# Double-click or run from Terminal

APP_NAME="Vowrite"
APP_PATH="/Applications/${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="${SCRIPT_DIR}/${APP_NAME}.app"

if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ ${APP_NAME}.app not found next to this script."
    exit 1
fi

echo "📦 Installing ${APP_NAME}..."

# Quit if running
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "⏹  Quitting running ${APP_NAME}..."
    pkill -x "$APP_NAME"
    sleep 2
fi

# Copy to Applications
echo "📁 Copying to /Applications..."
rm -rf "$APP_PATH"
cp -R "$SOURCE_APP" "$APP_PATH"

# Launch
echo "🚀 Launching ${APP_NAME}..."
open "$APP_PATH"

echo "✅ Done!"
