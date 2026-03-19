import AVFoundation
import VowriteKit

final class iOSPermissionManager: PermissionProvider {
    func hasMicrophoneAccess() -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func hasRequiredPermissions() -> Bool {
        hasMicrophoneAccess()
    }
}
