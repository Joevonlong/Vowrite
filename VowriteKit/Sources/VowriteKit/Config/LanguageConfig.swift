import Foundation

/// A speech-recognition / output language, optionally qualified with a
/// BCP-47 region subtag (F-079, "language region variants").
///
/// Cases whose `rawValue` has no `-` are "family roots" — the plain
/// ISO-639-1 code (e.g. `"zh"`, `"en"`) that has always been the only kind
/// of value `Mode.language` / `Mode.targetLanguage` could store. Cases whose
/// `rawValue` contains a `-` (e.g. `"zh-TW"`, `"en-GB"`) are explicit region
/// variants of a family root. Storage stays a plain `String?` throughout the
/// app (`Mode.language`, `Mode.targetLanguage`, `LanguageConfig.globalLanguage`)
/// so old persisted plain codes decode unchanged — adding variant cases here
/// is a purely additive, zero-migration change.
public enum SupportedLanguage: String, CaseIterable, Identifiable, Codable {
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

    // F-079: region variants. Each belongs to the family root with the
    // matching prefix before the "-" (e.g. "zh-CN" belongs to "zh" / .zhHans).
    case zhCN = "zh-CN"
    case zhHK = "zh-HK"
    case enUS = "en-US"
    case enGB = "en-GB"
    case enAU = "en-AU"
    case esES = "es-ES"
    case esMX = "es-MX"
    case ptBR = "pt-BR"
    case ptPT = "pt-PT"
    case frFR = "fr-FR"
    case frCA = "fr-CA"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .en: return "English"
        case .zhHans: return "Chinese (Simplified)"
        case .zhHant: return "Chinese (Traditional, Taiwan)"
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
        case .zhCN: return "Chinese (Simplified, Mainland)"
        case .zhHK: return "Chinese (Traditional, Hong Kong)"
        case .enUS: return "English (US)"
        case .enGB: return "English (UK)"
        case .enAU: return "English (Australia)"
        case .esES: return "Spanish (Spain)"
        case .esMX: return "Spanish (Mexico)"
        case .ptBR: return "Portuguese (Brazil)"
        case .ptPT: return "Portuguese (Portugal)"
        case .frFR: return "French (France)"
        case .frCA: return "French (Canada)"
        }
    }

    /// Short label for the region-variant picker row — omits the language
    /// family name (already shown by the parent picker) and, for the
    /// script-sensitive Chinese variants, includes the native-script hint
    /// since that's the distinction users actually need to recognize at a
    /// glance. `nil` for family-root cases (no variant row for those).
    public var regionLabel: String? {
        switch self {
        case .zhCN: return "Simplified · Mainland (简体)"
        case .zhHant: return "Traditional · Taiwan (繁體)"
        case .zhHK: return "Traditional · Hong Kong (繁體)"
        case .enUS: return "US"
        case .enGB: return "UK"
        case .enAU: return "Australia"
        case .esES: return "Spain"
        case .esMX: return "Mexico"
        case .ptBR: return "Brazil"
        case .ptPT: return "Portugal"
        case .frFR: return "France"
        case .frCA: return "Canada"
        default: return nil
        }
    }

    /// The language tag handed to the STT layer. `nil` for auto-detect.
    ///
    /// This is the *full* BCP-47 tag (e.g. `"zh-TW"`), not downgraded to the
    /// ISO-639-1 main code — Deepgram's `/listen` API accepts full region
    /// tags directly. Adapters for Whisper-style APIs that only accept the
    /// main code (OpenAI, Groq, Qwen, ...) downgrade internally via
    /// `LanguageConfig.whisperMainCode(from:)` before sending.
    public var whisperCode: String? {
        self == .auto ? nil : rawValue
    }

    /// Compact 1-2 character label used in UI badges (e.g. recording overlay translation indicator).
    public var shortLabel: String {
        switch self {
        case .auto: return "—"
        case .en, .enUS, .enGB, .enAU: return "EN"
        case .zhHans, .zhCN: return "中"
        case .zhHant, .zhHK: return "繁"
        case .ja: return "日"
        case .ko: return "한"
        case .de: return "DE"
        case .fr, .frFR, .frCA: return "FR"
        case .es, .esES, .esMX: return "ES"
        case .it: return "IT"
        case .pt, .ptBR, .ptPT: return "PT"
        case .ru: return "RU"
        case .ar: return "AR"
        case .hi: return "HI"
        case .th: return "TH"
        case .vi: return "VI"
        case .nl: return "NL"
        case .pl: return "PL"
        case .sv: return "SV"
        case .tr: return "TR"
        }
    }

    // MARK: - F-079: Family / region-variant grouping

    /// The family-root case this language belongs to — itself for a plain
    /// main code, or the case matching the prefix before "-" for a region
    /// variant (e.g. `.zhHant.languageFamily == .zhHans`).
    public var languageFamily: SupportedLanguage {
        guard let dashIndex = rawValue.firstIndex(of: "-") else { return self }
        let mainCode = String(rawValue[rawValue.startIndex..<dashIndex])
        return SupportedLanguage(rawValue: mainCode) ?? self
    }

    /// True when this case is a plain main-language code (no region subtag) —
    /// the set shown in the primary "main language" picker.
    public var isFamilyRoot: Bool { languageFamily == self }

    /// The region variants available for this family (empty for a case that
    /// isn't itself a family root, or a family with no variants defined).
    public var regionVariants: [SupportedLanguage] {
        guard isFamilyRoot else { return [] }
        return SupportedLanguage.allCases.filter { $0 != self && $0.languageFamily == self }
    }

    /// All family-root cases, in declaration order — the option list for the
    /// primary "main language" picker.
    public static var familyRoots: [SupportedLanguage] {
        allCases.filter { $0.isFamilyRoot }
    }
}

