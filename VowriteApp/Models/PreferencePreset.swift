import Foundation

struct PreferencePreset: Identifiable {
    let id: String
    let name: String
    let icon: String
    let promptText: String

    static let presets: [PreferencePreset] = [
        PreferencePreset(id: "business", name: "Business", icon: "building.2", promptText: "Use formal, professional tone. Clear and concise."),
        PreferencePreset(id: "casual", name: "Casual", icon: "bubble.left", promptText: "Keep it natural and conversational. Relaxed tone."),
        PreferencePreset(id: "academic", name: "Academic", icon: "graduationcap", promptText: "Use academic writing style. Precise terminology."),
        PreferencePreset(id: "creative", name: "Creative", icon: "paintbrush", promptText: "Allow creative expression. Vivid language welcome."),
        PreferencePreset(id: "technical", name: "Technical", icon: "wrench.and.screwdriver", promptText: "Preserve all technical terms exactly. Precise and unambiguous."),
    ]
}
