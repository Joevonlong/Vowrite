import Foundation
import AuthenticationServices

// MARK: - Auth Mode

enum AuthMode: String {
    case apiKey = "apiKey"
    case googleAccount = "googleAccount"
}

// MARK: - Auth Manager

@MainActor
final class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String? = nil
    @Published var userName: String? = nil
    @Published var authMode: AuthMode
    @Published var authError: String? = nil
    @Published var isAuthenticating: Bool = false

    private var codeVerifier: String?

    private static let authModeKey = "authMode"
    private static let googleEmailKey = "googleUserEmail"
    private static let googleNameKey = "googleUserName"

    private override init() {
        let raw = UserDefaults.standard.string(forKey: Self.authModeKey) ?? AuthMode.apiKey.rawValue
        self.authMode = AuthMode(rawValue: raw) ?? .apiKey
        super.init()
        restoreGoogleSession()
    }

    // MARK: - Restore Session

    private func restoreGoogleSession() {
        if KeychainHelper.getGoogleAccessToken() != nil {
            isLoggedIn = true
            userEmail = UserDefaults.standard.string(forKey: Self.googleEmailKey)
            userName = UserDefaults.standard.string(forKey: Self.googleNameKey)
        }
    }

    // MARK: - Google Sign-In (PKCE + ASWebAuthenticationSession)

    func signInWithGoogle() {
        authError = nil
        isAuthenticating = true

        let verifier = GoogleAuthService.generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = GoogleAuthService.generateCodeChallenge(from: verifier)

        let authURL: URL
        do {
            authURL = try GoogleAuthService.authorizationURL(codeChallenge: challenge)
        } catch {
            authError = error.localizedDescription
            isAuthenticating = false
            return
        }

        // Extract scheme from redirect URI for ASWebAuthenticationSession
        let callbackScheme = GoogleAuthService.redirectURI
            .components(separatedBy: ":").first ?? "com.vowrite.app"

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    let nsError = error as NSError
                    // User cancelled — not an error to display
                    if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        self.isAuthenticating = false
                        return
                    }
                    self.authError = error.localizedDescription
                    self.isAuthenticating = false
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = GoogleAuthService.extractAuthorizationCode(from: callbackURL) else {
                    self.authError = GoogleAuthError.noAuthorizationCode.localizedDescription
                    self.isAuthenticating = false
                    return
                }

                await self.exchangeCodeForTokens(code: code)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    private func exchangeCodeForTokens(code: String) async {
        guard let verifier = codeVerifier else {
            authError = "Internal error: missing code verifier."
            isAuthenticating = false
            return
        }

        do {
            let tokenResponse = try await GoogleAuthService.exchangeCodeForTokens(
                code: code,
                codeVerifier: verifier
            )

            // Save tokens to Keychain
            KeychainHelper.saveGoogleAccessToken(tokenResponse.accessToken)
            if let refreshToken = tokenResponse.refreshToken {
                KeychainHelper.saveGoogleRefreshToken(refreshToken)
            }
            if let idToken = tokenResponse.idToken {
                KeychainHelper.saveGoogleIDToken(idToken)

                // Decode user info from id_token
                if let userInfo = GoogleAuthService.decodeIDToken(idToken) {
                    userEmail = userInfo.email
                    userName = userInfo.name
                    UserDefaults.standard.set(userInfo.email, forKey: Self.googleEmailKey)
                    UserDefaults.standard.set(userInfo.name, forKey: Self.googleNameKey)
                }
            }

            isLoggedIn = true
            authError = nil
        } catch {
            authError = error.localizedDescription
        }

        codeVerifier = nil
        isAuthenticating = false
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.deleteGoogleTokens()
        UserDefaults.standard.removeObject(forKey: Self.googleEmailKey)
        UserDefaults.standard.removeObject(forKey: Self.googleNameKey)
        isLoggedIn = false
        userEmail = nil
        userName = nil
        authError = nil
    }

    // MARK: - Auth Mode

    func setAuthMode(_ mode: AuthMode) {
        authMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Self.authModeKey)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
    }
}
