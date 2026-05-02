import Foundation

/// One-shot purge of residual MiniMax OAuth state.
///
/// The MiniMax OAuth flow was never functional — `clientID` was never obtained
/// from MiniMax developer support, so any sign-in attempt would have failed
/// before a token could be saved. The auth-method picker, however, may have
/// been flipped to "oauth" by curious users before the OAuth UI was removed,
/// leaving a stale `auth.method.minimax_*` key that now points at a deleted
/// auth path.
public enum MiniMaxOAuthPurge {
    private static let flagKey = "minimax_oauth.purge.v1.complete"

    public static func runIfNeeded() {
        guard !VowriteStorage.defaults.bool(forKey: flagKey) else { return }
        for providerID in ["minimax_intl", "minimax_cn", "minimax"] {
            OAuthTokenStore.delete(for: providerID)
            VowriteStorage.defaults.removeObject(forKey: "auth.method.\(providerID)")
        }
        VowriteStorage.defaults.set(true, forKey: flagKey)
    }
}
