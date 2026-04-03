// VowriteIOS/Sources/Views/OpenAICodexOAuthCard.swift
import SwiftUI
import VowriteKit
import AuthenticationServices

struct OpenAICodexOAuthCard: View {
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: .openai) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: .openai) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: "openai") }
    private var isExpired: Bool { storedToken?.isExpired ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isExpired && isOAuthMode {
                Text("ChatGPT 会话已过期").foregroundColor(.orange)
                HStack {
                    Button("重新登录") { startOAuthFlow() }.buttonStyle(.bordered)
                    Button("切换到 API Key") { KeyVault.setPreferredAuthMethod("apiKey", for: .openai) }
                        .buttonStyle(.bordered)
                }
            } else if isOAuthMode && hasOAuth {
                Label(storedToken?.email ?? "ChatGPT 账号", systemImage: "person.circle.fill")
                Text("ChatGPT Plus/Pro 已登录").font(.caption).foregroundColor(.green)
                Button("退出登录", role: .destructive) { OpenAICodexOAuthService.signOut() }
                    .font(.caption)
            } else {
                Button {
                    startOAuthFlow()
                } label: {
                    Label("Sign in with ChatGPT Plus/Pro", systemImage: "lock.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isAuthenticating)
                Text("需要 ChatGPT Plus、Pro 或 Business 订阅")
                    .font(.caption2).foregroundColor(.secondary)
            }
            if let error = authError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        Task { @MainActor in
            do {
                let scenes = UIApplication.shared.connectedScenes
                let anchor = (scenes.first as? UIWindowScene)?.windows.first ?? ASPresentationAnchor()
                _ = try await OpenAICodexOAuthService.signIn(presentationAnchor: anchor)
                KeyVault.setPreferredAuthMethod("oauth", for: .openai)
            } catch is CancellationError {
                // cancelled
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
