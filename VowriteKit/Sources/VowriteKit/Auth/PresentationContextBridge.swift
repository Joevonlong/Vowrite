import Foundation
import AuthenticationServices

/// Wraps an ASPresentationAnchor as an ASWebAuthenticationPresentationContextProviding.
/// Shared between OAuth services (e.g. OpenAICodexOAuthService) so the same
/// bridge is not redeclared per service.
final class PresentationContextBridge: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let anchor: ASPresentationAnchor
    init(anchor: ASPresentationAnchor) { self.anchor = anchor }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { anchor }
}
