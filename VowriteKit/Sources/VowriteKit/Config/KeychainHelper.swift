import Security
import Foundation

public enum KeychainHelper {
    private static let service = "com.vowrite.api-key"

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

    // MARK: - Google OAuth Tokens

    private static let googleService = "com.vowrite.google-oauth"

    @discardableResult
    public static func saveGoogleAccessToken(_ token: String) -> Bool {
        save(service: googleService, account: "access_token", value: token)
    }

    public static func getGoogleAccessToken() -> String? {
        load(service: googleService, account: "access_token")
    }

    @discardableResult
    public static func saveGoogleRefreshToken(_ token: String) -> Bool {
        save(service: googleService, account: "refresh_token", value: token)
    }

    public static func getGoogleRefreshToken() -> String? {
        load(service: googleService, account: "refresh_token")
    }

    @discardableResult
    public static func saveGoogleIDToken(_ token: String) -> Bool {
        save(service: googleService, account: "id_token", value: token)
    }

    public static func getGoogleIDToken() -> String? {
        load(service: googleService, account: "id_token")
    }

    public static func deleteGoogleTokens() {
        delete(service: googleService, account: "access_token")
        delete(service: googleService, account: "refresh_token")
        delete(service: googleService, account: "id_token")
    }

    // MARK: - Generic Value

    @discardableResult
    public static func saveValue(_ value: String, forAccount acct: String) -> Bool {
        save(service: service, account: acct, value: value)
    }

    public static func getValue(forAccount acct: String) -> String? {
        load(service: service, account: acct)
    }

    @discardableResult
    public static func deleteValue(forAccount acct: String) -> Bool {
        delete(service: service, account: acct)
        return true
    }
}
