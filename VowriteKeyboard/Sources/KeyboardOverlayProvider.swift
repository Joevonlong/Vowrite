import VowriteKit

/// No-op overlay provider for keyboard extension.
/// All state is displayed directly in the keyboard UI.
final class KeyboardOverlayProvider: OverlayProvider {
    func showRecording() {}
    func showProcessing() {}
    func updateLevel(_ level: Float) {}
    func hide() {}
}
