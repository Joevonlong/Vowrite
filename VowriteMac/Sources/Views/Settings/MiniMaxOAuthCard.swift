import SwiftUI
import VowriteKit
import AuthenticationServices

struct MiniMaxOAuthCard: View {
    @State private var showRegionSheet = false
    @State private var selectedRegion = "global"
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: .minimax) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: .minimax) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: "minimax") }
    private var isExpired: Bool { storedToken?.isExpired ?? false }
    private var hasAPIKey: Bool { KeyVault.hasKey(for: .minimax) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MiniMax").font(.headline)
                Spacer()
                statusBadge
            }

            if hasOAuth || hasAPIKey {
                Picker("认证方式", selection: Binding(
                    get: { isOAuthMode ? "oauth" : "apiKey" },
                    set: { KeyVault.setPreferredAuthMethod($0, for: .minimax) }
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
        .sheet(isPresented: $showRegionSheet) {
            regionSheet
        }
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
            Text("MiniMax Coding Plan").font(.caption).foregroundColor(.secondary)
            Text("Token 消耗计入 MiniMax Coding Plan 订阅")
                .font(.caption2).foregroundColor(.secondary)
            if let baseURL = storedToken?.baseURL {
                Text("端点：\(baseURL)").font(.caption2.monospaced()).foregroundColor(.secondary)
            }
            Button("退出登录") { MiniMaxOAuthService.signOut() }
                .foregroundColor(.red).buttonStyle(.borderless).font(.caption)
        }
    }

    private var expiredStateContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let email = storedToken?.email {
                Text("\(email) 的 MiniMax 会话已过期")
                    .font(.callout).foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                Button("重新登录") { showRegionSheet = true }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("切换到 API Key") {
                    KeyVault.setPreferredAuthMethod("apiKey", for: .minimax)
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let masked = KeyVault.maskedKey(for: .minimax) {
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
            Button { showRegionSheet = true } label: {
                Label("Sign in with MiniMax", systemImage: "lock.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isAuthenticating)
        }
    }

    private var regionSheet: some View {
        VStack(spacing: 20) {
            Text("Sign in with MiniMax").font(.headline)
            Text("选择服务器区域：").font(.subheadline)
            VStack(alignment: .leading, spacing: 12) {
                regionButton(label: "Global (api.minimax.io)",
                             subtitle: "适合中国大陆以外的用户", region: "global")
                regionButton(label: "China (api.minimaxi.com)",
                             subtitle: "适合中国大陆用户（低延迟）", region: "china")
            }
            .padding()
            HStack(spacing: 12) {
                Button("取消") { showRegionSheet = false }.buttonStyle(.bordered)
                Button("继续登录") {
                    showRegionSheet = false
                    startOAuthFlow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAuthenticating)
            }
        }
        .padding(32)
        .frame(width: 360)
    }

    private func regionButton(label: String, subtitle: String, region: String) -> some View {
        Button { selectedRegion = region } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selectedRegion == region ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selectedRegion == region ? .accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.body)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        Task { @MainActor in
            do {
                let anchor = NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
                _ = try await MiniMaxOAuthService.signIn(region: selectedRegion,
                                                         presentationAnchor: anchor)
                KeyVault.setPreferredAuthMethod("oauth", for: .minimax)
            } catch is CancellationError {
                // User cancelled — no error
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
