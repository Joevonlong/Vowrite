import Foundation

public struct OutputStyle: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var icon: String          // SF Symbol name
    public var description: String
    public var templatePrompt: String
    public var isBuiltin: Bool

    public init(id: UUID, name: String, icon: String, description: String, templatePrompt: String, isBuiltin: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.templatePrompt = templatePrompt
        self.isBuiltin = isBuiltin
    }

    public static let builtinStyles: [OutputStyle] = [
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
            name: "None",
            icon: "minus.circle",
            description: "No extra formatting — just clean text.",
            templatePrompt: "",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
            name: "Bullet List",
            icon: "list.bullet",
            description: "Format output as bullet points.",
            templatePrompt: "Format the output as a bullet list. Each distinct point or idea should be its own bullet point. Use concise, clear phrasing for each item.",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000003")!,
            name: "Numbered List",
            icon: "list.number",
            description: "Format output as numbered steps.",
            templatePrompt: "Format the output as a numbered list. Each distinct point, step, or idea should be numbered sequentially. Use concise, clear phrasing for each item.",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000004")!,
            name: "Email",
            icon: "envelope.open",
            description: "Professional email format with greeting and sign-off.",
            templatePrompt: "Format the output as a professional email. Include an appropriate greeting, organize the body into clear paragraphs, and end with a polite sign-off. Use a formal but approachable tone.",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000005")!,
            name: "Meeting Notes",
            icon: "person.3",
            description: "Structured meeting notes with key points and action items.",
            templatePrompt: "Format the output as structured meeting notes. Include sections for key discussion points, decisions made, and action items. Use bullet points within each section. Mark action items clearly.",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000006")!,
            name: "Social Post",
            icon: "bubble.left.and.bubble.right",
            description: "Concise, engaging social media style.",
            templatePrompt: "Format the output as a social media post. Keep it concise, engaging, and punchy. Use short sentences and a conversational tone. Add line breaks for readability.",
            isBuiltin: true
        ),
        OutputStyle(
            id: UUID(uuidString: "00000000-0000-0000-0001-000000000007")!,
            name: "Technical Doc",
            icon: "doc.text.magnifyingglass",
            description: "Precise technical documentation style.",
            templatePrompt: "Format the output as technical documentation. Use precise, unambiguous language. Structure with clear sections and subsections where appropriate. Preserve all technical terms exactly as spoken.",
            isBuiltin: true
        ),
    ]

    /// The "None" style ID — means no extra formatting
    public static let noneId = UUID(uuidString: "00000000-0000-0000-0001-000000000001")!
}
