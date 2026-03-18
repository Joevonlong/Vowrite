import Foundation

struct UserAPIPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var configuration: SplitAPIConfiguration
}

enum BuiltInAPIPreset: String, CaseIterable, Identifiable {
    case recommended
    case openAIAllInOne
    case localOllama

    var id: String {
        "builtin:\(rawValue)"
    }

    var name: String {
        switch self {
        case .recommended: return "Recommended"
        case .openAIAllInOne: return "OpenAI all-in-one"
        case .localOllama: return "Local Ollama"
        }
    }

    var summary: String {
        switch self {
        case .recommended:
            return "Groq STT + DeepSeek polish"
        case .openAIAllInOne:
            return "OpenAI handles both STT and polish"
        case .localOllama:
            return "Run both pipelines locally on Ollama"
        }
    }

    var configuration: SplitAPIConfiguration {
        switch self {
        case .recommended:
            return .recommended
        case .openAIAllInOne:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .openai, model: "gpt-4o-mini-transcribe"),
                polish: APIEndpointConfiguration(provider: .openai, model: "gpt-4o-mini")
            )
        case .localOllama:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(
                    provider: .ollama,
                    model: "whisper-large-v3-turbo",
                    baseURL: APIProvider.ollama.defaultBaseURL
                ),
                polish: APIEndpointConfiguration(
                    provider: .ollama,
                    model: "qwen3:8b",
                    baseURL: APIProvider.ollama.defaultBaseURL
                )
            )
        }
    }
}

struct APIPresetOption: Identifiable, Equatable {
    let id: String
    let name: String
    let summary: String
    let configuration: SplitAPIConfiguration
    let isBuiltIn: Bool
    let userPresetID: UUID?
}

enum APIPresetStore {
    private static let userPresetsKey = "splitAPI.userPresets"

    static var builtInPresets: [APIPresetOption] {
        BuiltInAPIPreset.allCases.map {
            APIPresetOption(
                id: $0.id,
                name: $0.name,
                summary: $0.summary,
                configuration: $0.configuration,
                isBuiltIn: true,
                userPresetID: nil
            )
        }
    }

    static var userPresets: [UserAPIPreset] {
        get {
            guard let data = UserDefaults.standard.data(forKey: userPresetsKey),
                  let presets = try? JSONDecoder().decode([UserAPIPreset].self, from: data) else {
                return []
            }
            return presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            UserDefaults.standard.set(data, forKey: userPresetsKey)
        }
    }

    static var allPresets: [APIPresetOption] {
        builtInPresets + userPresets.map {
            APIPresetOption(
                id: userPresetID(for: $0.id),
                name: $0.name,
                summary: summary(for: $0.configuration),
                configuration: $0.configuration,
                isBuiltIn: false,
                userPresetID: $0.id
            )
        }
    }

    static func preset(for id: String) -> APIPresetOption? {
        allPresets.first { $0.id == id }
    }

    static func matchingPreset(for configuration: SplitAPIConfiguration) -> APIPresetOption? {
        allPresets.first { $0.configuration == configuration }
    }

    static func saveUserPreset(name: String, configuration: SplitAPIConfiguration) -> UserAPIPreset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let preset = UserAPIPreset(
            id: UUID(),
            name: trimmedName.isEmpty ? defaultPresetName(for: configuration) : trimmedName,
            configuration: configuration
        )
        var presets = userPresets
        presets.append(preset)
        userPresets = presets
        return preset
    }

    static func deleteUserPreset(id: UUID) {
        userPresets.removeAll { $0.id == id }
    }

    static func defaultPresetName(for configuration: SplitAPIConfiguration) -> String {
        "\(configuration.stt.provider.rawValue) + \(configuration.polish.provider.rawValue)"
    }

    static func summary(for configuration: SplitAPIConfiguration) -> String {
        "\(configuration.stt.provider.rawValue) STT + \(configuration.polish.provider.rawValue) polish"
    }

    static func userPresetID(for id: UUID) -> String {
        "user:\(id.uuidString.lowercased())"
    }
}
