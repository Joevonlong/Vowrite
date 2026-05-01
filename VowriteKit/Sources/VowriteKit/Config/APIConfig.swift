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

    /// Effective base URL for HTTP requests. When the user has an active OAuth
    /// session whose token carries a base URL override (e.g. Kimi Code Coding
    /// Plan re-routes to api.kimi.com/coding/v1), that takes precedence over
    /// the stored value.
    public var resolvedBaseURL: String {
        if let oauthURL = KeyVault.effectiveBaseURL(for: provider) {
            return oauthURL
        }
        return APIEndpointConfiguration.normalizeBaseURL(baseURL, provider: provider)
    }

    public var requiresAPIKey: Bool {
        provider.requiresAPIKey
    }

    /// True when an API key is stored OR a valid OAuth token is active.
    public var hasKey: Bool {
        if KeyVault.preferredAuthMethod(for: provider) == "oauth",
           KeyVault.hasValidOAuthToken(for: provider) {
            return true
        }
        return KeyVault.hasKey(for: provider)
    }

    /// Credential to use in the Authorization header. Returns the OAuth access
    /// token when the user prefers OAuth and has a valid token; otherwise the
    /// stored API key.
    public var key: String? {
        KeyVault.effectiveKey(for: provider)
    }

    /// Model ID to send to the API. Some providers require a different model
    /// alias when authenticated via OAuth (e.g. Kimi Code Coding Plan accepts
    /// only `kimi-for-coding`, mapped server-side to the user's plan model).
    public var resolvedModel: String {
        if KeyVault.preferredAuthMethod(for: provider) == "oauth",
           KeyVault.hasValidOAuthToken(for: provider) {
            switch provider.providerID {
            case "kimi":
                return "kimi-for-coding"
            default:
                break
            }
        }
        return model
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
        set { VowriteStorage.defaults.set(newValue.rawValue, forKey: sttProviderKey) }
    }

    public static var sttModel: String {
        get { string(forKey: sttModelKey) ?? "whisper-large-v3-turbo" }
        set { VowriteStorage.defaults.set(newValue, forKey: sttModelKey) }
    }

    public static var sttBaseURL: String {
        get { string(forKey: sttBaseURLKey) ?? sttProvider.defaultBaseURL }
        set { VowriteStorage.defaults.set(newValue, forKey: sttBaseURLKey) }
    }

    public static var polishProvider: APIProvider {
        get { provider(forKey: polishProviderKey, fallback: .deepseek) }
        set { VowriteStorage.defaults.set(newValue.rawValue, forKey: polishProviderKey) }
    }

    public static var polishModel: String {
        get { string(forKey: polishModelKey) ?? "deepseek-chat" }
        set { VowriteStorage.defaults.set(newValue, forKey: polishModelKey) }
    }

    public static var polishBaseURL: String {
        get { string(forKey: polishBaseURLKey) ?? polishProvider.defaultBaseURL }
        set { VowriteStorage.defaults.set(newValue, forKey: polishBaseURLKey) }
    }

    public static var selectedPresetID: String? {
        get { string(forKey: selectedPresetKey) }
        set {
            if let newValue {
                VowriteStorage.defaults.set(newValue, forKey: selectedPresetKey)
            } else {
                VowriteStorage.defaults.removeObject(forKey: selectedPresetKey)
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

    /// Migrate renamed builtin preset IDs (chinaRecommended → siliconflowKimi)
    public static func migratePresetIDs() {
        if selectedPresetID == "builtin:chinaRecommended" {
            selectedPresetID = "builtin:siliconflowKimi"
        }
    }

    public static func clearSelectedPresetIfNeeded(for configuration: SplitAPIConfiguration) {
        if let activePreset, activePreset.configuration == configuration {
            return
        }
        selectedPresetID = nil
    }

    private static func string(forKey key: String) -> String? {
        VowriteStorage.defaults.string(forKey: key)
    }

    private static func provider(forKey key: String, fallback: APIProvider) -> APIProvider {
        guard let rawValue = VowriteStorage.defaults.string(forKey: key),
              let provider = APIProvider(rawValue: rawValue) else {
            return fallback
        }
        return provider
    }
}
