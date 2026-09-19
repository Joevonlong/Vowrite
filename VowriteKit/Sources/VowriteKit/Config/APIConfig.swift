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
        var resolved = trimmed.isEmpty ? provider.defaultBaseURL : trimmed
        // Strip trailing slashes so endpoint construction ("\(base)/chat/completions")
        // never produces a double slash ("...//chat/completions") that strict servers reject.
        while resolved.hasSuffix("/") { resolved.removeLast() }
        return resolved
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
        polish: APIEndpointConfiguration(provider: .deepseek, model: "deepseek-flash")
    )
}

public enum PresetIDMigrationResult: Equatable, Sendable {
    case unchanged
    case renamed
    case invalidatedUnavailablePreset
}

public struct UnavailableAPIPresetRecovery: Equatable, Sendable {
    public let presetID: String
    public let name: String
    public let message: String
}

public enum APIConfig {
    private static let sttProviderKey = StorageKeys.splitAPISTTProvider
    private static let sttModelKey = StorageKeys.splitAPISTTModel
    private static let sttBaseURLKey = StorageKeys.splitAPISTTBaseURL
    private static let polishProviderKey = StorageKeys.splitAPIPolishProvider
    private static let polishModelKey = StorageKeys.splitAPIPolishModel
    private static let polishBaseURLKey = StorageKeys.splitAPIPolishBaseURL
    private static let selectedPresetKey = StorageKeys.splitAPISelectedPresetID
    private static let invalidatedPresetKey = StorageKeys.splitAPIInvalidatedPresetID

    public static var current: SplitAPIConfiguration {
        get {
            ProviderModelConfigurationLock.readSnapshot {
                configuration(from: VowriteStorage.defaults)
            }
        }
        set {
            ProviderModelConfigurationLock.performMutation {
                write(newValue, to: VowriteStorage.defaults)
            }
        }
    }

    public static var stt: APIEndpointConfiguration {
        get {
            ProviderModelConfigurationLock.readSnapshot {
                configuration(from: VowriteStorage.defaults).stt
            }
        }
        set {
            ProviderModelConfigurationLock.performMutation {
                write(newValue, capability: .stt, to: VowriteStorage.defaults)
            }
        }
    }

    public static var polish: APIEndpointConfiguration {
        get {
            ProviderModelConfigurationLock.readSnapshot {
                configuration(from: VowriteStorage.defaults).polish
            }
        }
        set {
            ProviderModelConfigurationLock.performMutation {
                write(newValue, capability: .polish, to: VowriteStorage.defaults)
            }
        }
    }

