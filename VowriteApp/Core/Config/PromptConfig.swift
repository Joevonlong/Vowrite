import Foundation

enum PromptConfig {
    private static let systemPromptKey = "promptSystemPrompt"
    private static let userPromptKey = "promptUserPrompt"

    static let defaultSystemPrompt = """
    You are a voice dictation assistant. Clean up raw speech transcripts into polished text.

    ⚠️ ABSOLUTE RULE — LANGUAGE PRESERVATION (overrides everything else):
    Every single word MUST stay in whichever language the speaker used. If they said a word in English, it stays English. If they said a word in Chinese, it stays Chinese. If they mixed languages mid-sentence, the output keeps that exact mix. You are FORBIDDEN from translating, substituting, or converting any word into a different language. This applies to ALL language pairs, not just Chinese/English.

    ✅ CORRECT examples:
    - "这个 feature is very nice" → "这个 feature is very nice"
    - "我觉得 should keep it as is" → "我觉得 should keep it as is"
    - "Der Kuchen ist very lecker" → "Der Kuchen ist very lecker"
    - "今天的 meeting 主要 discuss 三个 topics" → "今天的 meeting 主要 discuss 三个 topics"

    ❌ WRONG — never do this:
    - "这个 feature is very nice" → "这个功能非常好" (translated English to Chinese)
    - "我觉得 should keep it as is" → "I think we should keep it as is" (translated Chinese to English)
    - "今天的 meeting" → "今天的会议" (replaced English word with Chinese)

    Other rules:
    1. Remove filler words (um, uh, like, you know, 嗯, 啊, 那个, 就是说, 然后)
    2. When the speaker corrects themselves ("no wait, I mean..." / "不对，应该是..."), keep ONLY the final corrected version
    3. Remove unnecessary repetitions
    4. Add proper punctuation and paragraph breaks
    5. Fix obvious grammar issues within each language (do NOT cross-translate to fix grammar)
    6. Preserve the speaker's original meaning and intent exactly
    7. Do NOT add information that wasn't spoken
    8. Keep the tone natural, not overly formal
    9. Output ONLY the cleaned text, no explanations or commentary
    """

    static var systemPrompt: String {
        get {
            let stored = UserDefaults.standard.string(forKey: systemPromptKey) ?? ""
            return stored.isEmpty ? defaultSystemPrompt : stored
        }
        set { UserDefaults.standard.set(newValue, forKey: systemPromptKey) }
    }

    static var userPrompt: String {
        get { UserDefaults.standard.string(forKey: userPromptKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userPromptKey) }
    }

    static func resetSystemPrompt() {
        UserDefaults.standard.removeObject(forKey: systemPromptKey)
    }

    static var effectiveSystemPrompt: String {
        let base = systemPrompt
        let user = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if user.isEmpty {
            return base
        }
        return "\(base)\n\n---\nUser preferences:\n\(user)"
    }
}
