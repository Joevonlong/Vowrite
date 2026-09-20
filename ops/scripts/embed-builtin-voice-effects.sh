#!/bin/bash
set -euo pipefail

SOURCE_BUNDLE="${1:?Usage: embed-builtin-voice-effects.sh <source-bundle> <app-bundle>}"
APP_BUNDLE="${2:?Usage: embed-builtin-voice-effects.sh <source-bundle> <app-bundle>}"
DESTINATION="$APP_BUNDLE/Contents/Resources/VowriteMac_BuiltinVoiceEffects.bundle"

if [ ! -d "$SOURCE_BUNDLE" ]; then
    echo "❌ Built-in Voice Bar resource bundle not found: $SOURCE_BUNDLE" >&2
    exit 1
fi

for RESOURCE in catalog.json host.html host.js voice-effects.js; do
    if [ ! -f "$SOURCE_BUNDLE/$RESOURCE" ]; then
        echo "❌ Required built-in Voice Bar resource is missing: $RESOURCE" >&2
        exit 1
    fi
done

mkdir -p "$APP_BUNDLE/Contents/Resources"
ditto "$SOURCE_BUNDLE" "$DESTINATION"
echo "  ✓ Embedded built-in Voice Bar resources: $DESTINATION"