public enum LanguageConfig {
    private static let globalLanguageKey = StorageKeys.globalLanguage

    public static var globalLanguage: SupportedLanguage {
        get {
            guard let raw = VowriteStorage.defaults.string(forKey: globalLanguageKey),
                  let lang = SupportedLanguage(rawValue: raw) else { return .auto }
            return lang
        }
        set { VowriteStorage.defaults.set(newValue.rawValue, forKey: globalLanguageKey) }
    }

    // MARK: - F-079: Region-variant pure helpers
    //
    // These are plain String -> String?/Bool functions (no I/O, no shared
    // state) so they're testable without constructing a `SupportedLanguage`
    // and so they degrade gracefully for tags this app doesn't know about.

    /// Resolves the effective language tag by cascading: an explicit
    /// per-mode override wins when it's a recognized language code;
    /// otherwise falls back to `globalLanguage`. `nil` when the resolved
    /// language is "auto" (no explicit language hint at all).
    ///
    /// Pure function (both inputs are passed in, no UserDefaults read) so
    /// it's directly testable — shared by the STT-language resolution
    /// (DictationEngine / BackgroundRecordingService) and the polish-prompt
    /// region-hint resolution (`SpeculativePolish.buildSystemPrompt` via
    /// `ModeConfig.withResolvedLanguage`), so "mode.language == nil" means
    /// the same thing — "use the global default" — on both paths. Without
    /// this, a user whose global default is a region variant (e.g. zh-TW)
    /// would get the Traditional-Chinese STT hint but not the matching
    /// polish-output instruction for any mode that doesn't set its own
    /// `language` override.
    public static func resolvedLanguageTag(modeLanguage: String?, globalLanguage: SupportedLanguage) -> String? {
        if let modeLanguage, let lang = SupportedLanguage(rawValue: modeLanguage) {
            return lang.whisperCode
        }
        return globalLanguage.whisperCode
    }

    /// Downgrades a BCP-47 tag to its ISO-639-1 main code for STT APIs
    /// (OpenAI Whisper, Groq, Qwen, ...) that only accept the main code —
    /// e.g. `"zh-TW"` -> `"zh"`. Plain codes (no region subtag) pass through
    /// unchanged, e.g. `"en"` -> `"en"`.
    public static func whisperMainCode(from tag: String) -> String {
        guard let dashIndex = tag.firstIndex(of: "-") else { return tag }
        return String(tag[tag.startIndex..<dashIndex])
    }

    /// Whether Deepgram's `/listen` API should receive the tag as-is. Deepgram
    /// accepts full BCP-47 region tags (e.g. `"en-GB"`) directly, so this is
    /// always an identity passthrough — the function exists to make that
    /// decision explicit and testable rather than implicit in the adapter.
    public static func deepgramLanguage(for tag: String?) -> String? { tag }

    /// A short exemplar hint for STT vocabulary prompts, for region variants
    /// where script/orthography materially affects transcription output
    /// (Traditional vs. Simplified Chinese). The hint is itself written in
    /// the target script — Whisper-style `prompt` fields work by priming the
    /// model's style/vocabulary from the prompt text, not by following
    /// instructions, so an English instruction would not help here.
    /// `nil` when the tag has no script-sensitive hint.
    public static func sttRegionHint(for tag: String) -> String? {
        switch tag {
        case "zh-TW": return "以下是繁體中文的錄音內容："
        case "zh-HK": return "以下係香港繁體中文（廣東話）嘅錄音內容："
        default: return nil
        }
    }

    /// Combines an existing STT vocabulary prompt (F-014) with the region
    /// hint for `languageTag`, additively. Returns `basePrompt` unchanged
    /// when there's no hint for the tag (including a `nil` tag).
    public static func sttPrompt(basePrompt: String?, languageTag: String?) -> String? {
        guard let tag = languageTag, let hint = sttRegionHint(for: tag) else { return basePrompt }
        let base = basePrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return base.isEmpty ? hint : "\(hint) \(base)"
    }

    /// A short polish/translation-prompt instruction for a region variant —
    /// appended to the system prompt so the LLM renders output using that
    /// region's script/spelling conventions. `nil` for plain main codes,
    /// `"auto"`, and unrecognized tags.
    public static func polishRegionInstruction(for tag: String) -> String? {
        switch tag {
        case "zh-CN": return "Render Chinese text using Simplified Chinese characters (Mainland conventions)."
        case "zh-TW": return "Render Chinese text using Traditional Chinese characters (Taiwan conventions and vocabulary)."
        case "zh-HK": return "Render Chinese text using Traditional Chinese characters (Hong Kong conventions and vocabulary)."
        case "en-US": return "Use American English spelling and conventions."
        case "en-GB": return "Use British English spelling and conventions."
        case "en-AU": return "Use Australian English spelling and conventions."
        case "es-ES": return "Use European Spanish (Spain) conventions."
        case "es-MX": return "Use Mexican Spanish conventions."
        case "pt-BR": return "Use Brazilian Portuguese conventions."
        case "pt-PT": return "Use European Portuguese (Portugal) conventions."
        case "fr-FR": return "Use European French (France) conventions."
        case "fr-CA": return "Use Canadian French conventions."
        default: return nil
        }
    }
}
