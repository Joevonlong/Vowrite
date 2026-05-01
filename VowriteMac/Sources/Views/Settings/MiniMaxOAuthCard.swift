import SwiftUI
import VowriteKit
import AuthenticationServices

struct MiniMaxOAuthCard: View {
    let provider: APIProvider

    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: provider) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: provider) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: provider.providerID) }
    private var isExpired: Bool { storedToken?.isExpired ?? false }
    private var hasAPIKey: Bool { KeyVault.hasKey(for: provider) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(provider.id).font(.headline)
                Spacer()
                statusBadge
            }

            if hasOAuth || hasAPIKey {
                Picker("认证方式", selection: Binding(
                    get: { isOAuthMode ? "oauth" : "apiKey" },
                    set: { KeyVault.setPreferredAuthMethod($0, for: provider) }
                )) {
                    Text("API Key").tag("apiKey")
                    Text("Coding Plan 账号").tag("oauth")
                }
                .pickerStyle(.segmented)
            }

            if isExpired && isOAuthMode {
                expiredStateContent
            } else if isOAuthMode && hasOAuth {
                oauthActiveContent
            } else {
                apiKeySection
                Divider().padding(.vertical, 4)
                signInSection
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
                Label("Coding Plan 登录", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.caption)
            } else if hasAPIKey {
                Label("已配置", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green).font(.caption)
            }
        }
    }

    private var oauthActiveContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = storedToken?.email {
                Label(email, systemImage: "person.circle")
            }
            Text(provider.oauthLabel ?? "MiniMax Coding Plan")
                .font(.caption).foregroundColor(.secondary)
            Text("Token 消耗计入 MiniMax Coding Plan 订阅")
                .font(.caption2).foregroundColor(.secondary)
            if let baseURL = storedToken?.baseURL {
                Text("端点：\(baseURL)").font(.caption2.monospaced()).foregroundColor(.secondary)
            }
            Button("退出登录") { MiniMaxOAuthService.signOut(provider: provider) }
                .foregroundColor(.red).buttonStyle(.borderless).font(.caption)
        }
    }

    private var expiredStateContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = storedToken?.email {
                Text("\(email) 的 \(provider.id) 会话已过期")
                    .font(.callout).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                Button("重新登录") { startOAuthFlow() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(isAuthenticating)
                Button("切换到 API Key") {
                    KeyVault.setPreferredAuthMethod("apiKey", for: provider)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let masked = KeyVault.maskedKey(for: provider) {
                Text("API Key: \(masked)").font(.caption.monospaced()).foregroundColor(.secondary)
            }
            Text("💡 MiniMax Token Plan 订阅用户：请使用 Token Plan 专属 API Key")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("── 或登录 MiniMax Coding Plan 账号 ──")
                .font(.caption).foregroundColor(.secondary)
            Button { startOAuthFlow() } label: {
                Label(signInButtonLabel, systemImage: "lock.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isAuthenticating)
        }
    }

    private var signInButtonLabel: String {
        provider == .minimaxCN ? "登录 MiniMax 账号" : "Sign in with MiniMax"
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        Task { @MainActor in
            do {
                let anchor = NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
                _ = try await MiniMaxOAuthService.signIn(provider: provider,
                                                         presentationAnchor: anchor)
                KeyVault.setPreferredAuthMethod("oauth", for: provider)
            } catch is CancellationError {
                // User cancelled — no error
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
