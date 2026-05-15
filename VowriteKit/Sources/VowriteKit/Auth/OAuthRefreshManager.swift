import Foundation

// MARK: - OAuthRefreshManager
//
// Actor that serialises concurrent token-refresh requests.
// Multiple callers racing on the same providerID (e.g. double-tap recording →
// two CredentialManager.prepareCredentials calls) share a single in-flight Task
// instead of each firing an independent refresh. This prevents the token-rotation
// race on short-TTL providers (Kimi 15-min window) where a second refresh attempt
// with a now-spent refresh_token triggers a server error and token deletion.

public actor OAuthRefreshManager {

    // MARK: - Shared instance

    public static let shared = OAuthRefreshManager()

    // MARK: - In-flight deduplication

    /// Keyed by providerID. A Task is inserted when a refresh starts and removed
    /// when it completes (success or error). Subsequent callers that arrive while
    /// the Task is live simply await its completion.
    private var inFlightTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Refresh threshold

    /// How many minutes before expiry we proactively refresh.
    /// Kimi Code tokens expire in 15 min so need a shorter window.
    private func refreshThreshold(for providerID: String) -> Double {
        switch providerID {
        case "kimi": return 3.0
        default:     return 5.0
        }
    }

    // MARK: - Refresh If Needed

    /// Refreshes the token for a provider if it expires within the safety window.
    /// Concurrent calls for the same providerID join the single in-flight Task —
    /// only one HTTP refresh request is ever sent per expiry cycle.
    public func refreshIfNeeded(for providerID: String) async {
        // Fast path: token is fresh or has no refresh token — no work needed.
        guard let token = OAuthTokenStore.load(for: providerID),
              let refreshToken = token.refreshToken,
              token.expiresWithin(minutes: refreshThreshold(for: providerID)) else { return }

        // If there is already a refresh in flight for this provider, wait for it.
        if let existing = inFlightTasks[providerID] {
            await existing.value
            return
        }

        // We are the first caller — create the task and register it.
        let task = Task<Void, Never> {
            await self.performRefresh(providerID: providerID, refreshToken: refreshToken)
        }
        inFlightTasks[providerID] = task

        // Await completion, then clean up regardless of outcome.
        await task.value
        inFlightTasks.removeValue(forKey: providerID)
    }

    // MARK: - Private

    private func performRefresh(providerID: String, refreshToken: String) async {
        switch providerID {
        case "kimi":
            await KimiCodeOAuthService.refresh(refreshToken: refreshToken)
        case "openai":
            await OpenAICodexOAuthService.refresh(refreshToken: refreshToken)
        default:
            break
        }
    }
}
