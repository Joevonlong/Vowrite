import Security
import Foundation

enum KeychainHelper {
    private static let service = "com.vowrite.api-key"
    private static let account = "openai"

    // MARK: - Generic Keychain Helpers

    @discardableResult
    private static func save(service svc: String, account acct: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acct
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acct,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private static func load(service svc: String, account acct: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acct,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service svc: String, account acct: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acct
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - API Key

    static func saveAPIKey(_ key: String) -> Bool {
        save(service: service, account: account, value: key)
    }

    static func getAPIKey() -> String? {
        load(service: service, account: account)
    }

    static func deleteAPIKey() {
        delete(service: service, account: account)
    }

    // MARK: - Google OAuth Tokens

    private static let googleService = "com.vowrite.google-oauth"

    @discardableResult
    static func saveGoogleAccessToken(_ token: String) -> Bool {
        save(service: googleService, account: "access_token", value: token)
    }

    static func getGoogleAccessToken() -> String? {
        load(service: googleService, account: "access_token")
    }

    @discardableResult
    static func saveGoogleRefreshToken(_ token: String) -> Bool {
        save(service: googleService, account: "refresh_token", value: token)
    }

    static func getGoogleRefreshToken() -> String? {
        load(service: googleService, account: "refresh_token")
    }

    @discardableResult
    static func saveGoogleIDToken(_ token: String) -> Bool {
        save(service: googleService, account: "id_token", value: token)
    }

    static func getGoogleIDToken() -> String? {
        load(service: googleService, account: "id_token")
    }

    static func deleteGoogleTokens() {
        delete(service: googleService, account: "access_token")
        delete(service: googleService, account: "refresh_token")
        delete(service: googleService, account: "id_token")
    }
}
