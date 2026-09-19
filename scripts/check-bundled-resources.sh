#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMBED="$PROJECT_ROOT/ops/scripts/embed-kit-resources.sh"
SOURCE="$PROJECT_ROOT/VowriteKit/Sources/VowriteKit/Resources"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/vowrite-bundle-check.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

SOURCE_BUNDLE="$TEMP_ROOT/VowriteKit_VowriteKit.bundle"
APP_BUNDLE="$TEMP_ROOT/Vowrite.app"
mkdir -p "$SOURCE_BUNDLE"
cp "$SOURCE/providers.json" "$SOURCE_BUNDLE/providers.json"
cp "$SOURCE/Prompts/polish.system.md" "$SOURCE_BUNDLE/polish.system.md"
cp "$SOURCE/Prompts/translate.system.md" "$SOURCE_BUNDLE/translate.system.md"

"$EMBED" "$SOURCE_BUNDLE" "$APP_BUNDLE"
DEST="$APP_BUNDLE/Contents/Resources/VowriteKit_VowriteKit.bundle"
test -f "$DEST/providers.json"
test -f "$DEST/polish.system.md"
test -f "$DEST/translate.system.md"
test ! -e "$APP_BUNDLE/VowriteKit_VowriteKit.bundle"

if "$EMBED" "$TEMP_ROOT/missing.bundle" "$APP_BUNDLE" >/dev/null 2>&1; then
    echo "❌ Missing source bundle unexpectedly succeeded" >&2
    exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
    echo "❌ swiftc is required for the standalone resource proof" >&2
    exit 1
fi

mkdir -p "$APP_BUNDLE/Contents/MacOS"
cat > "$TEMP_ROOT/BundleModuleShim.swift" <<'SWIFT'
import Foundation

extension Bundle {
    static var module: Bundle {
        fatalError("Bundle.module fallback was evaluated")
    }
}
SWIFT
cat > "$TEMP_ROOT/probe.swift" <<'SWIFT'
import Foundation

@main
struct Probe {
    static func main() throws {
        let bundle = VowriteResources.bundle
        for path in [
            bundle.url(forResource: "providers", withExtension: "json"),
            bundle.url(forResource: "polish.system", withExtension: "md"),
            bundle.url(forResource: "translate.system", withExtension: "md")
        ] {
            guard let path else { throw NSError(domain: "ResourceProbe", code: 2) }
            _ = try String(contentsOf: path, encoding: .utf8)
        }
    }
}
SWIFT
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.vowrite.resource-probe</string></dict></plist>
PLIST
swiftc \
    "$PROJECT_ROOT/VowriteKit/Sources/VowriteKit/Config/VowriteResources.swift" \
    "$TEMP_ROOT/BundleModuleShim.swift" \
    "$TEMP_ROOT/probe.swift" \
    -o "$APP_BUNDLE/Contents/MacOS/resource-probe"
codesign --force --sign - "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"
"$APP_BUNDLE/Contents/MacOS/resource-probe"

echo "✅ Embedded bundle, missing-source failure, app-root hygiene, and standalone lookup passed"
