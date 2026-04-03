import Foundation

// MARK: - OAuthToken

public struct OAuthToken: Codable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresAt: Date?
    public let email: String?
    /// Provider-specific base URL override (e.g. Kimi Code uses api.kimi.com/coding/v1).
    /// nil means use the provider's default baseURL from providers.json.
    public let baseURL: String?

    public init(accessToken: String,
                refreshToken: String?,
                expiresAt: Date?,
                email: String?,
                baseURL: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.email = email
        self.baseURL = baseURL
    }

    /// True if the token is definitively past its expiry date.
    public var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() >= exp
    }

    /// True if the token expires within `minutes` minutes.
    public func expiresWithin(minutes: Double) -> Bool {
        guard let exp = expiresAt else { return false }
        return Date().addingTimeInterval(minutes * 60) >= exp
    }
}

// MARK: - OAuthTokenStore

public enum OAuthTokenStore {

    private static let service = "com.vowrite.oauth"

    /// Saves an OAuth token for a provider. Overwrites any existing token.
    @discardableResult
    public static func save(_ token: OAuthToken, for providerID: String) -> Bool {
        guard let data = try? JSONEncoder().encode(token) else { return false }
        let value = data.base64EncodedString()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = "C2H6PL267S.com.vowrite.shared"
        #endif

        SecItemDelete(query as CFDictionary)

        var addQuery = query
        guard let valueData = value.data(using: .utf8) else { return false }
        addQuery[kSecValueData as String] = valueData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        addQuery[kSecAttrSynchronizable as String] = false

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    /// Loads the stored OAuth token for a provider. Returns nil if none exists.
    public static func load(for providerID: String) -> OAuthToken? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = "C2H6PL267S.com.vowrite.shared"
        #endif

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let tokenData = Data(base64Encoded: string) else { return nil }

        return try? JSONDecoder().decode(OAuthToken.self, from: tokenData)
    }

    /// Deletes the stored OAuth token for a provider.
    @discardableResult
    public static func delete(for providerID: String) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID
        ]
        #if os(iOS)
        query[kSecAttrAccessGroup as String] = "C2H6PL267S.com.vowrite.shared"
        #endif
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
