import UIKit
import VowriteKit

final class iOSFeedback: FeedbackProvider {
    func playStartSound() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        SoundFeedback.playStart()
    }

    func playSuccessSound() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        SoundFeedback.playSuccess()
    }

    func playErrorSound() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        SoundFeedback.playError()
    }
}
