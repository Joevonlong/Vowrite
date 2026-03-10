import Foundation

/// F-019: Separate API configuration for STT and Polish pipelines.
/// Falls back to the global APIConfig for backward compatibility.
enum DualAPIConfig {

    // MARK: - STT Pipeline

    private static let sttProviderKey = "dualAPI_sttProvider"
    private static let sttBaseURLKey = "dualAPI_sttBaseURL"
    private static let sttAPIKeyKeychainAccount = "vowrite_stt_api_key"
    private static let sttModelKey = "dualAPI_sttModel"
    private static let dualModeEnabledKey = "dualAPI_enabled"

    /// Whether dual-provider mode is enabled
    static var isDualModeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: dualModeEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: dualModeEnabledKey) }
    }

    // -- STT provider (only used when dual mode is ON) --

    static var sttProvider: APIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: sttProviderKey),
                  let p = APIProvider(rawValue: raw) else { return .groq }
            return p
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sttProviderKey) }
    }

    static var sttBaseURL: String {
        get { UserDefaults.standard.string(forKey: sttBaseURLKey) ?? sttProvider.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: sttBaseURLKey) }
    }

    static var sttModel: String {
        get { UserDefaults.standard.string(forKey: sttModelKey) ?? sttProvider.defaultSTTModel }
        set { UserDefaults.standard.set(newValue, forKey: sttModelKey) }
    }

    static var sttAPIKey: String? {
        get { KeychainHelper.getValue(forAccount: sttAPIKeyKeychainAccount) }
        set {
            if let key = newValue {
                _ = KeychainHelper.saveValue(key, forAccount: sttAPIKeyKeychainAccount)
            } else {
                _ = KeychainHelper.deleteValue(forAccount: sttAPIKeyKeychainAccount)
            }
        }
    }

    // MARK: - Polish Pipeline (uses global APIConfig by default)

    private static let polishProviderKey = "dualAPI_polishProvider"
    private static let polishBaseURLKey = "dualAPI_polishBaseURL"
    private static let polishAPIKeyKeychainAccount = "vowrite_polish_api_key"
    private static let polishModelKey = "dualAPI_polishModel"

    static var polishProvider: APIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: polishProviderKey),
                  let p = APIProvider(rawValue: raw) else { return .openai }
            return p
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: polishProviderKey) }
    }

    static var polishBaseURL: String {
        get { UserDefaults.standard.string(forKey: polishBaseURLKey) ?? polishProvider.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: polishBaseURLKey) }
    }

    static var polishModel: String {
        get { UserDefaults.standard.string(forKey: polishModelKey) ?? polishProvider.defaultPolishModel }
        set { UserDefaults.standard.set(newValue, forKey: polishModelKey) }
    }

    static var polishAPIKey: String? {
        get { KeychainHelper.getValue(forAccount: polishAPIKeyKeychainAccount) }
        set {
            if let key = newValue {
                _ = KeychainHelper.saveValue(key, forAccount: polishAPIKeyKeychainAccount)
            } else {
                _ = KeychainHelper.deleteValue(forAccount: polishAPIKeyKeychainAccount)
            }
        }
    }

    // MARK: - Resolved Config (what the app actually uses)

    /// The effective STT API key (dual or single mode)
    static var effectiveSTTAPIKey: String? {
        if isDualModeEnabled, let key = sttAPIKey, !key.isEmpty { return key }
        return KeychainHelper.getAPIKey()
    }

    /// The effective STT base URL
    static var effectiveSTTBaseURL: String {
        isDualModeEnabled ? sttBaseURL : APIConfig.baseURL
    }

    /// The effective STT model
    static var effectiveSTTModel: String {
        isDualModeEnabled ? sttModel : APIConfig.sttModel
    }

    /// The effective STT provider
    static var effectiveSTTProvider: APIProvider {
        isDualModeEnabled ? sttProvider : APIConfig.provider
    }

    /// The effective Polish API key
    static var effectivePolishAPIKey: String? {
        if isDualModeEnabled, let key = polishAPIKey, !key.isEmpty { return key }
        return KeychainHelper.getAPIKey()
    }

    /// The effective Polish base URL
    static var effectivePolishBaseURL: String {
        isDualModeEnabled ? polishBaseURL : APIConfig.baseURL
    }

    /// The effective Polish model
    static var effectivePolishModel: String {
        isDualModeEnabled ? polishModel : APIConfig.polishModel
    }

    /// The effective Polish provider
    static var effectivePolishProvider: APIProvider {
        isDualModeEnabled ? polishProvider : APIConfig.provider
    }
}
