import Foundation

/// Pure classification of OAuth token-refresh failures, shared by every OAuth
/// provider's refresh flow.
///
/// A refresh call can fail for many reasons — a flaky 5xx, an HTML error page
/// from a proxy, a plain network hiccup — and only a narrow subset of those
/// actually mean the refresh token itself is dead. Deleting the token (forcing
/// a full re-auth) on every decode failure, as the previous code did, silently
/// signs users out on transient failures that have nothing to do with the
/// token's validity.
///
/// Per RFC 6749 §5.2, a 400/401 response whose body is a well-formed OAuth
/// error envelope with an `invalid_grant`-class code means the refresh token
/// is truly unusable and re-authentication is required. Everything else —
/// other status codes, malformed/HTML bodies, undecodable JSON — is treated
/// as transient: the caller should keep the existing token and let the next
/// refresh attempt retry.
public enum OAuthErrorClassifier {

    /// OAuth error codes that indicate the refresh token itself is no longer
    /// usable. `invalid_grant` is the RFC 6749 §5.2 code; `expired_token` and
    /// `revoked` are common provider-specific variants of the same condition.
    private static let invalidGrantCodes: Set<String> = [
        "invalid_grant",
        "expired_token",
        "revoked",
    ]

    private struct OAuthErrorEnvelope: Decodable {
        let error: String
    }

    /// Returns true only when the token should be deleted (forcing re-auth).
    /// Returns false for anything transient — the caller keeps the existing
    /// token and simply lets the failed refresh be retried next time.
    public static func shouldInvalidateToken(status: Int, body: Data) -> Bool {
        guard status == 400 || status == 401 else { return false }
        guard let envelope = try? JSONDecoder().decode(OAuthErrorEnvelope.self, from: body) else {
            return false
        }
        return invalidGrantCodes.contains(envelope.error)
    }
}
