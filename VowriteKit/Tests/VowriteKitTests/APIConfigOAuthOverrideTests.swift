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
        OAuthTokenStore.delete(for: "kimi")
        UserDefaults.standard.removeObject(forKey: authMethodKey)
        UserDefaults.standard.removeObject(forKey: sttProviderKey)
        UserDefaults.standard.removeObject(forKey: sttModelKey)
        UserDefaults.standard.removeObject(forKey: sttBaseURLKey)
    }

    func testSettingSTTWhileOAuthOverrideActiveDoesNotPersistOverrideURL() {
        // Arrange: simulate an active Kimi Code OAuth session with a base-URL
        // override, exactly as KeyVault.effectiveBaseURL resolves it in production.
        let token = OAuthToken(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            email: "test@example.com",
            baseURL: KimiCodeOAuthService.kimiCodeBaseURL
        )
        XCTAssertTrue(OAuthTokenStore.save(token, for: "kimi"))
        KeyVault.setPreferredAuthMethod("oauth", for: .kimi)

        // Precondition: the override really is active before exercising the setter.
        XCTAssertEqual(KeyVault.effectiveBaseURL(for: .kimi), KimiCodeOAuthService.kimiCodeBaseURL)

        let plainURL = "https://api.moonshot.cn/v1"
        let config = APIEndpointConfiguration(provider: .kimi, model: "moonshot-v1-8k", baseURL: plainURL)
        XCTAssertEqual(
            config.resolvedBaseURL, KimiCodeOAuthService.kimiCodeBaseURL,
            "precondition: resolvedBaseURL should reflect the OAuth override"
        )

        // Act
        APIConfig.stt = config

        // Assert: the stored value is the plain URL, not the OAuth-resolved one.
        XCTAssertEqual(APIConfig.sttBaseURL, plainURL)
        XCTAssertNotEqual(APIConfig.sttBaseURL, KimiCodeOAuthService.kimiCodeBaseURL)
    }
}
