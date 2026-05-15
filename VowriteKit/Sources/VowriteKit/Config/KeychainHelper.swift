import Security
import Foundation

public enum KeychainHelper {
    private static let service = "com.vowrite.api-key"

    /// iOS uses Keychain Access Group for cross-process sharing.
    /// macOS doesn't need this (same-process Keychain is naturally shared).
    #if os(iOS)
    private static let accessGroup: String? = "C2H6PL267S.com.vowrite.shared"
    #else
    private static let accessGroup: String? = nil
    #endif

    // MARK: - Base Query

    private static func baseQuery(service svc: String, account acct: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecAttrAccount as String: acct
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }

    // MARK: - Generic Keychain Helpers

    @discardableResult
    private static func save(service svc: String, account acct: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let deleteQuery = baseQuery(service: svc, account: acct)
        SecItemDelete(deleteQuery as CFDictionary)

        var addQuery = baseQuery(service: svc, account: acct)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private static func load(service svc: String, account acct: String) -> String? {
        var query = baseQuery(service: svc, account: acct)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service svc: String, account acct: String) {
        let query = baseQuery(service: svc, account: acct)
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

    // MARK: - iOS Keychain Migration

    #if os(iOS)
    /// Migrate keychain items from no-access-group to access-group on first v0.2 launch.
    public static func migrateToAccessGroup() {
        let migrationKey = "keychain_access_group_migrated"
        guard !VowriteStorage.defaults.bool(forKey: migrationKey) else { return }

        // Build provider accounts dynamically from APIProvider.allCases to stay in sync
        // with any future provider additions and avoid the V-011 omission recurrence.
        let providerAccounts = APIProvider.allCases.map { "provider.\($0.id)" }
        let googleOAuthAccounts = ["access_token", "refresh_token", "id_token"]
        let accounts = providerAccounts + googleOAuthAccounts

        let services = [service, googleService]

        for svc in services {
            for acct in accounts {
                // Read old value (no access group)
                let oldQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: svc,
                    kSecAttrAccount as String: acct,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]
                var result: AnyObject?
                let status = SecItemCopyMatching(oldQuery as CFDictionary, &result)
                guard status == errSecSuccess, let data = result as? Data,
                      let value = String(data: data, encoding: .utf8) else { continue }

                // Write new value (with access group) — save() auto-includes group
                save(service: svc, account: acct, value: value)
            }
        }

        VowriteStorage.defaults.set(true, forKey: migrationKey)
    }
    #endif
}
