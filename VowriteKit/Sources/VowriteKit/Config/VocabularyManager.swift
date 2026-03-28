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
