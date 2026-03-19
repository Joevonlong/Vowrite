import AVFoundation
import ApplicationServices
import VowriteKit

/// Implementation of PermissionProvider for macOS
final class MacPermissionProvider: PermissionProvider {
    func hasMicrophoneAccess() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func hasRequiredPermissions() -> Bool {
        hasMicrophoneAccess() && hasAccessibilityAccess()
    }

    func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        )
    }

    func requestAccessibilityAccess() async {
        AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
    }
}
