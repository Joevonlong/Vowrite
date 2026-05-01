import Foundation

/// One-shot migration: split legacy `.minimax` provider into `.minimaxIntl` and `.minimaxCN`.
///
/// Per design decision (Plan: minimax-staged-whale), all stored data migrates to CN
/// because the legacy default base URL was `api.minimaxi.com`. OAuth tokens are an
/// exception: they carry their own `baseURL` field and can be routed precisely.
///
/// MUST run before `APIConfigMigration.runIfNeeded()` and before any `APIConfig`
/// read, because the old rawValue `"MiniMax"` no longer resolves to any enum case
/// after the split.
public enum MiniMaxMigration {
    private static let migrationFlagKey = "minimax_split.migration.v1.complete"

    private static let legacyRawValue = "MiniMax"
    private static let cnRawValue = "MiniMax (CN)"
    private static let intlRawValue = "MiniMax (International)"

    private static let legacyProviderID = "minimax"
    private static let cnProviderID = "minimax_cn"
    private static let intlProviderID = "minimax_intl"

    public static func runIfNeeded() {
        guard !VowriteStorage.defaults.bool(forKey: migrationFlagKey) else { return }

        // 1. OAuth token: route by stored baseURL (the only data point that can
        //    distinguish whether the user signed into Intl vs CN).
        let oauthTargetProviderID = migrateOAuthToken()

        // 2. Keychain API key: legacy account "provider.MiniMax" → "provider.MiniMax (CN)".
        migrateAPIKey()

        // 3. UserDefaults auth method: route to whichever providerID got the OAuth token,
        //    or default to CN.
        migrateAuthMethod(targetProviderID: oauthTargetProviderID ?? cnProviderID)

        // 4. SplitAPIConfiguration provider rawValues stored in VowriteStorage.
        migrateSplitConfigRawValues()

        // 5. Legacy v0.1.x UserDefaults.standard keys (defensive: in case
        //    APIConfigMigration hasn't run yet).
        migrateLegacyStandardDefaults()

        VowriteStorage.defaults.set(true, forKey: migrationFlagKey)
    }

    // MARK: - OAuth Token

    /// Returns the providerID the OAuth token was migrated to, or nil if no token existed.
    private static func migrateOAuthToken() -> String? {
        guard let token = OAuthTokenStore.load(for: legacyProviderID) else { return nil }

        let targetProviderID: String
        if let baseURL = token.baseURL, baseURL.contains("minimax.io") {
            targetProviderID = intlProviderID
        } else {
            targetProviderID = cnProviderID
        }

        OAuthTokenStore.save(token, for: targetProviderID)
        OAuthTokenStore.delete(for: legacyProviderID)
        return targetProviderID
    }

    // MARK: - Keychain API Key

    private static func migrateAPIKey() {
        let legacyAccount = "provider.\(legacyRawValue)"
        let cnAccount = "provider.\(cnRawValue)"

        guard let legacyKey = KeychainHelper.getValue(forAccount: legacyAccount),
              !legacyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Don't overwrite an existing CN key.
        if KeychainHelper.getValue(forAccount: cnAccount) == nil {
            _ = KeychainHelper.saveValue(legacyKey, forAccount: cnAccount)
        }
        _ = KeychainHelper.deleteValue(forAccount: legacyAccount)
    }

    // MARK: - Auth Method

    private static func migrateAuthMethod(targetProviderID: String) {
        let legacyKey = "auth.method.\(legacyProviderID)"
        let targetKey = "auth.method.\(targetProviderID)"

        guard let value = VowriteStorage.defaults.string(forKey: legacyKey) else { return }

        if VowriteStorage.defaults.string(forKey: targetKey) == nil {
            VowriteStorage.defaults.set(value, forKey: targetKey)
        }
        VowriteStorage.defaults.removeObject(forKey: legacyKey)
    }

    // MARK: - Split Config Raw Values

    private static func migrateSplitConfigRawValues() {
        let keys = ["splitAPI.stt.provider", "splitAPI.polish.provider"]
        for key in keys {
            if VowriteStorage.defaults.string(forKey: key) == legacyRawValue {
                VowriteStorage.defaults.set(cnRawValue, forKey: key)
            }
        }
    }

    // MARK: - Legacy v0.1.x Standard Defaults

    private static func migrateLegacyStandardDefaults() {
        let keys = [
            "apiProvider",
            "dualAPI_sttProvider",
            "dualAPI_polishProvider",
        ]
        for key in keys {
            if UserDefaults.standard.string(forKey: key) == legacyRawValue {
                UserDefaults.standard.set(cnRawValue, forKey: key)
            }
        }
    }
}
