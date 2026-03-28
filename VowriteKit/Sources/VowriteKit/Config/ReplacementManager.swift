import Foundation

/// A single text replacement rule.
/// `trigger`: what the STT might produce (wrong text, e.g. "伏莱特")
/// `replacement`: what it should be (correct text, e.g. "Vowrite")
public struct ReplacementRule: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var trigger: String
    public var replacement: String

    public init(id: UUID = UUID(), trigger: String, replacement: String) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
    }
}

/// Manages user-defined text replacement rules for post-STT and post-LLM correction.
///
/// Two use cases covered by the same mechanism:
/// - **Correction:** "伏莱特" → "Vowrite" (fix STT misrecognition)
/// - **Snippet:** "我的邮箱" → "hello@example.com" (expand shortcuts)
///
/// Rules are stored in App Group shared UserDefaults so iOS keyboard extension can access them.
@MainActor
public final class ReplacementManager: ObservableObject {
    public static let shared = ReplacementManager()

    nonisolated private static let storageKey = "vowriteReplacements"

    @Published public var rules: [ReplacementRule] {
        didSet { save() }
    }

    private init() {
        self.rules = Self.loadFromDefaults()
    }

    // MARK: - CRUD

    public func add(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else { return }
        // Reject duplicate triggers
        guard !rules.contains(where: { $0.trigger.lowercased() == trimmedTrigger.lowercased() }) else { return }
        rules.append(ReplacementRule(trigger: trimmedTrigger, replacement: trimmedReplacement))
    }

    public func update(_ rule: ReplacementRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
    }

    public func remove(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
    }

    public func remove(_ rule: ReplacementRule) {
        rules.removeAll { $0.id == rule.id }
    }

    /// Reload from shared UserDefaults. Used by iOS keyboard extension after config changes.
    public func reload() {
        self.rules = Self.loadFromDefaults()
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            VowriteStorage.defaults.set(data, forKey: Self.storageKey)
        }
    }

    nonisolated private static func loadFromDefaults() -> [ReplacementRule] {
        guard let data = VowriteStorage.defaults.data(forKey: storageKey),
              let rules = try? JSONDecoder().decode([ReplacementRule].self, from: data)
        else { return [] }
        return rules
    }

    // MARK: - Text Replacement Engine

    /// Apply all replacement rules to text. Thread-safe: reads directly from UserDefaults.
    /// Rules are sorted by trigger length descending (long match first) to prevent
    /// shorter triggers from interfering with longer ones.
    nonisolated public static func apply(to text: String) -> String {
        let rules = loadFromDefaults()
        guard !rules.isEmpty else { return text }

        // Sort by trigger length descending — longer triggers match first
        let sorted = rules.sorted { $0.trigger.count > $1.trigger.count }

        var result = text
        for rule in sorted {
            let pattern = buildFlexPattern(rule.trigger)
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: NSRegularExpression.escapedTemplate(for: rule.replacement)
                )
            }
        }
        return result
    }

    /// Build a vocabulary list for LLM prompt injection.
    /// Returns deduplicated correct terms (replacement values + VocabularyManager words).
    /// Only includes the *correct* spellings — the LLM doesn't need the full mapping table.
    nonisolated public static var llmVocabularyHint: String? {
        let rules = loadFromDefaults()
        let replacementTerms = Set(rules.map(\.replacement))
        let vocabWords = Set(VocabularyManager.storedWords)
        let combined = replacementTerms.union(vocabWords)
        guard !combined.isEmpty else { return nil }
        return combined.sorted().joined(separator: ", ")
    }

    // MARK: - Flex Pattern Engine

    /// Builds a regex pattern that allows optional whitespace between CJK/ASCII boundaries.
    /// "我的Gmail邮箱" matches "我的 Gmail 邮箱", "我的Gmail 邮箱", etc.
    /// Pure ASCII triggers get word boundary markers (\b) to prevent substring false positives
    /// (e.g. "AI" should not match inside "FAIR").
    nonisolated private static func buildFlexPattern(_ trigger: String) -> String {
        let words = trigger.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return NSRegularExpression.escapedPattern(for: trigger) }

        let wordPatterns = words.map { word -> String in
            var clusters: [String] = []
            var current = ""
            var lastType: CharType?
            for ch in word {
                let type = charType(ch)
                if let last = lastType, last != type {
                    if !current.isEmpty {
                        clusters.append(NSRegularExpression.escapedPattern(for: current))
                    }
                    current = String(ch)
                } else {
                    current.append(ch)
                }
                lastType = type
            }
            if !current.isEmpty {
                clusters.append(NSRegularExpression.escapedPattern(for: current))
            }
            return clusters.joined(separator: "\\s*")
        }

        let joined = wordPatterns.joined(separator: "\\s+")

        // Pure ASCII triggers: add word boundaries to prevent substring matches
        // e.g. "AI" should not match inside "FAIR", "claude code" should not match "claude coder"
        let isPureASCII = trigger.unicodeScalars.allSatisfy { $0.isASCII }
        if isPureASCII {
            return "\\b" + joined + "\\b"
        }
        return joined
    }

    private enum CharType { case cjk, ascii, other }

    nonisolated private static func charType(_ ch: Character) -> CharType {
        guard let scalar = ch.unicodeScalars.first else { return .other }
        let v = scalar.value
        // CJK Unified Ideographs + common CJK ranges + fullwidth forms
        if (0x4E00...0x9FFF).contains(v) || (0x3400...0x4DBF).contains(v) ||
           (0x3000...0x303F).contains(v) || (0xFF00...0xFFEF).contains(v) {
            return .cjk
        }
        if ch.isASCII { return .ascii }
        return .other
    }
}
