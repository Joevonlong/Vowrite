import Foundation

struct Mode: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String          // SF Symbol name
    var isBuiltin: Bool

    // STT settings
    var sttModel: String?     // nil = use global default
    var language: String?     // nil = use global default (SupportedLanguage rawValue)

    // Polish settings
    var polishEnabled: Bool   // false = pure transcription, no AI polish
    var polishModel: String?  // nil = use global default
    var systemPrompt: String
    var userPrompt: String
    var temperature: Double
    var autoPaste: Bool

    // Output style template (nil = no style / "None")
    var outputStyleId: UUID?

    // Keyboard shortcut index (Cmd+1, Cmd+2, etc.)
    var shortcutIndex: Int?

    static let builtinModes: [Mode] = [
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
