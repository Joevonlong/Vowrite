import Foundation

/// One-shot repair for a state-corruption bug: `APIConfig.stt`/`.polish` setters
/// used to persist `resolvedBaseURL` — which returns the OAuth-session-scoped
/// override (e.g. Kimi Code's `api.kimi.com/coding/v1`) when one is active —
/// instead of the plain configured base URL. Any settings write made while
/// signed into Kimi Code OAuth therefore baked the coding-plan endpoint into
/// UserDefaults; after sign-out, plain API-key requests kept routing to that
/// endpoint and got rejected with 403.
///
/// This migration resets any stored stt/polish baseURL that still equals the
/// Kimi coding URL back to the provider's configured default, undoing the
/// corruption for users who hit it before the setter fix shipped. It is safe
/// to run unconditionally after that fix: newly-written values can never equal
/// the coding URL unless the user's actual provider default happens to be it
/// (not the case for any provider today).
public enum KimiBaseURLRepairMigration {
    private static let flagKey = "kimi_baseurl_repair.v1.complete"

    /// Pure decision: should `stored` be reset, and if so to what?
    /// Returns nil when no repair is needed.
    static func repairedBaseURL(stored: String, providerDefault: String) -> String? {
        guard stored == KimiCodeOAuthService.kimiCodeBaseURL else { return nil }
        return providerDefault
    }

    public static func runIfNeeded() {
        guard !VowriteStorage.defaults.bool(forKey: flagKey) else { return }

        if let repaired = repairedBaseURL(stored: APIConfig.sttBaseURL, providerDefault: APIConfig.sttProvider.defaultBaseURL) {
            APIConfig.sttBaseURL = repaired
        }
        if let repaired = repairedBaseURL(stored: APIConfig.polishBaseURL, providerDefault: APIConfig.polishProvider.defaultBaseURL) {
            APIConfig.polishBaseURL = repaired
        }

        VowriteStorage.defaults.set(true, forKey: flagKey)
    }
}
