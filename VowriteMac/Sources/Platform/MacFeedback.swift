import AppKit
import VowriteKit

final class MacFeedback: FeedbackProvider {
    func playStartSound() {
        NSSound(named: .init("Tink"))?.play()
    }

    func playSuccessSound() {
        NSSound(named: .init("Tink"))?.play()
    }

    func playErrorSound() {
        NSSound(named: .init("Basso"))?.play()
    }
}
