import VowriteKit

final class MacFeedback: FeedbackProvider {
    func playStartSound() {
        SoundFeedback.playStart()
    }

    func playSuccessSound() {
        SoundFeedback.playSuccess()
    }

    func playErrorSound() {
        SoundFeedback.playError()
    }
}
