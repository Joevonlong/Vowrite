import Foundation

enum HallucinationFilter {
    /// Known Whisper hallucination phrases (lowercased, trimmed).
    /// Sources: OpenAI community reports, openai/whisper#1057, production blocklists.
    private static let blocklist: Set<String> = [
        // English
        "thank you", "thank you.", "thank you!", "thank you for watching",
        "thank you for watching.", "thank you for watching!", "thanks for watching",
        "thanks for watching.", "thanks for watching!", "thanks for listening",
        "thanks for listening.",
        // Subtitles boilerplate
        "subtitles by the amara.org community",
        "subtitles by", "subtitles made by",
        // French
        "sous-titres réalisés para la communauté d'amara.org",
        "sous-titres par la communauté d'amara.org",
        "merci.",
        // German
        "untertitel von", "vielen dank.",
        // Common single-word hallucinations
        "you", "the", "bye", "bye.", "bye-bye", "bye-bye.",
        "okay", "okay.", "ok", "ok.",
        "yeah", "yeah.", "yes", "yes.", "no", "no.",
        "hmm", "hmm.", "huh", "huh.",
        "ah", "ah.", "oh", "oh.", "uh", "uh.",
        // Blank audio markers
        "[blank_audio]", "[ blank_audio ]", "[silence]", "[ silence ]",
        // YouTube / podcast boilerplate
        "please subscribe", "please subscribe.", "like and subscribe",
        "like and subscribe.", "please like and subscribe.",
        "subscribe to my channel", "subscribe to my channel.",
        // Chinese/Japanese single-char hallucinations
        "谢谢", "谢谢。", "谢谢！",
        // Korean
        "감사합니다", "감사합니다.",
        // Music markers
        "♪", "♪♪", "♫",
        // Ellipsis / dots
        "...", "…",
    ]

    /// Returns true if the transcript appears to be a Whisper hallucination
    /// rather than genuine speech.
    static func isHallucination(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()

        // 1. Exact match against known hallucination phrases
        if blocklist.contains(lowered) {
            return true
        }

        // 2. Repeated-token pattern: same short phrase repeated 2+ times
        //    e.g. "Thank you. Thank you. Thank you."
        if isRepeatedPhrase(lowered) {
            return true
        }

        return false
    }

    /// Detects text that is just the same short phrase repeated.
    /// e.g. "thank you. thank you. thank you." or "you you you you"
    private static func isRepeatedPhrase(_ text: String) -> Bool {
        // Split by common sentence delimiters
        let segments = text
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "！", with: ".")
            .replacingOccurrences(of: "!", with: ".")
            .split(separator: ".")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard segments.count >= 2 else {
            // Try space-separated tokens for "you you you you" pattern
            let words = text.split(separator: " ").map(String.init)
            if words.count >= 3, Set(words).count == 1 {
                return true
            }
            return false
        }

        // All segments are the same phrase
        let unique = Set(segments)
        if unique.count == 1 {
            // Check that the repeated phrase is short (likely hallucination, not real speech)
            if let phrase = unique.first, phrase.count <= 30 {
                return true
            }
        }

        return false
    }
}
