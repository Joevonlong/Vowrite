import Foundation
import AuthenticationServices

// MARK: - Auth Mode

public enum AuthMode: String {
    case apiKey = "apiKey"
    case googleAccount = "googleAccount"
}

// MARK: - Auth Manager

@MainActor
public final class AuthManager: NSObject, ObservableObject {
    public static let shared = AuthManager()

    @Published public var isLoggedIn: Bool = false
    @Published public var userEmail: String? = nil
    @Published public var userName: String? = nil
    @Published public var authMode: AuthMode
    @Published public var authError: String? = nil
    @Published public var isAuthenticating: Bool = false

    private var codeVerifier: String?
    private var pendingState: String?
    private var authSession: ASWebAuthenticationSession?

    private static let authModeKey = "authMode"
    private static let googleEmailKey = "googleUserEmail"
    private static let googleNameKey = "googleUserName"

    private override init() {
        let raw = VowriteStorage.defaults.string(forKey: Self.authModeKey) ?? AuthMode.apiKey.rawValue
        self.authMode = AuthMode(rawValue: raw) ?? .apiKey
        super.init()
        restoreGoogleSession()
    }

    // MARK: - Restore Session

    private func restoreGoogleSession() {
        if KeychainHelper.getGoogleAccessToken() != nil {
            isLoggedIn = true
            userEmail = VowriteStorage.defaults.string(forKey: Self.googleEmailKey)
            userName = VowriteStorage.defaults.string(forKey: Self.googleNameKey)
        }
    }

    // MARK: - Google Sign-In (PKCE + ASWebAuthenticationSession)

    public func signInWithGoogle() {
        authError = nil
        isAuthenticating = true

        let verifier = GoogleAuthService.generateCodeVerifier()
        self.codeVerifier = verifier
        let challenge = GoogleAuthService.generateCodeChallenge(from: verifier)
        let state = GoogleAuthService.generateState()
        self.pendingState = state

        let authURL: URL
        do {
            authURL = try GoogleAuthService.authorizationURL(codeChallenge: challenge, state: state)
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

                self.authSession = nil

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

                guard let callbackURL = callbackURL else {
                    self.authError = GoogleAuthError.noAuthorizationCode.localizedDescription
                    self.isAuthenticating = false
                    return
                }

                // CSRF protection: validate state parameter matches the one we sent
                let returnedState = GoogleAuthService.extractState(from: callbackURL)
                guard returnedState != nil, returnedState == self.pendingState else {
                    self.pendingState = nil
                    self.codeVerifier = nil
                    self.authError = "Authentication failed: invalid state parameter (CSRF check failed)."
                    self.isAuthenticating = false
                    return
                }
                self.pendingState = nil

                guard let code = GoogleAuthService.extractAuthorizationCode(from: callbackURL) else {
                    self.authError = GoogleAuthError.noAuthorizationCode.localizedDescription
                    self.isAuthenticating = false
                    return
                }

                await self.exchangeCodeForTokens(code: code)
            }
        }

        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        self.authSession = session
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
                    VowriteStorage.defaults.set(userInfo.email, forKey: Self.googleEmailKey)
                    VowriteStorage.defaults.set(userInfo.name, forKey: Self.googleNameKey)
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

    public func signOut() {
        KeychainHelper.deleteGoogleTokens()
        VowriteStorage.defaults.removeObject(forKey: Self.googleEmailKey)
        VowriteStorage.defaults.removeObject(forKey: Self.googleNameKey)
        isLoggedIn = false
        userEmail = nil
        userName = nil
        authError = nil
    }

    // MARK: - Auth Mode

    public func setAuthMode(_ mode: AuthMode) {
        authMode = mode
        VowriteStorage.defaults.set(mode.rawValue, forKey: Self.authModeKey)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
        #else
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? ASPresentationAnchor()
        #endif
    }
}
