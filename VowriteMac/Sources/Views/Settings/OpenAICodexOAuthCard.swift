// VowriteMac/Sources/Views/Settings/OpenAICodexOAuthCard.swift
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
    private var hasAPIKey: Bool { KeyVault.hasKey(for: .openai) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OpenAI").font(.headline)
                Spacer()
                statusBadge
            }

            if hasOAuth || hasAPIKey {
                Picker("认证方式", selection: Binding(
                    get: { isOAuthMode ? "oauth" : "apiKey" },
                    set: { KeyVault.setPreferredAuthMethod($0, for: .openai) }
                )) {
                    Text("API Key").tag("apiKey")
                    Text("ChatGPT 账号").tag("oauth")
                }
                .pickerStyle(.segmented)
            }

            if isExpired && isOAuthMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(storedToken?.email ?? "ChatGPT 账号") 的会话已过期")
                        .font(.callout).foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button("重新登录") { startOAuthFlow() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                        Button("切换到 API Key") { KeyVault.setPreferredAuthMethod("apiKey", for: .openai) }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
            } else if isOAuthMode && hasOAuth {
                VStack(alignment: .leading, spacing: 8) {
                    if let email = storedToken?.email {
                        Label(email, systemImage: "person.circle")
                    }
                    Text("ChatGPT Plus/Pro").font(.caption).foregroundColor(.secondary)
                    Text("Token 消耗计入 ChatGPT 订阅（不计 API 费用）")
                        .font(.caption2).foregroundColor(.secondary)
                    Button("退出登录") { OpenAICodexOAuthService.signOut() }
                        .foregroundColor(.red).buttonStyle(.borderless).font(.caption)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("── 或登录 ChatGPT 订阅账号 ──")
                        .font(.caption).foregroundColor(.secondary)
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
            }

            if let error = authError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var statusBadge: some View {
        Group {
            if isExpired && isOAuthMode {
                Label("会话过期", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange).font(.caption)
            } else if isOAuthMode && hasOAuth {
                Label("ChatGPT 登录", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.caption)
            } else if hasAPIKey {
                Label("已配置", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.caption)
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
