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

    public init(rawTranscript: String, polishedText: String, duration: TimeInterval, detectedLanguage: String?) {
        self.id = UUID()
        self.rawTranscript = rawTranscript
        self.polishedText = polishedText
        self.duration = duration
        self.detectedLanguage = detectedLanguage
        self.createdAt = Date()
    }
}