    public static var sttProvider: APIProvider {
        get { ProviderModelConfigurationLock.readSnapshot { provider(forKey: sttProviderKey, fallback: .groq, defaults: VowriteStorage.defaults) } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue.rawValue, forKey: sttProviderKey) } }
    }

    public static var sttModel: String {
        get { ProviderModelConfigurationLock.readSnapshot { VowriteStorage.defaults.string(forKey: sttModelKey) ?? "whisper-large-v3-turbo" } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue, forKey: sttModelKey) } }
    }

    public static var sttBaseURL: String {
        get { ProviderModelConfigurationLock.readSnapshot { configuration(from: VowriteStorage.defaults).stt.baseURL } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue, forKey: sttBaseURLKey) } }
    }

    public static var polishProvider: APIProvider {
        get { ProviderModelConfigurationLock.readSnapshot { provider(forKey: polishProviderKey, fallback: .deepseek, defaults: VowriteStorage.defaults) } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue.rawValue, forKey: polishProviderKey) } }
    }

    public static var polishModel: String {
        // Fallback tracks DeepSeek's current economical chat tier. Existing
        // saved values are preserved verbatim by the defaults-backed store.
        get { ProviderModelConfigurationLock.readSnapshot { VowriteStorage.defaults.string(forKey: polishModelKey) ?? "deepseek-flash" } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue, forKey: polishModelKey) } }
    }

    public static var polishBaseURL: String {
        get { ProviderModelConfigurationLock.readSnapshot { configuration(from: VowriteStorage.defaults).polish.baseURL } }
        set { ProviderModelConfigurationLock.performMutation { VowriteStorage.defaults.set(newValue, forKey: polishBaseURLKey) } }
    }

    public static var selectedPresetID: String? {
        get { ProviderModelConfigurationLock.readSnapshot { VowriteStorage.defaults.string(forKey: selectedPresetKey) } }
        set {
            ProviderModelConfigurationLock.performMutation {
                if let newValue {
                    VowriteStorage.defaults.set(newValue, forKey: selectedPresetKey)
                } else {
                    VowriteStorage.defaults.removeObject(forKey: selectedPresetKey)
                }
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
        ProviderModelConfigurationLock.performMutation {
            writeAppliedConfiguration(
                configuration,
                presetID: presetID,
                defaults: VowriteStorage.defaults
            )
        }
    }

    /// Deterministic seam used to prove a normal configuration transaction and
    /// the migration share the same lock domain.
    @discardableResult
    static func apply(
        _ configuration: SplitAPIConfiguration,
        presetID: String? = nil,
        defaults: UserDefaults,
        lockDirectory: URL
    ) -> Bool {
        ProviderModelConfigurationLock.withExclusiveLock(
            lockDirectory: lockDirectory,
            unavailable: false
        ) {
            writeAppliedConfiguration(
                configuration,
                presetID: presetID,
                defaults: defaults
            )
            return true
        }
    }

    public static func apply(_ preset: APIPresetOption) {
        apply(preset.configuration, presetID: preset.id)
    }

    /// Migrates renamed IDs and explicitly invalidates built-ins that no
    /// longer have a runnable production path. Endpoint values are preserved;
    /// recovery always requires a visible user choice.
    @discardableResult
    public static func migratePresetIDs() -> PresetIDMigrationResult {
        ProviderModelConfigurationLock.withProductionLock {
            migratePresetIDs(in: VowriteStorage.defaults)
        } ?? .unchanged
    }

    @discardableResult
    static func migratePresetIDs(in defaults: UserDefaults) -> PresetIDMigrationResult {
        let selectedID = defaults.string(forKey: selectedPresetKey)
        if selectedID == "builtin:chinaRecommended" {
            defaults.set("builtin:siliconflowKimi", forKey: selectedPresetKey)
            return .renamed
        }
        if selectedID == BuiltInAPIPreset.localOllama.id {
            defaults.set(selectedID, forKey: invalidatedPresetKey)
            defaults.removeObject(forKey: selectedPresetKey)
            return .invalidatedUnavailablePreset
        }
        return .unchanged
    }

    public static var pendingPresetRecovery: UnavailableAPIPresetRecovery? {
        ProviderModelConfigurationLock.readSnapshot {
            pendingPresetRecovery(in: VowriteStorage.defaults)
        }
    }

    static func pendingPresetRecovery(in defaults: UserDefaults) -> UnavailableAPIPresetRecovery? {
        guard defaults.string(forKey: invalidatedPresetKey)
                == BuiltInAPIPreset.localOllama.id else { return nil }
        return UnavailableAPIPresetRecovery(
            presetID: BuiltInAPIPreset.localOllama.id,
            name: "Local Ollama",
            message: "This preset is unavailable because its speech-to-text engine is not included in this build. Your existing provider and model settings were preserved."
        )
    }

    public static func acknowledgePresetRecoveryKeepingCurrentConfiguration() {
        ProviderModelConfigurationLock.performMutation {
            VowriteStorage.defaults.removeObject(forKey: invalidatedPresetKey)
        }
    }

    public static func clearSelectedPresetIfNeeded(for configuration: SplitAPIConfiguration) {
        if let activePreset, activePreset.configuration == configuration {
            return
        }
        selectedPresetID = nil
        ProviderModelConfigurationLock.performMutation {
            VowriteStorage.defaults.removeObject(forKey: invalidatedPresetKey)
        }
    }

    private static func provider(
        forKey key: String,
        fallback: APIProvider,
        defaults: UserDefaults
    ) -> APIProvider {
        guard let rawValue = defaults.string(forKey: key),
              let provider = APIProvider(rawValue: rawValue) else {
            return fallback
        }
        return provider
    }

    private static func configuration(from defaults: UserDefaults) -> SplitAPIConfiguration {
        let sttProvider = provider(forKey: sttProviderKey, fallback: .groq, defaults: defaults)
        let polishProvider = provider(forKey: polishProviderKey, fallback: .deepseek, defaults: defaults)
        return SplitAPIConfiguration(
            stt: APIEndpointConfiguration(
                provider: sttProvider,
                model: defaults.string(forKey: sttModelKey) ?? "whisper-large-v3-turbo",
                baseURL: defaults.string(forKey: sttBaseURLKey) ?? sttProvider.defaultBaseURL
            ),
            polish: APIEndpointConfiguration(
                provider: polishProvider,
                model: defaults.string(forKey: polishModelKey) ?? "deepseek-flash",
                baseURL: defaults.string(forKey: polishBaseURLKey) ?? polishProvider.defaultBaseURL
            )
        )
    }

    private static func write(_ configuration: SplitAPIConfiguration, to defaults: UserDefaults) {
        write(configuration.stt, capability: .stt, to: defaults)
        write(configuration.polish, capability: .polish, to: defaults)
    }

    private static func writeAppliedConfiguration(
        _ configuration: SplitAPIConfiguration,
        presetID: String?,
        defaults: UserDefaults
    ) {
        write(configuration, to: defaults)
        if let presetID {
            defaults.set(presetID, forKey: selectedPresetKey)
        } else {
            defaults.removeObject(forKey: selectedPresetKey)
        }
        defaults.removeObject(forKey: invalidatedPresetKey)
    }

    private static func write(
        _ endpoint: APIEndpointConfiguration,
        capability: ProviderModelCapability,
        to defaults: UserDefaults
    ) {
        let keys = capability == .stt
            ? (sttProviderKey, sttModelKey, sttBaseURLKey)
            : (polishProviderKey, polishModelKey, polishBaseURLKey)
        defaults.set(endpoint.provider.rawValue, forKey: keys.0)
        defaults.set(endpoint.model, forKey: keys.1)
        // Persist the configured URL, never an OAuth session override.
        defaults.set(endpoint.baseURL, forKey: keys.2)
    }
}
