#!/bin/bash
# generate-icon.sh — Convert a single PNG icon to macOS .icns and install to app bundle
#
# Usage:
#   ./scripts/generate-icon.sh [source image path]
#
# Default source: Resources/AppIcon-source.png (1024x1024 PNG)
#
set -e
cd "$(dirname "$0")/.."

SOURCE="${1:-Resources/AppIcon-source.png}"
ICONSET_DIR="build/Vowrite.iconset"
ICNS_OUTPUT="Vowrite.app/Contents/Resources/AppIcon.icns"

if [ ! -f "$SOURCE" ]; then
  echo "❌ Source image not found: $SOURCE"
  echo ""
  echo "Please place a 1024x1024 PNG icon at:"
  echo "  VowriteApp/Resources/AppIcon-source.png"
  echo ""
  echo "Or specify a path: ./scripts/generate-icon.sh /path/to/icon.png"
  exit 1
fi

# Check image dimensions
WIDTH=$(sips -g pixelWidth "$SOURCE" | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE" | tail -1 | awk '{print $2}')
if [ "$WIDTH" -lt 1024 ] || [ "$HEIGHT" -lt 1024 ]; then
  echo "⚠️  Warning: Source image is ${WIDTH}x${HEIGHT}, 1024x1024 recommended for best results"
fi

echo "🎨 Generating icon from $SOURCE..."

# Clean and create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all macOS-required sizes
sips -z 16 16       "$SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32       "$SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64       "$SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128     "$SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256     "$SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512     "$SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024   "$SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# Convert to .icns
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_OUTPUT"

# Clean up temporary files
rm -rf "$ICONSET_DIR"

echo "✅ Icon generated: $ICNS_OUTPUT"
echo "   Next build.sh run will automatically include this icon."
