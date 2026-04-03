import Foundation

public enum KeyVault {
    private static let accountPrefix = "provider."

    /// Providers that need API key management, derived from the Registry.
    public static var managedProviders: [APIProvider] {
        APIProvider.availableCases.filter(\.requiresAPIKey)
    }

    public static func key(for provider: APIProvider) -> String? {
        guard provider.requiresAPIKey else { return nil }
        return normalized(KeychainHelper.getValue(forAccount: account(for: provider)))
    }

    @discardableResult
    public static func saveKey(_ key: String, for provider: APIProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        guard let normalizedKey = normalized(key) else {
            return deleteKey(for: provider)
        }
        return KeychainHelper.saveValue(normalizedKey, forAccount: account(for: provider))
    }

    @discardableResult
    public static func deleteKey(for provider: APIProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        return KeychainHelper.deleteValue(forAccount: account(for: provider))
    }

    public static func hasKey(for provider: APIProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        return key(for: provider) != nil
    }

    public static func maskedKey(for provider: APIProvider) -> String? {
        guard let key = key(for: provider) else { return nil }
        guard key.count > 8 else { return "••••••••" }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }

    public static func requiredProviders(for configuration: SplitAPIConfiguration) -> [APIProvider] {
        var seen = Set<APIProvider>()
        return [configuration.stt.provider, configuration.polish.provider].filter { provider in
            guard provider.requiresAPIKey else { return false }
            return seen.insert(provider).inserted
        }
    }

    public static func missingProviders(for configuration: SplitAPIConfiguration) -> [APIProvider] {
        requiredProviders(for: configuration).filter { !hasKey(for: $0) }
    }

    private static func account(for provider: APIProvider) -> String {
        "\(accountPrefix)\(provider.id)"
    }

    private static func normalized(_ key: String?) -> String? {
        guard let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    // MARK: - OAuth-Aware Credential Resolution

    private static let authMethodPrefix = "auth.method."

    /// The user's preferred auth method for this provider.
    /// Stored in UserDefaults as "auth.method.{providerID}" = "oauth" | "apiKey".
    public static func preferredAuthMethod(for provider: APIProvider) -> String {
        VowriteStorage.defaults.string(forKey: authMethodPrefix + provider.providerID) ?? "apiKey"
    }

    public static func setPreferredAuthMethod(_ method: String, for provider: APIProvider) {
        VowriteStorage.defaults.set(method, forKey: authMethodPrefix + provider.providerID)
    }

    /// Returns the effective API key string for use in HTTP requests.
    /// - OAuth mode + valid token  → access token
    /// - OAuth mode + expired token → falls back to stored API key (silent degradation)
    /// - API key mode              → stored API key
    public static func effectiveKey(for provider: APIProvider) -> String? {
        if preferredAuthMethod(for: provider) == "oauth" {
            if let token = OAuthTokenStore.load(for: provider.providerID), !token.isExpired {
                return token.accessToken
            }
            // Expired or missing — fall back to API key silently
        }
        return key(for: provider)
    }

    /// Returns the OAuth-specific base URL for this provider, if in OAuth mode
    /// and the stored token carries a baseURL override.
    /// Returns nil otherwise (caller uses provider's default from providers.json).
    public static func effectiveBaseURL(for provider: APIProvider) -> String? {
        guard preferredAuthMethod(for: provider) == "oauth" else { return nil }
        return OAuthTokenStore.load(for: provider.providerID)?.baseURL
    }

    /// True if an OAuth token exists and is not expired.
    public static func hasValidOAuthToken(for provider: APIProvider) -> Bool {
        guard let token = OAuthTokenStore.load(for: provider.providerID) else { return false }
        return !token.isExpired
    }
}
