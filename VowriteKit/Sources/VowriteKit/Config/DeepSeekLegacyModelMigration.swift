import Foundation

/// One-shot migration for DeepSeek's legacy alias retirement: upstream shuts
/// down `deepseek-chat` and `deepseek-reasoner` on 2026-07-24 15:59 UTC
/// (official notice, api-docs.deepseek.com/news/news260424). Any stored
/// configuration still pointing at an alias starts failing with 404s after
/// that date — including pre-F-062 installs whose Recommended preset wrote
/// `deepseek-chat`.
///
/// Rewrites the alias to `deepseek-v4-flash` (DeepSeek's documented chat-tier
/// replacement; polish disables thinking via providers.json overrides, which
/// also matches the reasoner alias's short-task guidance) in three places:
///   1. the global split polish config,
///   2. per-mode polish model overrides,
///   3. user-saved API presets whose polish provider is DeepSeek.
///
/// The alias strings are unambiguous — no other provider exposes these IDs —
/// so matching is by exact model string.
public enum DeepSeekLegacyModelMigration {
    private static let flagKey = "deepseek_legacy_alias.v1.complete"
    static let replacement = "deepseek-v4-flash"
    private static let legacyIDs: Set<String> = ["deepseek-chat", "deepseek-reasoner"]

    /// Pure decision: replacement for a retired alias, nil when unaffected.
    static func migratedModel(_ model: String) -> String? {
        legacyIDs.contains(model) ? replacement : nil
    }

    /// Pure transform over the persisted modes JSON. Returns re-encoded data
    /// when at least one mode's polish override changed; nil when nothing
    /// needed patching or the payload doesn't decode.
    static func migratedModesData(_ data: Data) -> Data? {
        guard var modes = try? JSONDecoder().decode([Mode].self, from: data) else { return nil }
        var changed = false
        for idx in modes.indices {
            if let model = modes[idx].polishModel, let repaired = migratedModel(model) {
                modes[idx].polishModel = repaired
                changed = true
            }
        }
        guard changed else { return nil }
        return try? JSONEncoder().encode(modes)
    }

    public static func runIfNeeded() {
        guard !VowriteStorage.defaults.bool(forKey: flagKey) else { return }

        if let repaired = migratedModel(APIConfig.polishModel) {
            APIConfig.polishModel = repaired
        }

        if let data = VowriteStorage.defaults.data(forKey: StorageKeys.vowriteModes),
           let repaired = migratedModesData(data) {
            VowriteStorage.defaults.set(repaired, forKey: StorageKeys.vowriteModes)
        }

        var presets = APIPresetStore.userPresets
        var presetsChanged = false
        for idx in presets.indices where presets[idx].configuration.polish.provider == .deepseek {
            if let repaired = migratedModel(presets[idx].configuration.polish.model) {
                presets[idx].configuration.polish.model = repaired
                presetsChanged = true
            }
        }
        if presetsChanged {
            APIPresetStore.userPresets = presets
        }

        VowriteStorage.defaults.set(true, forKey: flagKey)
    }
}
