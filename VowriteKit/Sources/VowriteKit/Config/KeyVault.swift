import Foundation

public enum KeyVault {
    private static let accountPrefix = "provider."

    public static let managedProviders: [APIProvider] = [
        .groq,
        .deepgram,
        .deepseek,
        .openai,
        .openrouter,
        .together,
        .siliconflow,
        .kimi,
        .minimax,
        .volcengine,
        .qwen,
        .gemini,
        .zhipu,
        .claude,
        .custom
    ]

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
}
