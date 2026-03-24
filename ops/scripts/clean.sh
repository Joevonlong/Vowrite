#!/bin/bash
#
# Vowrite Build Clean Script
#
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MAC_DIR="$PROJECT_ROOT/VowriteMac"
KIT_DIR="$PROJECT_ROOT/VowriteKit"

echo "▶ Cleaning Vowrite build artifacts..."

# VowriteMac build cache
if [ -d "$MAC_DIR/.build" ]; then
    rm -rf "$MAC_DIR/.build"
    echo "  ✓ Removed VowriteMac/.build/"
fi

# VowriteKit build cache
if [ -d "$KIT_DIR/.build" ]; then
    rm -rf "$KIT_DIR/.build"
    echo "  ✓ Removed VowriteKit/.build/"
fi

# Code signature (will be regenerated)
if [ -d "$MAC_DIR/Vowrite.app/Contents/_CodeSignature" ]; then
    rm -rf "$MAC_DIR/Vowrite.app/Contents/_CodeSignature"
    echo "  ✓ Removed _CodeSignature/"
fi

# Binary (will be rebuilt)
if [ -f "$MAC_DIR/Vowrite.app/Contents/MacOS/Vowrite" ]; then
    rm "$MAC_DIR/Vowrite.app/Contents/MacOS/Vowrite"
    echo "  ✓ Removed binary"
fi

# Temp audio files
TEMP_COUNT=$(ls /tmp/vowrite_* 2>/dev/null | wc -l | tr -d ' ')
if [ "$TEMP_COUNT" -gt 0 ]; then
    rm -f /tmp/vowrite_*
    echo "  ✓ Removed $TEMP_COUNT temp audio file(s)"
fi

# Release DMGs (optional, ask first)
if [ -d "$PROJECT_ROOT/releases" ] && [ "$(ls -A "$PROJECT_ROOT/releases" 2>/dev/null)" ]; then
    echo ""
    echo "  Found release DMGs in releases/:"
    ls -lh "$PROJECT_ROOT/releases/"
    echo ""
    read -p "  Delete release DMGs? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_ROOT/releases"
        echo "  ✓ Removed releases/"
    fi
fi

echo ""
echo "✅ Clean complete."
