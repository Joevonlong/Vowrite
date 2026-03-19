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

    public init(id: UUID, name: String, icon: String, isBuiltin: Bool, sttModel: String?, language: String?, polishEnabled: Bool, polishModel: String?, systemPrompt: String, userPrompt: String, temperature: Double, autoPaste: Bool, outputStyleId: UUID?, shortcutIndex: Int?) {
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
            systemPrompt: "",
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
            systemPrompt: "Format as clean, organized notes. Use bullet points or numbered lists where appropriate. Keep it concise and well-structured.",
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
    ]
}
