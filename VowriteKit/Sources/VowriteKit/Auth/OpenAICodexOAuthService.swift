// VowriteKit/Sources/VowriteKit/Auth/OpenAICodexOAuthService.swift
import Foundation
import AuthenticationServices

// MARK: - OpenAI Codex OAuth Error

public enum OpenAICodexOAuthError: LocalizedError {
    case authSessionFailed(String)
    case noAuthorizationCode
    case tokenExchangeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .authSessionFailed(let msg):   return "OpenAI authentication failed: \(msg)"
        case .noAuthorizationCode:          return "No authorization code received from OpenAI."
        case .tokenExchangeFailed(let msg): return "OpenAI token exchange failed: \(msg)"
        }
    }
}

// MARK: - OpenAI Codex OAuth Service

public enum OpenAICodexOAuthService {

    private static let clientID       = "app_EMoamEEZ73f0CkXaXp7hrann"
    private static let authEndpoint   = "https://auth.openai.com/oauth/authorize"
    private static let tokenEndpoint  = "https://auth.openai.com/oauth/token"
    private static let scopes         = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    static let redirectURI            = "com.vowrite.app:/oauth2redirect"

    // MARK: - Sign In

    @MainActor
    public static func signIn(presentationAnchor: ASPresentationAnchor) async throws -> OAuthToken {
        let verifier  = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.generateCodeChallenge(from: verifier)

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id",             value: clientID),
            URLQueryItem(name: "redirect_uri",          value: redirectURI),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "scope",                 value: scopes),
            URLQueryItem(name: "code_challenge",        value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        guard let authURL = components.url else {
            throw OpenAICodexOAuthError.authSessionFailed("Could not build authorization URL")
        }

        let callbackScheme = redirectURI.components(separatedBy: ":").first ?? "com.vowrite.app"

        // IMPORTANT: PresentationContextBridge is internal to VowriteKit module, accessible here.
        // Must hold strong ref — presentationContextProvider is weak var.
        let bridge = PresentationContextBridge(anchor: presentationAnchor)

        let code: String = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [bridge] callbackURL, error in
                _ = bridge  // keep bridge alive for duration of session
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    continuation.resume(throwing: OpenAICodexOAuthError.authSessionFailed(error.localizedDescription))
                    return
                }
                guard let callbackURL,
                      let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: OpenAICodexOAuthError.noAuthorizationCode)
                    return
                }
                continuation.resume(returning: code)
            }
            session.presentationContextProvider = bridge
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        return try await exchangeCode(code: code, verifier: verifier)
    }

    // MARK: - Token Exchange

    private static func exchangeCode(code: String, verifier: String) async throws -> OAuthToken {
        guard let url = URL(string: tokenEndpoint) else {
            throw OpenAICodexOAuthError.tokenExchangeFailed("Invalid token endpoint")
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
            throw OpenAICodexOAuthError.tokenExchangeFailed("HTTP error: \(body)")
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
            baseURL: nil
        )
        OAuthTokenStore.save(token, for: "openai")
        return token
    }

    // MARK: - Refresh

    public static func refresh(refreshToken: String) async {
        guard let url = URL(string: tokenEndpoint) else { return }
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
            OAuthTokenStore.delete(for: "openai")
            return
        }
        let expiresAt = tokenResponse.expires_in.map { Date().addingTimeInterval(Double($0)) }
        let stored = OAuthTokenStore.load(for: "openai")
        let newToken = OAuthToken(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token ?? refreshToken,
            expiresAt: expiresAt,
            email: stored?.email,
            baseURL: nil
        )
        OAuthTokenStore.save(newToken, for: "openai")
    }

    // MARK: - Sign Out

    public static func signOut() {
        OAuthTokenStore.delete(for: "openai")
        VowriteStorage.defaults.removeObject(forKey: "auth.method.openai")
    }
}
