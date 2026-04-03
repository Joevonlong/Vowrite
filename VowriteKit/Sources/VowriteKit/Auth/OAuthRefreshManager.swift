import Foundation

public enum OAuthRefreshManager {

    // MARK: - Refresh Threshold

    /// How many minutes before expiry we proactively refresh.
    /// Kimi Code tokens expire in 15 min so need a shorter window.
    static func refreshThreshold(for providerID: String) -> Double {
        switch providerID {
        case "kimi": return 3.0
        default:     return 5.0
        }
    }

    // MARK: - Refresh If Needed

    /// Refreshes the token for a provider if it expires within the safety window.
    /// Does nothing if no token exists, no refresh token, or token is fresh.
    public static func refreshIfNeeded(for providerID: String) async {
        guard let token = OAuthTokenStore.load(for: providerID),
              let refreshToken = token.refreshToken,
              token.expiresWithin(minutes: refreshThreshold(for: providerID)) else { return }

        await performRefresh(providerID: providerID, refreshToken: refreshToken)
    }

    // MARK: - Private

    private static func performRefresh(providerID: String, refreshToken: String) async {
        switch providerID {
        case "minimax":
            await MiniMaxOAuthService.refresh(refreshToken: refreshToken)
        case "kimi":
            await KimiCodeOAuthService.refresh(refreshToken: refreshToken)
        case "openai":
            await OpenAICodexOAuthService.refresh(refreshToken: refreshToken)
        default:
            break
        }
    }
}
