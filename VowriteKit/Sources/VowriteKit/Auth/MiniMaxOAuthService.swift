import Foundation
import AuthenticationServices

// MARK: - MiniMax OAuth Error

public enum MiniMaxOAuthError: LocalizedError {
    case paramsNotConfigured
    case unsupportedProvider
    case authSessionFailed(String)
    case noAuthorizationCode
    case tokenExchangeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .paramsNotConfigured:
            return "MiniMax OAuth parameters not yet configured. Use API Key for now."
        case .unsupportedProvider:
            return "MiniMaxOAuthService only supports .minimaxIntl and .minimaxCN providers."
        case .authSessionFailed(let msg):
            return "MiniMax authentication failed: \(msg)"
        case .noAuthorizationCode:
            return "No authorization code received from MiniMax."
        case .tokenExchangeFailed(let msg):
            return "MiniMax token exchange failed: \(msg)"
        }
    }
}

// MARK: - MiniMax OAuth Service

public enum MiniMaxOAuthService {

    // MARK: - OAuth Parameters
    // TODO(F-058): Obtain from OpenClaw minimax-portal plugin source or MiniMax developer support.
    // Blocker: These are not in public MiniMax documentation.
    private static let clientID: String? = nil   // e.g. "your-client-id"
    private static let scopes = "openid profile offline_access"
    static let redirectURI = "com.vowrite.app:/oauth2redirect"

    // MARK: - Region-Specific Endpoints

    private struct RegionEndpoints {
        let authorize: String
        let token: String
        let baseURL: String
    }

    private static func endpoints(for provider: APIProvider) throws -> RegionEndpoints {
        switch provider {
        case .minimaxIntl:
            return RegionEndpoints(
                authorize: "https://minimax.io/oauth/authorize",
                token: "https://minimax.io/oauth/token",
                baseURL: "https://api.minimax.io/v1"
            )
        case .minimaxCN:
            return RegionEndpoints(
                authorize: "https://minimaxi.com/oauth/authorize",
                token: "https://minimaxi.com/oauth/token",
                baseURL: "https://api.minimaxi.com/v1"
            )
        default:
            throw MiniMaxOAuthError.unsupportedProvider
        }
    }

    // MARK: - Sign In

    @MainActor
    public static func signIn(provider: APIProvider,
                              presentationAnchor: ASPresentationAnchor) async throws -> OAuthToken {
        guard let clientID, !clientID.isEmpty else {
            throw MiniMaxOAuthError.paramsNotConfigured
        }
        let endpoints = try endpoints(for: provider)

        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)

        var components = URLComponents(string: endpoints.authorize)!
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: scopes),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            throw MiniMaxOAuthError.authSessionFailed("Could not build authorization URL")
        }

        let callbackScheme = redirectURI.components(separatedBy: ":").first ?? "com.vowrite.app"
        let code: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let bridge = PresentationContextBridge(anchor: presentationAnchor)
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [bridge] callbackURL, error in
                _ = bridge  // keep bridge alive until callback fires
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    continuation.resume(throwing: MiniMaxOAuthError.authSessionFailed(error.localizedDescription))
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: MiniMaxOAuthError.noAuthorizationCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = bridge
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        return try await exchangeCode(code: code, verifier: verifier,
                                      provider: provider, endpoints: endpoints)
    }

    // MARK: - Token Exchange

    private static func exchangeCode(code: String, verifier: String,
                                     provider: APIProvider,
                                     endpoints: RegionEndpoints) async throws -> OAuthToken {
        guard let clientID, let url = URL(string: endpoints.token) else {
            throw MiniMaxOAuthError.paramsNotConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code=\(code)",
            "client_id=\(clientID)",
            "redirect_uri=\(redirectURI)",
            "grant_type=authorization_code",
            "code_verifier=\(verifier)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw MiniMaxOAuthError.tokenExchangeFailed("HTTP error: \(body)")
        }

        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
            let email: String?
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(Double($0)) }
        let token = OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiresAt: expiresAt,
            email: tokenResponse.email,
            baseURL: endpoints.baseURL
        )
        OAuthTokenStore.save(token, for: provider.providerID)
        return token
    }

    // MARK: - Refresh

    public static func refresh(refreshToken: String, providerID: String) async {
        guard let provider = APIProvider.availableCases.first(where: { $0.providerID == providerID }),
              let endpoints = try? endpoints(for: provider) else { return }
        let stored = OAuthTokenStore.load(for: providerID)

        guard let clientID, let url = URL(string: endpoints.token) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientID)",
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }

        struct TokenResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Int?
        }
        guard let tokenResponse = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            OAuthTokenStore.delete(for: providerID)
            return
        }
        let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(Double($0)) }
        let newToken = OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? refreshToken,
            expiresAt: expiresAt,
            email: stored?.email,
            baseURL: endpoints.baseURL
        )
        OAuthTokenStore.save(newToken, for: providerID)
    }

    // MARK: - Sign Out

    public static func signOut(provider: APIProvider) {
        OAuthTokenStore.delete(for: provider.providerID)
        VowriteStorage.defaults.removeObject(forKey: "auth.method.\(provider.providerID)")
    }
}

// MARK: - Presentation Context Bridge (internal)

/// Wraps an ASPresentationAnchor as an ASWebAuthenticationPresentationContextProviding.
final class PresentationContextBridge: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
