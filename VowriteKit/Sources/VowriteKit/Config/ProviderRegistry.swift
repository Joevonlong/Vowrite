import Foundation
import os

/// Singleton registry that loads provider definitions from JSON.
/// All provider metadata queries go through this registry.
public final class ProviderRegistry: @unchecked Sendable {
    public static let shared = ProviderRegistry()

    private static let logger = Logger(subsystem: "com.vowrite.kit", category: "provider")

    private var _providers: [ProviderDefinition] = []
    private var _index: [String: ProviderDefinition] = [:]
    private let lock = NSLock()

    private init() {
        loadBuiltIn()
    }

    // MARK: - Loading

    private func loadBuiltIn() {
        guard let url = Bundle.module.url(forResource: "providers", withExtension: "json") else {
            Self.logger.fault("providers.json not found in VowriteKit bundle — all provider queries will return nil")
            assertionFailure("providers.json not found in VowriteKit bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ProvidersFile.self, from: data)
            lock.lock()
            _providers = file.providers
            _index = Dictionary(uniqueKeysWithValues: file.providers.map { ($0.id, $0) })
            lock.unlock()
        } catch {
            Self.logger.fault("Failed to decode providers.json: \(error as NSError) — all provider queries will return nil")
            assertionFailure("Failed to decode providers.json: \(error)")
        }
    }

    // MARK: - Queries

    public var providers: [ProviderDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return _providers
    }

    public func provider(for id: String) -> ProviderDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return _index[id]
    }

    /// All providers available on the current platform.
    public var availableProviders: [ProviderDefinition] {
        providers.filter { def in
            #if os(iOS)
            return def.platformFilter == nil
            #else
            return true
            #endif
        }
    }

    /// Providers that support STT on the current platform.
    public var sttProviders: [ProviderDefinition] {
        availableProviders.filter(\.hasSTTSupport)
    }

    /// Providers that support Polish on the current platform.
    public var polishProviders: [ProviderDefinition] {
        availableProviders.filter(\.hasPolishSupport)
    }

    /// Providers that require an API key (for KeyVault management).
    public var managedProviders: [ProviderDefinition] {
        availableProviders.filter(\.requiresAPIKey)
    }

    /// Look up STT model description across all providers.
    public func sttModelDescription(_ modelID: String) -> String? {
        for p in providers {
            if let desc = p.sttModelDescription(modelID) {
                return desc
            }
        }
        return nil
    }

    /// Look up Polish model description across all providers.
    public func polishModelDescription(_ modelID: String) -> String? {
        for p in providers {
            if let desc = p.polishModelDescription(modelID) {
                return desc
            }
        }
        return nil
    }

    /// Get the sttAdapter identifier for a provider. Defaults to "openai-compatible".
    public func sttAdapterID(for providerID: String) -> String {
        provider(for: providerID)?.sttAdapter ?? "openai-compatible"
    }

    /// F-073: Returns the `polishOverrides` declared for a specific model in a
    /// specific provider, or nil when the model is unlisted or has no overrides.
    public func polishOverrides(providerID: String, modelID: String) -> [String: JSONValue]? {
        provider(for: providerID)?.polishOverrides(for: modelID)
    }
}
