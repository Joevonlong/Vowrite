// VowriteMac/Sources/Views/Settings/OpenAICodexOAuthCard.swift
import SwiftUI
import VowriteKit
import AuthenticationServices

/// Compact OAuth section shown below the standard OpenAI API Key row.
/// Allows ChatGPT Plus/Pro users to sign in with their subscription account
/// as an alternative to providing an API Key.
struct OpenAICodexOAuthSection: View {
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: .openai) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: .openai) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: "openai") }
    private var isExpired: Bool { storedToken?.isExpired ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: VW.Spacing.xl) {
            Text("Connect with your ChatGPT Plus or Pro subscription.")
                .font(.system(size: 13))
                .foregroundStyle(VW.Colors.Text.secondary)
            if isOAuthMode && hasOAuth {
                // Active OAuth session
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill").foregroundColor(VW.Colors.Status.success)
                    if let email = storedToken?.email {
                        Text(email).font(.caption)
                    }
                    Text("ChatGPT connected").font(.caption).foregroundColor(VW.Colors.Text.secondary)
                    Spacer()
                    Button("Use API Key") {
                        KeyVault.setPreferredAuthMethod("apiKey", for: .openai)
                    }
                    .font(.caption).buttonStyle(.borderless)
                    Button("Sign Out") {
                        OpenAICodexOAuthService.signOut()
                    }
                    .font(.caption).buttonStyle(.borderless).foregroundColor(VW.Colors.Status.error)
                }
            } else if isOAuthMode && isExpired {
                // Expired OAuth session
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(VW.Colors.Status.warning)
                    Text("ChatGPT session expired").font(.caption).foregroundColor(VW.Colors.Text.secondary)
                    Spacer()
                    Button("Sign In Again") { startOAuthFlow() }
                        .font(.caption).buttonStyle(.borderless)
                    Button("Use API Key") {
                        KeyVault.setPreferredAuthMethod("apiKey", for: .openai)
                    }
                    .font(.caption).buttonStyle(.borderless)
                }
            } else {
                // Default: show sign-in option
                HStack(spacing: 8) {
                    Button {
                        startOAuthFlow()
                    } label: {
                        Label("Sign In with ChatGPT", systemImage: "person.circle")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(isAuthenticating)
                }
            }

            if isAuthenticating {
                HStack(spacing: VW.Spacing.md) {
                    ProgressView().controlSize(.small)
                    Text("Waiting for sign-in…")
                        .font(.system(size: 13))
                        .foregroundStyle(VW.Colors.Text.secondary)
                }
            }

            if let error = authError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundColor(VW.Colors.Status.error)
            }
        }
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        Task { @MainActor in
            do {
                let anchor = NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
                _ = try await OpenAICodexOAuthService.signIn(presentationAnchor: anchor)
                KeyVault.setPreferredAuthMethod("oauth", for: .openai)
            } catch is CancellationError {
                // User cancelled
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
