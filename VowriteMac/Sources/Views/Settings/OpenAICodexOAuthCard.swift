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
        VStack(alignment: .leading, spacing: 6) {
            if isOAuthMode && hasOAuth {
                // Active OAuth session
                HStack(spacing: 8) {
                    Image(systemName: "person.circle.fill").foregroundColor(.green)
                    if let email = storedToken?.email {
                        Text(email).font(.caption)
                    }
                    Text("ChatGPT 订阅登录").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("切换到 API Key") {
                        KeyVault.setPreferredAuthMethod("apiKey", for: .openai)
                    }
                    .font(.caption).buttonStyle(.borderless)
                    Button("退出") {
                        OpenAICodexOAuthService.signOut()
                    }
                    .font(.caption).buttonStyle(.borderless).foregroundColor(.red)
                }
            } else if isOAuthMode && isExpired {
                // Expired OAuth session
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("ChatGPT 会话已过期").font(.caption).foregroundColor(.secondary)
                    Spacer()
                    Button("重新登录") { startOAuthFlow() }
                        .font(.caption).buttonStyle(.borderless)
                    Button("切换到 API Key") {
                        KeyVault.setPreferredAuthMethod("apiKey", for: .openai)
                    }
                    .font(.caption).buttonStyle(.borderless)
                }
            } else {
                // Default: show sign-in option
                HStack(spacing: 8) {
                    Text("没有 API Key？").font(.caption).foregroundColor(.secondary)
                    Button {
                        startOAuthFlow()
                    } label: {
                        Label("使用 ChatGPT Plus/Pro 订阅登录", systemImage: "person.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isAuthenticating)
                }
            }

            if let error = authError {
                Text(error).font(.caption2).foregroundColor(.red)
            }
        }
        .padding(.leading, 152) // align with key input area
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
