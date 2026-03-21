import UIKit
import VowriteKit

final class KeyboardFeedback: FeedbackProvider {
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func playStartSound() {
        impactMedium.impactOccurred()
    }

    func playSuccessSound() {
        notification.notificationOccurred(.success)
    }

    func playErrorSound() {
        notification.notificationOccurred(.error)
    }
}
