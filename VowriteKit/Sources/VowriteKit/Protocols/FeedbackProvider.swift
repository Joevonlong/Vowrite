import Foundation

/// Platform-specific feedback — macOS uses NSSound, iOS uses Haptics
public protocol FeedbackProvider {
    func playStartSound()
    func playSuccessSound()
    func playErrorSound()
}
