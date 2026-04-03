import SwiftUI
import VowriteKit
import AuthenticationServices

struct MiniMaxOAuthCard: View {
    @State private var showRegionPicker = false
    @State private var selectedRegion = "global"
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: .minimax) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: .minimax) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: "minimax") }
    private var isExpired: Bool { storedToken?.isExpired ?? false }

    var body: some View {
        Group {
            if isExpired && isOAuthMode {
                expiredState
            } else if isOAuthMode && hasOAuth {
                oauthActiveState
            } else {
                defaultState
            }
        }
        .confirmationDialog("选择区域", isPresented: $showRegionPicker) {
            Button("Global（国际）") { selectedRegion = "global"; startOAuthFlow() }
            Button("China（中国大陆）") { selectedRegion = "china"; startOAuthFlow() }
            Button("取消", role: .cancel) {}
        }
        if let error = authError {
            Text(error).font(.caption).foregroundColor(.red)
        }
    }

    private var oauthActiveState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(storedToken?.email ?? "MiniMax 账号", systemImage: "person.circle.fill")
            Text("Coding Plan 已登录").font(.caption).foregroundColor(.green)
            Button("退出登录", role: .destructive) { MiniMaxOAuthService.signOut() }
                .font(.caption)
        }
    }

    private var expiredState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MiniMax 会话已过期").foregroundColor(.orange)
            HStack {
                Button("重新登录") { showRegionPicker = true }.buttonStyle(.bordered)
                Button("切换到 API Key") {
                    KeyVault.setPreferredAuthMethod("apiKey", for: .minimax)
                }.buttonStyle(.bordered)
            }
        }
    }

    private var defaultState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Token Plan 用户请使用专属 API Key")
                .font(.caption).foregroundColor(.secondary)
            Button { showRegionPicker = true } label: {
                Label("Sign in with MiniMax Coding Plan", systemImage: "lock.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isAuthenticating)
        }
    }

    private func startOAuthFlow() {
        isAuthenticating = true
        authError = nil
        Task { @MainActor in
            do {
                let scenes = UIApplication.shared.connectedScenes
                let anchor = (scenes.first as? UIWindowScene)?.windows.first ?? ASPresentationAnchor()
                _ = try await MiniMaxOAuthService.signIn(region: selectedRegion,
                                                          presentationAnchor: anchor)
                KeyVault.setPreferredAuthMethod("oauth", for: .minimax)
            } catch is CancellationError {
                // cancelled
            } catch {
                authError = error.localizedDescription
            }
            isAuthenticating = false
        }
    }
}
