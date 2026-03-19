import VowriteKit

/// On iOS the overlay is handled by SwiftUI views directly (RecordingView),
/// so this provider is a no-op stub. The UI reacts to DictationEngine.state changes.
final class iOSOverlayProvider: OverlayProvider {
    func showRecording() {}
    func showProcessing() {}
    func hide() {}
    func updateLevel(_ level: Float) {}
}
