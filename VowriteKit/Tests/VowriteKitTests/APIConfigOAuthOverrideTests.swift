import XCTest
@testable import VowriteKit

/// Regression test for the APIConfig setter bug (see the `stt`/`polish` setter
/// comments in APIConfig.swift): while an OAuth override is active for a
/// provider, `resolvedBaseURL` returns the OAuth-scoped URL (e.g. Kimi Code's
/// coding-plan endpoint). The setters must persist only the plain configured
/// `baseURL` — never the resolved one — or every settings write made while
/// signed in bakes the OAuth endpoint into UserDefaults permanently, breaking
/// plain API-key requests after sign-out.
final class APIConfigOAuthOverrideTests: XCTestCase {

    private let authMethodKey = "auth.method.kimi"
    private let sttProviderKey = "splitAPI.stt.provider"
    private let sttModelKey = "splitAPI.stt.model"
    private let sttBaseURLKey = "splitAPI.stt.baseURL"

    override func setUp() {
        super.setUp()
        clearState()
    }

    override func tearDown() {
        clearState()
        super.tearDown()
    }

    private func clearState() {
        UserDefaults.standard.removeObject(forKey: authMethodKey)
        UserDefaults.standard.removeObject(forKey: sttProviderKey)
        UserDefaults.standard.removeObject(forKey: sttModelKey)
        UserDefaults.standard.removeObject(forKey: sttBaseURLKey)
    }

    func testSettingSTTPersistsConfiguredPlainURL() {
        let plainURL = "https://api.moonshot.cn/v1"
        let config = APIEndpointConfiguration(provider: .kimi, model: "moonshot-v1-8k", baseURL: plainURL)

        APIConfig.stt = config

        XCTAssertEqual(APIConfig.sttBaseURL, plainURL)
    }

    func testOAuthEndpointResolverHonorsAuthMethodAndTokenValidity() {
        let validToken = OAuthToken(
            accessToken: "valid-token",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(60),
            email: nil,
            baseURL: KimiCodeOAuthService.kimiCodeBaseURL
        )
        let expiredToken = OAuthToken(
            accessToken: "expired-token",
            refreshToken: "refresh-token",
            expiresAt: Date().addingTimeInterval(-60),
            email: nil,
            baseURL: KimiCodeOAuthService.kimiCodeBaseURL
        )

        XCTAssertEqual(
            KeyVault.oauthBaseURL(preferredAuthMethod: "oauth", token: validToken),
            KimiCodeOAuthService.kimiCodeBaseURL
        )
        XCTAssertNil(KeyVault.oauthBaseURL(preferredAuthMethod: "oauth", token: nil))
        XCTAssertNil(KeyVault.oauthBaseURL(preferredAuthMethod: "apiKey", token: validToken))
        XCTAssertNil(KeyVault.oauthBaseURL(preferredAuthMethod: "oauth", token: expiredToken))
    }
}
