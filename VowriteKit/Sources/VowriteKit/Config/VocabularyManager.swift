import Foundation

@MainActor
public final class VocabularyManager: ObservableObject {
    public static let shared = VocabularyManager()

    nonisolated private static let storageKey = "personalVocabulary"
    nonisolated private static let seededKey = "vocabularySeeded"

    /// Example words seeded on first launch to demonstrate the feature.
    private static let seedWords = [
        "Vowrite", "GPT", "Whisper", "OpenAI", "DeepSeek",
        "macOS", "Sonoma", "SwiftUI",
    ]

    @Published public var words: [String] {
        didSet { save() }
    }

    private init() {
        self.words = VowriteStorage.defaults.stringArray(forKey: Self.storageKey) ?? []
        seedIfNeeded()
    }

    private func seedIfNeeded() {
        guard !VowriteStorage.defaults.bool(forKey: Self.seededKey) else { return }
        VowriteStorage.defaults.set(true, forKey: Self.seededKey)
        if words.isEmpty {
            words = Self.seedWords
        }
    }

    /// Reload all data from UserDefaults.
    /// Used by iOS keyboard extension: user may have changed config in Container App.
    public func reload() {
        self.words = VowriteStorage.defaults.stringArray(forKey: Self.storageKey) ?? []
    }

    public func add(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !words.contains(trimmed) else { return }
        words.append(trimmed)
    }

    public func addBulk(_ input: String) {
        let newWords = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for word in newWords where !word.isEmpty && !words.contains(word) {
            words.append(word)
        }
    }

    public func remove(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
    }

    public func remove(_ word: String) {
        words.removeAll { $0 == word }
    }

    private func save() {
        VowriteStorage.defaults.set(words, forKey: Self.storageKey)
    }

    // MARK: - CSV Import / Export (F-074)

    /// Represents the result of a CSV import operation.
    public struct ImportResult: Equatable {
        public let imported: Int
        public let duplicates: Int
    }

    /// Returns a UTF-8 BOM-prefixed CSV string with one word per line, sorted
    /// alphabetically, plus a comment header line. Suitable for Excel on Windows.
    public func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        let header = "# Vowrite vocabulary export — \(formatter.string(from: Date()))\n"
        let body = words.sorted().joined(separator: "\n")
        return "\u{FEFF}" + header + body + "\n"
    }

    /// Imports words from a single-column CSV string.
    /// - Lines starting with `#` are treated as comments and skipped.
    /// - Blank lines are skipped.
    /// - A leading UTF-8 BOM is stripped automatically.
    /// - Returns a result describing how many words were imported vs. skipped as duplicates.
    @discardableResult
    public func importCSV(_ csv: String) -> ImportResult {
        var imported = 0
        var duplicates = 0
        var input = csv
        if input.hasPrefix("\u{FEFF}") { input.removeFirst() }
        for raw in input.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            if words.contains(line) {
                duplicates += 1
                continue
            }
            add(line)
            imported += 1
        }
        return ImportResult(imported: imported, duplicates: duplicates)
    }

    /// Thread-safe read of all vocabulary words from UserDefaults.
    nonisolated public static var storedWords: [String] {
        VowriteStorage.defaults.stringArray(forKey: storageKey) ?? []
    }

    /// Build a prompt string from vocabulary for Whisper API guidance.
    /// Thread-safe: reads directly from UserDefaults.
    nonisolated public static var whisperPrompt: String? {
        guard let words = VowriteStorage.defaults.stringArray(forKey: storageKey), !words.isEmpty else {
            return nil
        }
        return words.joined(separator: ", ")
    }
}
