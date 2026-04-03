import Foundation

public enum CredentialManager {

    /// Called before each dictation. Proactively refreshes any OAuth tokens
    /// that are close to expiry (within the provider's safety window).
    /// Has a 3-second timeout per provider — if refresh times out, recording
    /// still starts and uses any existing token (or falls back to API key).
    public static func prepareCredentials(for config: SplitAPIConfiguration) async {
        let providers = Set([config.stt.provider.providerID, config.polish.provider.providerID])
        await withTaskGroup(of: Void.self) { group in
            for providerID in providers {
                group.addTask {
                    await refreshWithTimeout(providerID: providerID)
                }
            }
        }
    }

    // MARK: - Private

    private static func refreshWithTimeout(providerID: String) async {
        try? await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await OAuthRefreshManager.refreshIfNeeded(for: providerID)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                throw CancellationError()
            }
            try await group.next()
            group.cancelAll()
        }
    }
}
