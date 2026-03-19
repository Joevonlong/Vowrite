import Foundation

public struct APIEndpointConfiguration: Codable, Equatable {
    public var provider: APIProvider
    public var model: String
    public var baseURL: String

    public init(provider: APIProvider, model: String, baseURL: String? = nil) {
        self.provider = provider
        self.model = model
        self.baseURL = APIEndpointConfiguration.normalizeBaseURL(baseURL, provider: provider)
    }

    public var resolvedBaseURL: String {
        APIEndpointConfiguration.normalizeBaseURL(baseURL, provider: provider)
    }

    public var requiresAPIKey: Bool {
        provider.requiresAPIKey
    }

    public var hasKey: Bool {
        KeyVault.hasKey(for: provider)
    }

    public var key: String? {
        KeyVault.key(for: provider)
    }

    public static func normalizeBaseURL(_ baseURL: String?, provider: APIProvider) -> String {
        let trimmed = baseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? provider.defaultBaseURL : trimmed
    }
}

public struct SplitAPIConfiguration: Codable, Equatable {
    public var stt: APIEndpointConfiguration
    public var polish: APIEndpointConfiguration

    public init(stt: APIEndpointConfiguration, polish: APIEndpointConfiguration) {
        self.stt = stt
        self.polish = polish
    }

    public static let recommended = SplitAPIConfiguration(
        stt: APIEndpointConfiguration(provider: .groq, model: "whisper-large-v3-turbo"),
        polish: APIEndpointConfiguration(provider: .deepseek, model: "deepseek-chat")
    )
}

public enum APIConfig {
    private static let sttProviderKey = "splitAPI.stt.provider"
    private static let sttModelKey = "splitAPI.stt.model"
    private static let sttBaseURLKey = "splitAPI.stt.baseURL"
    private static let polishProviderKey = "splitAPI.polish.provider"
    private static let polishModelKey = "splitAPI.polish.model"
    private static let polishBaseURLKey = "splitAPI.polish.baseURL"
    private static let selectedPresetKey = "splitAPI.selectedPresetID"

    public static var current: SplitAPIConfiguration {
        get {
            SplitAPIConfiguration(
                stt: APIEndpointConfiguration(
                    provider: sttProvider,
                    model: sttModel,
                    baseURL: sttBaseURL
                ),
                polish: APIEndpointConfiguration(
                    provider: polishProvider,
                    model: polishModel,
                    baseURL: polishBaseURL
                )
            )
        }
        set {
            stt = newValue.stt
            polish = newValue.polish
        }
    }

    public static var stt: APIEndpointConfiguration {
        get {
            APIEndpointConfiguration(provider: sttProvider, model: sttModel, baseURL: sttBaseURL)
        }
        set {
            sttProvider = newValue.provider
            sttModel = newValue.model
            sttBaseURL = newValue.resolvedBaseURL
        }
    }

    public static var polish: APIEndpointConfiguration {
        get {
            APIEndpointConfiguration(provider: polishProvider, model: polishModel, baseURL: polishBaseURL)
        }
        set {
            polishProvider = newValue.provider
            polishModel = newValue.model
            polishBaseURL = newValue.resolvedBaseURL
        }
    }

    public static var sttProvider: APIProvider {
        get { provider(forKey: sttProviderKey, fallback: .groq) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sttProviderKey) }
    }

    public static var sttModel: String {
        get { string(forKey: sttModelKey) ?? "whisper-large-v3-turbo" }
        set { UserDefaults.standard.set(newValue, forKey: sttModelKey) }
    }

    public static var sttBaseURL: String {
        get { string(forKey: sttBaseURLKey) ?? sttProvider.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: sttBaseURLKey) }
    }

    public static var polishProvider: APIProvider {
        get { provider(forKey: polishProviderKey, fallback: .deepseek) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: polishProviderKey) }
    }

    public static var polishModel: String {
        get { string(forKey: polishModelKey) ?? "deepseek-chat" }
        set { UserDefaults.standard.set(newValue, forKey: polishModelKey) }
    }

    public static var polishBaseURL: String {
        get { string(forKey: polishBaseURLKey) ?? polishProvider.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: polishBaseURLKey) }
    }

    public static var selectedPresetID: String? {
        get { string(forKey: selectedPresetKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: selectedPresetKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedPresetKey)
            }
        }
    }

    public static var activePreset: APIPresetOption? {
        if let selectedPresetID,
           let preset = APIPresetStore.preset(for: selectedPresetID) {
            return preset
        }
        return APIPresetStore.matchingPreset(for: current)
    }

    public static func apply(_ configuration: SplitAPIConfiguration, presetID: String? = nil) {
        current = configuration
        selectedPresetID = presetID
    }

    public static func apply(_ preset: APIPresetOption) {
        apply(preset.configuration, presetID: preset.id)
    }

    public static func clearSelectedPresetIfNeeded(for configuration: SplitAPIConfiguration) {
        if let activePreset, activePreset.configuration == configuration {
            return
        }
        selectedPresetID = nil
    }

    private static func string(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: key)
    }

    private static func provider(forKey key: String, fallback: APIProvider) -> APIProvider {
        guard let rawValue = UserDefaults.standard.string(forKey: key),
              let provider = APIProvider(rawValue: rawValue) else {
            return fallback
        }
        return provider
    }
}
