import Foundation

struct SceneProfile: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let icon: String
    let promptTemplate: String

    static let presets: [SceneProfile] = [
        SceneProfile(
            id: "none",
            name: "None",
            icon: "minus.circle",
            promptTemplate: ""
        ),
        SceneProfile(
            id: "email",
            name: "Email",
            icon: "envelope",
            promptTemplate: "Format the text as a professional email with a greeting and sign-off. Use clear paragraphs and a polite, formal tone."
        ),
        SceneProfile(
            id: "chat",
            name: "Chat",
            icon: "bubble.left",
            promptTemplate: "Keep it casual and conversational. Use short sentences, natural phrasing, and a friendly tone as if texting a friend."
        ),
        SceneProfile(
            id: "social",
            name: "Social Media",
            icon: "at",
            promptTemplate: "Make it concise and punchy for social media. Keep it short, add relevant emojis where natural, and use an engaging tone."
        ),
        SceneProfile(
            id: "blog",
            name: "Blog",
            icon: "doc.richtext",
            promptTemplate: "Structure the text as a well-organized blog post. Use clear paragraphs and add subheadings where appropriate for readability."
        ),
        SceneProfile(
            id: "code",
            name: "Code Comment",
            icon: "chevron.left.forwardslash.chevron.right",
            promptTemplate: "Format as a technical code comment. Be concise and precise, preserve all technical terms in their original language, and use standard documentation conventions."
        ),
    ]
}
