import Foundation
import SwiftData

@Model
public final class DictationRecord {
    public var id: UUID
    public var rawTranscript: String
    public var polishedText: String
    public var duration: TimeInterval
    public var detectedLanguage: String?
    public var createdAt: Date
    // F-063: marks records produced by Translate mode (additive SwiftData migration)
    public var wasTranslation: Bool?

    public init(rawTranscript: String, polishedText: String, duration: TimeInterval, detectedLanguage: String?, wasTranslation: Bool? = nil) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.duration = duration
        self.detectedLanguage = detectedLanguage
        self.createdAt = Date()
        self.wasTranslation = wasTranslation
    }
}
