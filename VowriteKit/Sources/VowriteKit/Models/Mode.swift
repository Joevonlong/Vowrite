import Foundation

public struct Mode: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var icon: String          // SF Symbol name
    public var isBuiltin: Bool

    // STT settings
    public var sttModel: String?     // nil = use global default
    public var language: String?     // nil = use global default (SupportedLanguage rawValue)

    // Polish settings
    public var polishEnabled: Bool   // false = pure transcription, no AI polish
    public var polishModel: String?  // nil = use global default
    public var systemPrompt: String
    public var userPrompt: String
    public var temperature: Double
    public var autoPaste: Bool

    // Output style template (nil = no style / "None")
    public var outputStyleId: UUID?

    // Keyboard shortcut index (Cmd+1, Cmd+2, etc.)
    public var shortcutIndex: Int?

    // F-063: Translation mode flags
    public var isTranslation: Bool
    public var targetLanguage: String?   // SupportedLanguage rawValue (e.g. "en", "zh-Hans")

    public init(
        id: UUID,
        name: String,
        icon: String,
        isBuiltin: Bool,
        sttModel: String?,
        language: String?,
        polishEnabled: Bool,
        polishModel: String?,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double,
        autoPaste: Bool,
        outputStyleId: UUID?,
        shortcutIndex: Int?,
        isTranslation: Bool = false,
        targetLanguage: String? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBuiltin = isBuiltin
        self.sttModel = sttModel
        self.language = language
        self.polishEnabled = polishEnabled
        self.polishModel = polishModel
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.temperature = temperature
        self.autoPaste = autoPaste
        self.outputStyleId = outputStyleId
        self.shortcutIndex = shortcutIndex
        self.isTranslation = isTranslation
        self.targetLanguage = targetLanguage
    }

    // MARK: - Codable (backward-compatible decoding)
    //
    // Custom init(from:) so old JSON without `isTranslation` / `targetLanguage`
    // keys still decodes successfully. encode(to:) is auto-synthesized.

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, isBuiltin
        case sttModel, language
        case polishEnabled, polishModel, systemPrompt, userPrompt, temperature, autoPaste
        case outputStyleId
        case shortcutIndex
        case isTranslation, targetLanguage
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.icon = try c.decode(String.self, forKey: .icon)
        self.isBuiltin = try c.decode(Bool.self, forKey: .isBuiltin)
        self.sttModel = try c.decodeIfPresent(String.self, forKey: .sttModel)
        self.language = try c.decodeIfPresent(String.self, forKey: .language)
        self.polishEnabled = try c.decode(Bool.self, forKey: .polishEnabled)
        self.polishModel = try c.decodeIfPresent(String.self, forKey: .polishModel)
        self.systemPrompt = try c.decode(String.self, forKey: .systemPrompt)
        self.userPrompt = try c.decode(String.self, forKey: .userPrompt)
        self.temperature = try c.decode(Double.self, forKey: .temperature)
        self.autoPaste = try c.decode(Bool.self, forKey: .autoPaste)
        self.outputStyleId = try c.decodeIfPresent(UUID.self, forKey: .outputStyleId)
        self.shortcutIndex = try c.decodeIfPresent(Int.self, forKey: .shortcutIndex)
        self.isTranslation = try c.decodeIfPresent(Bool.self, forKey: .isTranslation) ?? false
        self.targetLanguage = try c.decodeIfPresent(String.self, forKey: .targetLanguage)
    }

    public static let builtinModes: [Mode] = [
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Dictation",
            icon: "mic.fill",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: false,
            polishModel: nil,
            systemPrompt: "",
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: 1
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Clean",
            icon: "sparkles",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: """
            Optimize for clarity and concision. Lead with the main point.
            Default to short paragraphs; use bullets when the content has list-like structure.
            Remove redundancy aggressively; preserve facts exactly.
            """,
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: 2
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Email",
            icon: "envelope",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: "Format the text as a professional email with a greeting and sign-off. Use clear paragraphs and a polite, formal tone.",
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: UUID(uuidString: "00000000-0000-0000-0001-000000000004")!,
            shortcutIndex: 3
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "Chat",
            icon: "bubble.left",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: "Keep it casual and conversational. Use short sentences, natural phrasing, and a friendly tone as if texting a friend.",
            userPrompt: "",
            temperature: 0.4,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: 4
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "Note",
            icon: "note.text",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: """
            Extract distinct points from the dictation and present them as bullets.
            Each bullet is one complete idea. Drop transitional and conversational scaffolding.
            Group related bullets under a one-line topic header when there are clear sub-themes.
            """,
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            shortcutIndex: 5
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            name: "Code Comment",
            icon: "chevron.left.forwardslash.chevron.right",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: "Format as a technical code comment. Be concise and precise, preserve all technical terms in their original language, and use standard documentation conventions.",
            userPrompt: "",
            temperature: 0.2,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: 6
        ),
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            name: "Command",
            icon: "terminal",
            isBuiltin: true,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: "命令如下：{text}\n选择的内容：{selected}\n剪切板的内容：{clipboard}",
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: 7
        ),
        // F-063: Translate mode (eighth built-in)
        Mode(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            name: "Translate",
            icon: "globe",
            isBuiltin: true,
            sttModel: nil,
            language: nil,                  // STT auto-detect (so users can speak any source language)
            polishEnabled: true,            // Translation goes through the LLM (polish) channel
            polishModel: nil,
            systemPrompt: "",               // Translation mode reuses systemPrompt as optional "additional instructions"
            userPrompt: "",
            temperature: 0.2,               // Lower temperature for stable translation
            autoPaste: true,
            outputStyleId: nil,             // Translation mode does not use output style
            shortcutIndex: nil,             // Triggered by dedicated translate hotkey, not ⌘1-⌘9
            isTranslation: true,
            targetLanguage: "en"            // Default target English; user-configurable
        ),
    ]
}
