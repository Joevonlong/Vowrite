import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
    case auto = "auto"
    case en = "en"
    case zhHans = "zh"
    case zhHant = "zh-TW"
    case ja = "ja"
    case ko = "ko"
    case de = "de"
    case fr = "fr"
    case es = "es"
    case it = "it"
    case pt = "pt"
    case ru = "ru"
    case ar = "ar"
    case hi = "hi"
    case th = "th"
    case vi = "vi"
    case nl = "nl"
    case pl = "pl"
    case sv = "sv"
    case tr = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .en: return "English"
        case .zhHans: return "Chinese (Simplified)"
        case .zhHant: return "Chinese (Traditional)"
        case .ja: return "Japanese"
        case .ko: return "Korean"
        case .de: return "German"
        case .fr: return "French"
        case .es: return "Spanish"
        case .it: return "Italian"
        case .pt: return "Portuguese"
        case .ru: return "Russian"
        case .ar: return "Arabic"
        case .hi: return "Hindi"
        case .th: return "Thai"
        case .vi: return "Vietnamese"
        case .nl: return "Dutch"
        case .pl: return "Polish"
        case .sv: return "Swedish"
        case .tr: return "Turkish"
        }
    }

    /// Whisper API language code (ISO 639-1). nil for auto-detect.
    var whisperCode: String? {
        switch self {
        case .auto: return nil
        case .zhHant: return "zh" // Whisper uses "zh" for all Chinese
        default: return rawValue
        }
    }
}

enum LanguageConfig {
    private static let globalLanguageKey = "globalLanguage"

    static var globalLanguage: SupportedLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: globalLanguageKey),
                  let lang = SupportedLanguage(rawValue: raw) else { return .auto }
            return lang
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: globalLanguageKey) }
    }
}
