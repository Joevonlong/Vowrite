import CryptoKit
import Foundation

/// The request surface a model is used on. A model retirement on one
/// capability must never affect the same bare identifier on another surface.
public enum ProviderModelCapability: String, Codable, Sendable {
    case stt
    case polish
}

/// Provider-scoped compatibility rules for model IDs that are known to fail on
/// broadly available provider tiers. Unknown IDs are deliberately preserved so
/// Enterprise and custom-endpoint users keep control of their own deployments.
public enum ProviderModelSafetyRules {
    public static let migrationID = "provider-model-compat-2026-08-v1"

    private struct Key: Hashable {
        let providerID: String
        let capability: ProviderModelCapability
        let model: String
    }

    private struct Rule {
        let key: Key
        let replacement: String

        var canonicalLine: String {
            "\(key.providerID)|\(key.capability.rawValue)|\(key.model)|\(replacement)"
        }
    }

    private static let rules: [Rule] = [
        Rule(key: Key(providerID: "deepseek", capability: .polish, model: "deepseek-chat"), replacement: "deepseek-v4-flash"),
        Rule(key: Key(providerID: "deepseek", capability: .polish, model: "deepseek-reasoner"), replacement: "deepseek-v4-flash"),
        Rule(key: Key(providerID: "groq", capability: .polish, model: "qwen/qwen3-32b"), replacement: "openai/gpt-oss-120b"),
        Rule(key: Key(providerID: "groq", capability: .polish, model: "llama-3.3-70b-versatile"), replacement: "openai/gpt-oss-120b"),
        Rule(key: Key(providerID: "groq", capability: .polish, model: "llama-3.1-8b-instant"), replacement: "openai/gpt-oss-20b"),
        Rule(key: Key(providerID: "siliconflow", capability: .polish, model: "zai-org/GLM-4.6"), replacement: "deepseek-ai/DeepSeek-V3"),
        Rule(key: Key(providerID: "together", capability: .stt, model: "whisper-large-v3"), replacement: "openai/whisper-large-v3"),
    ]

    private static let replacements = Dictionary(
        uniqueKeysWithValues: rules.map { ($0.key, $0.replacement) }
    )

    static let canonicalRuleset = rules
        .map(\.canonicalLine)
        .sorted()
        .joined(separator: "\n")

    /// Always derived from the canonical sorted rule table. A rule edit cannot
    /// accidentally retain a stale handwritten migration hash.
    public static let rulesetHash = SHA256.hash(data: Data(canonicalRuleset.utf8))
        .map { String(format: "%02x", $0) }
        .joined()

    /// Returns a provider-safe model for this request boundary. Only exact
    /// provider + capability + model matches are replaced.
    public static func safeModel(
        providerID: String,
        capability: ProviderModelCapability,
        storedModel: String
    ) -> String {
        replacements[
            Key(providerID: providerID, capability: capability, model: storedModel)
        ] ?? storedModel
    }
}
