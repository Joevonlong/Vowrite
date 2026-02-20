import Foundation
import SwiftData

@Model
final class DictationRecord {
    var id: UUID
    var rawTranscript: String
    var polishedText: String
    var duration: TimeInterval
    var detectedLanguage: String?
    var createdAt: Date

    init(rawTranscript: String, polishedText: String, duration: TimeInterval, detectedLanguage: String?) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.duration = duration
        self.detectedLanguage = detectedLanguage
        self.createdAt = Date()
    }
}
