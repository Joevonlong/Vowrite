import Foundation

public enum APIConfigMigration {
    private static let migrationFlagKey = "splitAPI.migration.v1.complete"

    private static let legacyGlobalProviderKey = "apiProvider"
    private static let legacyGlobalBaseURLKey = "apiBaseURL"
    private static let legacyGlobalSTTModelKey = "apiSTTModel"
    private static let legacyGlobalPolishModelKey = "apiPolishModel"

    private static let legacyDualEnabledKey = "dualAPI_enabled"
    private static let legacyDualSTTProviderKey = "dualAPI_sttProvider"
    private static let legacyDualSTTBaseURLKey = "dualAPI_sttBaseURL"
    private static let legacyDualSTTModelKey = "dualAPI_sttModel"
    private static let legacyDualPolishProviderKey = "dualAPI_polishProvider"
    private static let legacyDualPolishBaseURLKey = "dualAPI_polishBaseURL"
    private static let legacyDualPolishModelKey = "dualAPI_polishModel"

    private static let legacyGenericAccounts = ["vowrite_api_key", "openai"]
    private static let legacySTTAccounts = ["vowrite_stt_api_key"]
    private static let legacyPolishAccounts = ["vowrite_polish_api_key"]

    public static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationFlagKey) else { return }

        let configuration = migratedConfiguration()
        APIConfig.apply(configuration, presetID: APIPresetStore.matchingPreset(for: configuration)?.id)
        migrateKeys(for: configuration)

        UserDefaults.standard.set(true, forKey: migrationFlagKey)
    }

    private static func migratedConfiguration() -> SplitAPIConfiguration {
        if UserDefaults.standard.bool(forKey: legacyDualEnabledKey) {
            let sttProvider = provider(forKey: legacyDualSTTProviderKey, fallback: .groq)
            let polishProvider = provider(forKey: legacyDualPolishProviderKey, fallback: .deepseek)

            return SplitAPIConfiguration(
                stt: APIEndpointConfiguration(
                    provider: sttProvider,
                    model: string(forKey: legacyDualSTTModelKey) ?? sttProvider.defaultSTTModel,
                    baseURL: string(forKey: legacyDualSTTBaseURLKey) ?? sttProvider.defaultBaseURL
                ),
                polish: APIEndpointConfiguration(
                    provider: polishProvider,
                    model: string(forKey: legacyDualPolishModelKey) ?? polishProvider.defaultPolishModel,
                    baseURL: string(forKey: legacyDualPolishBaseURLKey) ?? polishProvider.defaultBaseURL
                )
            )
        }

        let provider = provider(forKey: legacyGlobalProviderKey, fallback: .groq)
        let baseURL = string(forKey: legacyGlobalBaseURLKey) ?? provider.defaultBaseURL
        return SplitAPIConfiguration(
            stt: APIEndpointConfiguration(
                provider: provider,
                model: string(forKey: legacyGlobalSTTModelKey) ?? provider.defaultSTTModel,
                baseURL: baseURL
            ),
            polish: APIEndpointConfiguration(
                provider: provider,
                model: string(forKey: legacyGlobalPolishModelKey) ?? provider.defaultPolishModel,
                baseURL: baseURL
            )
        )
    }

    private static func migrateKeys(for configuration: SplitAPIConfiguration) {
        let genericKey = legacyGenericAccounts.lazy.compactMap(loadLegacyValue).first
        let sttKey = legacySTTAccounts.lazy.compactMap(loadLegacyValue).first ?? genericKey
        let polishKey = legacyPolishAccounts.lazy.compactMap(loadLegacyValue).first ?? genericKey

        if let sttKey, configuration.stt.provider.requiresAPIKey, !KeyVault.hasKey(for: configuration.stt.provider) {
            _ = KeyVault.saveKey(sttKey, for: configuration.stt.provider)
        }
        if let polishKey, configuration.polish.provider.requiresAPIKey, !KeyVault.hasKey(for: configuration.polish.provider) {
            _ = KeyVault.saveKey(polishKey, for: configuration.polish.provider)
        }
    }

    private static func loadLegacyValue(account: String) -> String? {
        KeychainHelper.getValue(forAccount: account)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
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

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
