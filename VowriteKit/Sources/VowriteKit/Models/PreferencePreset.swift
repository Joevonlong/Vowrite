import Foundation

public struct PreferencePreset: Identifiable {
    public let id: String
    public let name: String
    public let icon: String
    public let promptText: String

    public init(id: String, name: String, icon: String, promptText: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.promptText = promptText
    }

    public static let presets: [PreferencePreset] = [
        PreferencePreset(id: "business", name: "Business", icon: "building.2", promptText: "Use formal, professional tone. Clear and concise."),
        PreferencePreset(id: "casual", name: "Casual", icon: "bubble.left", promptText: "Keep it natural and conversational. Relaxed tone."),
        PreferencePreset(id: "academic", name: "Academic", icon: "graduationcap", promptText: "Use academic writing style. Precise terminology."),
        PreferencePreset(id: "creative", name: "Creative", icon: "paintbrush", promptText: "Allow creative expression. Vivid language welcome."),
        PreferencePreset(id: "technical", name: "Technical", icon: "wrench.and.screwdriver", promptText: "Preserve all technical terms exactly. Precise and unambiguous."),
    ]
}
