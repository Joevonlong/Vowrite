import Foundation

@MainActor
final class VocabularyManager: ObservableObject {
    static let shared = VocabularyManager()

    nonisolated(unsafe) private static let storageKey = "personalVocabulary"

    @Published var words: [String] {
        didSet { save() }
    }

    private init() {
        self.words = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
    }

    func add(_ word: String) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !words.contains(trimmed) else { return }
        words.append(trimmed)
    }

    func addBulk(_ input: String) {
        let newWords = input.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for word in newWords where !word.isEmpty && !words.contains(word) {
            words.append(word)
        }
    }

    func remove(at offsets: IndexSet) {
        words.remove(atOffsets: offsets)
    }

    func remove(_ word: String) {
        words.removeAll { $0 == word }
    }

    private func save() {
        UserDefaults.standard.set(words, forKey: Self.storageKey)
    }

    /// Build a prompt string from vocabulary for Whisper API guidance.
    /// Thread-safe: reads directly from UserDefaults.
    nonisolated static var whisperPrompt: String? {
        guard let words = UserDefaults.standard.stringArray(forKey: storageKey), !words.isEmpty else {
            return nil
        }
        return words.joined(separator: ", ")
    }
}
