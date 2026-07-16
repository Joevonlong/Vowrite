import Foundation

/// A single text replacement rule.
/// `trigger`: what the STT might produce (wrong text, e.g. "伏莱特")
/// `replacement`: what it should be (correct text, e.g. "Vowrite")
public struct ReplacementRule: Codable, Identifiable, Equatable, Sendable {
    /// Where a rule came from (F-080). Drives the Personalization summary
    /// card and "Clear learned data" — which only ever touches `.learned`.
    public enum Source: String, Codable, Equatable, Sendable {
        /// Created by the user through a Corrections UI (Mac VocabularyPage,
        /// iOS PersonalizationView).
        case manual
        /// Auto-created by `CorrectionMonitor` (Mac, F-053) from an observed
        /// paste correction.
        case learned
    }

    public let id: UUID
    public var trigger: String
    public var replacement: String
    public var source: Source
    /// When this rule was created. `nil` for rules persisted before F-080
    /// (legacy data) — excluded from "recently learned" but still counted.
    public var createdAt: Date?

    public init(
        id: UUID = UUID(),
        trigger: String,
        replacement: String,
        source: Source = .manual,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.source = source
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, trigger, replacement, source, createdAt
    }

    /// Custom decode: `source` and `createdAt` are new (F-080) fields.
    /// Legacy persisted JSON (pre-F-080) has neither key — decode those as
    /// `.manual` / `nil` rather than throwing, so existing rules survive
    /// the upgrade unchanged (zero migration breakage, per spec).
    /// `encode(to:)` stays compiler-synthesized (all properties + CodingKeys
    /// already line up), so it is not redeclared here.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        trigger = try container.decode(String.self, forKey: .trigger)
        replacement = try container.decode(String.self, forKey: .replacement)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
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

    nonisolated private static let storageKey = StorageKeys.vowriteReplacements

    @Published public var rules: [ReplacementRule] {
        didSet { save() }
    }

    private init() {
        self.rules = Self.loadFromDefaults()
    }

    // MARK: - CRUD

    /// - Parameter source: `.manual` (default) for user-entered rules (Mac
    ///   VocabularyPage, iOS PersonalizationView). `CorrectionMonitor` (F-053/
    ///   F-080) passes `.learned` for rules it auto-creates from observed
    ///   corrections. Existing call sites are source-compatible.
    public func add(trigger: String, replacement: String, source: ReplacementRule.Source = .manual) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty, !trimmedReplacement.isEmpty else { return }
        // Reject duplicate triggers — including when a machine-learned guess
        // would collide with an existing (manual or learned) rule; the
        // existing mapping wins rather than being silently overwritten.
        guard !rules.contains(where: { $0.trigger.lowercased() == trimmedTrigger.lowercased() }) else { return }
        rules.append(ReplacementRule(
            trigger: trimmedTrigger,
            replacement: trimmedReplacement,
            source: source,
            createdAt: Date()
        ))
    }

    public func update(_ rule: ReplacementRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        // Reject if another rule (different id) already has this trigger
        let trimmedTrigger = rule.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        if rules.contains(where: { $0.id != rule.id && $0.trigger.lowercased() == trimmedTrigger.lowercased() }) {
            return
        }
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

    // MARK: - Learning (F-080)

    /// Master switch for automatic learning. While `false`, `CorrectionMonitor`
    /// (Mac) must not observe pastes or create `.learned` rules — checked
    /// fresh on every recording (see `CorrectionMonitor.captureElement()`),
    /// so flipping this takes effect on the next dictation, not just at launch.
    ///
    /// Deliberately reuses the `"autoLearnCorrections"` key already written
    /// by the legacy `@AppStorage("autoLearnCorrections")` toggle in Mac's
    /// GeneralPage: on macOS `VowriteStorage.defaults` IS `UserDefaults.standard`
    /// (see `VowriteStorage.swift`), so the two toggles read/write the exact
    /// same stored bool — no dual state, no migration needed. iOS has no
    /// legacy toggle, so the App Group key starts fresh there. Default ON.
    nonisolated public static var learningEnabled: Bool {
        get {
            guard VowriteStorage.defaults.object(forKey: StorageKeys.autoLearnCorrections) != nil else {
                return true
            }
            return VowriteStorage.defaults.bool(forKey: StorageKeys.autoLearnCorrections)
        }
        set {
            VowriteStorage.defaults.set(newValue, forKey: StorageKeys.autoLearnCorrections)
        }
    }

    /// Number of `.learned` rules currently stored.
    public var learnedCount: Int { Self.learnedCount(in: rules) }

    /// Up to `limit` most recently learned rules, newest first. Legacy
    /// `.learned` rules with a `nil` createdAt (should not occur going
    /// forward, but decoded defensively) are excluded from this list while
    /// still counting toward `learnedCount`.
    public func recentLearned(limit: Int = 3) -> [ReplacementRule] {
        Self.recentLearned(in: rules, limit: limit)
    }

    /// Deletes every `.learned` rule, leaving `.manual` rules untouched.
    /// Irreversible — callers must confirm with the user first. The iOS
    /// keyboard extension picks up the change through its existing
    /// `ReplacementManager.shared.reload()` call in `reloadConfiguration()`.
    public func clearLearned() {
        rules = Self.removingLearned(from: rules)
    }

    // MARK: - Learning: pure helpers (unit-tested directly, no MainActor/UserDefaults involved)

    nonisolated static func learnedCount(in rules: [ReplacementRule]) -> Int {
        rules.filter { $0.source == .learned }.count
    }

    nonisolated static func recentLearned(in rules: [ReplacementRule], limit: Int = 3) -> [ReplacementRule] {
        rules
            .filter { $0.source == .learned }
            .compactMap { rule -> (rule: ReplacementRule, date: Date)? in
                guard let date = rule.createdAt else { return nil }
                return (rule, date)
            }
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map(\.rule)
    }

    nonisolated static func removingLearned(from rules: [ReplacementRule]) -> [ReplacementRule] {
        rules.filter { $0.source != .learned }
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

        // Pure ASCII triggers: use lookaround to prevent substring matches within ASCII words
        // e.g. "AI" should not match inside "FAIR", but SHOULD match in "这个AI很好"
        // We can't use \b because it doesn't work at ASCII↔CJK boundaries.
        // Instead: negative lookbehind/lookahead for ASCII word characters only.
        let isPureASCII = trigger.unicodeScalars.allSatisfy { $0.isASCII }
        if isPureASCII {
            return "(?<![a-zA-Z0-9_])" + joined + "(?![a-zA-Z0-9_])"
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
