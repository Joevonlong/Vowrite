#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_ROOT="$(mktemp -d /tmp/vowrite-text-injector-test.XXXXXX)"
PACKAGE_DIR="$TEMP_ROOT/PermissionHarness"
trap 'rm -rf "$TEMP_ROOT"' EXIT
mkdir -p "$PACKAGE_DIR/Sources/PermissionHarness"

cp "$PROJECT_ROOT/VowriteMac/Sources/Platform/MacTextInjector.swift" \
    "$PACKAGE_DIR/Sources/PermissionHarness/MacTextInjector.swift"
sed -i '' '/^import VowriteKit$/d' "$PACKAGE_DIR/Sources/PermissionHarness/MacTextInjector.swift"
cp "$PROJECT_ROOT/VowriteKit/Sources/VowriteKit/Protocols/TextOutputProvider.swift" \
    "$PACKAGE_DIR/Sources/PermissionHarness/TextOutputProvider.swift"

cat > "$PACKAGE_DIR/Package.swift" <<EOF
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PermissionHarness",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "PermissionHarness")]
)
EOF

cat > "$PACKAGE_DIR/Sources/PermissionHarness/CorrectionMonitorStub.swift" <<'EOF'
import ApplicationServices
import Foundation

final class CorrectionMonitor {
    static let shared = CorrectionMonitor()
    static var captureCount = 0
    static var startCount = 0

    func captureElement() -> AXUIElement? {
        Self.captureCount += 1
        return nil
    }

    func start(element: AXUIElement, injectedText: String) {
        Self.startCount += 1
    }
}
EOF

cat > "$PACKAGE_DIR/Sources/PermissionHarness/main.swift" <<'EOF'
import AppKit

let semaphore = DispatchSemaphore(value: 0)
Task { @MainActor in
    let pasteboard = NSPasteboard.general
    let clipboardChangeCount = pasteboard.changeCount
    let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
    var trustChecks = 0
    var activationAttempts = 0

    let injector = MacTextInjector(
        accessibilityTrustProvider: {
            trustChecks += 1
            return false
        },
        activationOverride: {
            activationAttempts += 1
            return false
        }
    )
    let delivered = await injector.output(text: "VOWRITE_PERMISSION_TEST_SENTINEL")

    guard !delivered else { fatalError("Denied Accessibility was reported as delivered") }
    guard trustChecks == 1 else { fatalError("Accessibility trust was not checked exactly once") }
    guard activationAttempts == 0 else { fatalError("Target activation ran after permission denial") }
    guard CorrectionMonitor.captureCount == 0, CorrectionMonitor.startCount == 0 else {
        fatalError("Correction monitoring ran after permission denial")
    }
    guard pasteboard.changeCount == clipboardChangeCount else {
        fatalError("Clipboard changed after permission denial")
    }
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmostPID else {
        fatalError("Frontmost application changed after permission denial")
    }

    print("MAC_TEXT_INJECTOR_PERMISSION_OK no_activation no_clipboard_change no_monitoring")
    semaphore.signal()
}

while semaphore.wait(timeout: .now() + .milliseconds(20)) == .timedOut {
    RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
}
EOF

(
    cd "$PACKAGE_DIR"
    swift run PermissionHarness
)
