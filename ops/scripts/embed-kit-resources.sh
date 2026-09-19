#!/bin/bash
set -euo pipefail

SOURCE_BUNDLE="${1:?Usage: embed-kit-resources.sh <source-bundle> <app-bundle>}"
APP_BUNDLE="${2:?Usage: embed-kit-resources.sh <source-bundle> <app-bundle>}"
DESTINATION="$APP_BUNDLE/Contents/Resources/VowriteKit_VowriteKit.bundle"

if [ ! -d "$SOURCE_BUNDLE" ]; then
    echo "❌ VowriteKit resource bundle not found: $SOURCE_BUNDLE" >&2
    exit 1
fi

for RESOURCE in providers.json polish.system.md translate.system.md; do
    if [ -f "$SOURCE_BUNDLE/$RESOURCE" ] || [ -f "$SOURCE_BUNDLE/Prompts/$RESOURCE" ]; then
        continue
    fi
    echo "❌ Required VowriteKit resource is missing: $RESOURCE" >&2
    exit 1
done

mkdir -p "$APP_BUNDLE/Contents/Resources"
rm -rf "$DESTINATION"
cp -R "$SOURCE_BUNDLE" "$DESTINATION"
echo "  ✓ Embedded VowriteKit resources: $DESTINATION"
