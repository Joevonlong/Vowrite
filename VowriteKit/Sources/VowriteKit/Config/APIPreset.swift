import Foundation

public struct UserAPIPreset: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var configuration: SplitAPIConfiguration

    public init(id: UUID, name: String, configuration: SplitAPIConfiguration) {
        self.id = id
        self.name = name
        self.configuration = configuration
    }
}

public enum BuiltInAPIPreset: String, CaseIterable, Identifiable {
    case recommended
    case openAIAllInOne
    case siliconflowKimi
    case localOllama

    public var id: String {
        "builtin:\(rawValue)"
    }

    public var name: String {
        switch self {
        case .recommended: return "Recommended"
        case .openAIAllInOne: return "OpenAI all-in-one"
        case .siliconflowKimi: return "SiliconFlow + Kimi"
        case .localOllama: return "Local Ollama"
        }
    }

    public var summary: String {
        switch self {
        case .recommended:
            return "Groq STT + DeepSeek polish"
        case .openAIAllInOne:
            return "OpenAI handles both STT and polish"
        case .siliconflowKimi:
            return "SiliconFlow STT (SenseVoice) + Kimi polish"
        case .localOllama:
            return "Run both pipelines locally on Ollama"
        }
    }

    public var configuration: SplitAPIConfiguration {
        switch self {
        case .recommended:
            return .recommended
        case .openAIAllInOne:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .openai, model: "gpt-4o-mini-transcribe"),
                polish: APIEndpointConfiguration(provider: .openai, model: "gpt-4o-mini")
            )
        case .siliconflowKimi:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .siliconflow, model: "FunAudioLLM/SenseVoiceSmall"),
                polish: APIEndpointConfiguration(provider: .kimi, model: "kimi-k2.5")
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

public struct APIPresetOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let summary: String
    public let configuration: SplitAPIConfiguration
    public let isBuiltIn: Bool
    public let userPresetID: UUID?

    public init(id: String, name: String, summary: String, configuration: SplitAPIConfiguration, isBuiltIn: Bool, userPresetID: UUID?) {
        self.id = id
        self.name = name
        self.summary = summary
        self.configuration = configuration
        self.isBuiltIn = isBuiltIn
        self.userPresetID = userPresetID
    }
}

public enum APIPresetStore {
    private static let userPresetsKey = "splitAPI.userPresets"

    public static var builtInPresets: [APIPresetOption] {
        BuiltInAPIPreset.allCases
            .filter { preset in
                #if os(iOS)
                return preset != .localOllama
                #else
                return true
                #endif
            }
            .map {
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

    public static var userPresets: [UserAPIPreset] {
        get {
            guard let data = VowriteStorage.defaults.data(forKey: userPresetsKey),
                  let presets = try? JSONDecoder().decode([UserAPIPreset].self, from: data) else {
                return []
            }
            return presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            VowriteStorage.defaults.set(data, forKey: userPresetsKey)
        }
    }

    public static var allPresets: [APIPresetOption] {
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

    public static func preset(for id: String) -> APIPresetOption? {
        allPresets.first { $0.id == id }
    }

    public static func matchingPreset(for configuration: SplitAPIConfiguration) -> APIPresetOption? {
        allPresets.first { $0.configuration == configuration }
    }

    @discardableResult
    public static func saveUserPreset(name: String, configuration: SplitAPIConfiguration) -> UserAPIPreset {
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

    public static func deleteUserPreset(id: UUID) {
        userPresets.removeAll { $0.id == id }
    }

    public static func defaultPresetName(for configuration: SplitAPIConfiguration) -> String {
        "\(configuration.stt.provider.rawValue) + \(configuration.polish.provider.rawValue)"
    }

    public static func summary(for configuration: SplitAPIConfiguration) -> String {
        "\(configuration.stt.provider.rawValue) STT + \(configuration.polish.provider.rawValue) polish"
    }

    public static func userPresetID(for id: UUID) -> String {
        "user:\(id.uuidString.lowercased())"
    }
}
