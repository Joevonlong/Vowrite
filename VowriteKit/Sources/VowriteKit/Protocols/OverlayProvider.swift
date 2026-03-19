import Foundation

/// Platform-specific recording overlay — macOS uses NSWindow float, iOS uses Sheet
public protocol OverlayProvider {
    func showRecording()
    func showProcessing()
    func hide()
    func updateLevel(_ level: Float)
}
