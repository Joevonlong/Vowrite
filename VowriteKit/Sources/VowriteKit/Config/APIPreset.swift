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
    case localMLX

    public var id: String {
        "builtin:\(rawValue)"
    }

    /// True only when every endpoint has a production request path in this
    /// build. The legacy ID remains decodable for explicit upgrade recovery.
    public var isRuntimeEligible: Bool {
        self != .localOllama
    }

    public var name: String {
        switch self {
        case .recommended: return "Recommended"
        case .openAIAllInOne: return "OpenAI all-in-one"
        case .siliconflowKimi: return "SiliconFlow + Kimi"
        case .localOllama: return "Sherpa + Ollama"
        case .localMLX: return "Groq STT + MLX Polish"
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
            return "Offline Sherpa STT + local Ollama polish"
        case .localMLX:
            return "Groq STT + local MLX polish (Apple Silicon optimized)"
        }
    }

    public var configuration: SplitAPIConfiguration {
        switch self {
        case .recommended:
            return .recommended
        case .openAIAllInOne:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .openai, model: "gpt-4o-mini-transcribe"),
                polish: APIEndpointConfiguration(provider: .openai, model: "gpt-5.4-mini")
            )
        case .siliconflowKimi:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .siliconflow, model: "FunAudioLLM/SenseVoiceSmall"),
                polish: APIEndpointConfiguration(provider: .kimi, model: "kimi-k2.6")
            )
        case .localOllama:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(
                    provider: .sherpa,
                    model: "sensevoice-small",
                    baseURL: APIProvider.sherpa.defaultBaseURL
                ),
                polish: APIEndpointConfiguration(
                    provider: .ollama,
                    model: "qwen3:8b",
                    baseURL: APIProvider.ollama.defaultBaseURL
                )
            )
        case .localMLX:
            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(provider: .groq, model: "whisper-large-v3-turbo"),
                polish: APIEndpointConfiguration(
                    provider: .mlxServer,
                    model: "mlx-community/Qwen3.5-9B-MLX-4bit",
                    baseURL: APIProvider.mlxServer.defaultBaseURL
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
    private static let userPresetsKey = StorageKeys.splitAPIUserPresets

    public static var builtInPresets: [APIPresetOption] {
        BuiltInAPIPreset.allCases
            .filter { preset in
                guard preset.isRuntimeEligible else { return false }
                #if os(iOS)
                return preset != .localOllama && preset != .localMLX
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
            ProviderModelConfigurationLock.readSnapshot {
                loadUserPresets(from: VowriteStorage.defaults)
            }
        }
        set {
            ProviderModelConfigurationLock.performMutation {
                writeUserPresets(newValue, to: VowriteStorage.defaults)
            }
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
        ProviderModelConfigurationLock.performMutation {
            var presets = loadUserPresets(from: VowriteStorage.defaults)
            presets.append(preset)
            writeUserPresets(presets, to: VowriteStorage.defaults)
        }
        return preset
    }

    public static func deleteUserPreset(id: UUID) {
        ProviderModelConfigurationLock.performMutation {
            var presets = loadUserPresets(from: VowriteStorage.defaults)
            presets.removeAll { $0.id == id }
            writeUserPresets(presets, to: VowriteStorage.defaults)
        }
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

    private static func loadUserPresets(from defaults: UserDefaults) -> [UserAPIPreset] {
        guard let data = defaults.data(forKey: userPresetsKey),
              let presets = try? JSONDecoder().decode([UserAPIPreset].self, from: data) else {
            return []
        }
        return presets.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func writeUserPresets(_ presets: [UserAPIPreset], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: userPresetsKey)
    }
}
