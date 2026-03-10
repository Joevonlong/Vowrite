import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Google OAuth Error

enum GoogleAuthError: LocalizedError {
    case missingClientID
    case pkceGenerationFailed
    case authSessionFailed(String)
    case noAuthorizationCode
    case tokenExchangeFailed(String)
    case invalidIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Google OAuth Client ID is not configured. Set it in Settings → API."
        case .pkceGenerationFailed:
            return "Failed to generate PKCE challenge."
        case .authSessionFailed(let msg):
            return "Authentication failed: \(msg)"
        case .noAuthorizationCode:
            return "No authorization code received from Google."
        case .tokenExchangeFailed(let msg):
            return "Token exchange failed: \(msg)"
        case .invalidIDToken:
            return "Could not parse identity from Google token."
        }
    }
}

// MARK: - Google Token Response

struct GoogleTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

// MARK: - Google User Info (decoded from id_token JWT)

struct GoogleUserInfo {
    let email: String
    let name: String?
}

// MARK: - Google Auth Service

enum GoogleAuthService {

    static let redirectURI = "com.vowrite.app:/oauth2redirect"

    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    // MARK: - Client ID
    // TODO: Replace with your Google Cloud OAuth Client ID for com.vowrite.app
    // Create at: console.cloud.google.com → APIs & Services → Credentials → OAuth 2.0 (macOS)
    private static let bundledClientID = ""  // FILL IN AFTER CREATING GOOGLE CLOUD PROJECT

    private static let clientIDKey = "googleOAuthClientID"

    static var clientID: String? {
        get {
            // Allow override via UserDefaults (for development), fallback to bundled
            let override = UserDefaults.standard.string(forKey: clientIDKey) ?? ""
            if !override.isEmpty { return override }
            return bundledClientID.isEmpty ? nil : bundledClientID
        }
        set { UserDefaults.standard.set(newValue, forKey: clientIDKey) }
    }

    // MARK: - PKCE

    static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Build Authorization URL

    static func authorizationURL(codeChallenge: String) throws -> URL {
        guard let clientID = clientID, !clientID.isEmpty else {
            throw GoogleAuthError.missingClientID
        }

        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]

        guard let url = components.url else {
            throw GoogleAuthError.pkceGenerationFailed
        }
        return url
    }

    // MARK: - Extract Authorization Code from Callback URL

    static func extractAuthorizationCode(from callbackURL: URL) -> String? {
        let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    // MARK: - Exchange Code for Tokens

    static func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> GoogleTokenResponse {
        guard let clientID = clientID, !clientID.isEmpty else {
            throw GoogleAuthError.missingClientID
        }

        guard let url = URL(string: tokenEndpoint) else {
            throw GoogleAuthError.tokenExchangeFailed("Invalid token endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code=\(code)",
            "client_id=\(clientID)",
            "redirect_uri=\(redirectURI)",
            "grant_type=authorization_code",
            "code_verifier=\(codeVerifier)",
        ]
        request.httpBody = bodyParams.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleAuthError.tokenExchangeFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            throw GoogleAuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    // MARK: - Decode ID Token (JWT payload, no signature verification for MVP)

    static func decodeIDToken(_ idToken: String) -> GoogleUserInfo? {
        let parts = idToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        // Restore standard Base64
        base64 = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: base64) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let email = json["email"] as? String else { return nil }
        let name = json["name"] as? String
        return GoogleUserInfo(email: email, name: name)
    }
}
