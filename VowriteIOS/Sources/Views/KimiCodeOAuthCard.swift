// VowriteIOS/Sources/Views/KimiCodeOAuthCard.swift
import SwiftUI
import VowriteKit

struct KimiCodeOAuthCard: View {
    @State private var showDeviceFlowSheet = false
    @State private var userCode: String?
    @State private var verificationURI: String?
    @State private var isAuthenticating = false
    @State private var authError: String?

    private var hasOAuth: Bool { KeyVault.hasValidOAuthToken(for: .kimi) }
    private var isOAuthMode: Bool { KeyVault.preferredAuthMethod(for: .kimi) == "oauth" }
    private var storedToken: OAuthToken? { OAuthTokenStore.load(for: "kimi") }
    private var isExpired: Bool { storedToken?.isExpired ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isExpired && isOAuthMode {
                expiredState
            } else if isOAuthMode && hasOAuth {
                oauthActiveState
            } else {
                defaultState
            }
        }
        .sheet(isPresented: $showDeviceFlowSheet, onDismiss: {
            if isAuthenticating { KimiCodeOAuthService.cancelSignIn() }
        }) {
            deviceFlowSheet
        }
        if let error = authError {
            Text(error).font(.caption).foregroundColor(.red)
        }
    }

    private var oauthActiveState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(storedToken?.email ?? "Kimi Code 账号", systemImage: "person.circle.fill")
            Text("Kimi Code 已登录").font(.caption).foregroundColor(.green)
            Text("端点：api.kimi.com/coding/v1").font(.caption2.monospaced()).foregroundColor(.secondary)
            Button("退出登录", role: .destructive) { KimiCodeOAuthService.signOut() }
                .font(.caption)
        }
    }

    private var expiredState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Kimi Code 会话已过期").foregroundColor(.orange)
            HStack {
                Button("重新登录") { startDeviceFlow() }.buttonStyle(.bordered)
                Button("切换到 API Key") { KeyVault.setPreferredAuthMethod("apiKey", for: .kimi) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var defaultState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { startDeviceFlow() } label: {
                Label("Sign in with Kimi Code", systemImage: "lock.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isAuthenticating)
            Text("需要 Kimi Code Coding Plan 订阅")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var deviceFlowSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let code = userCode {
                    Text("在浏览器中输入以下授权码：").font(.subheadline)
                    Text(formatUserCode(code))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("复制授权码", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    Text("等待浏览器完成登录...").foregroundColor(.secondary)
                    ProgressView()
                } else {
                    ProgressView("正在获取授权码...")
                }
            }
            .padding()
            .navigationTitle("Kimi Code 登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        KimiCodeOAuthService.cancelSignIn()
                        showDeviceFlowSheet = false
                        isAuthenticating = false
                    }
                }
            }
        }
    }

    private func startDeviceFlow() {
        isAuthenticating = true
        authError = nil
        showDeviceFlowSheet = true
        userCode = nil

        Task { @MainActor in
            do {
                _ = try await KimiCodeOAuthService.signIn { code, uri in
                    Task { @MainActor in
                        self.userCode = code
                        self.verificationURI = uri
                    }
                }
                KeyVault.setPreferredAuthMethod("oauth", for: .kimi)
                showDeviceFlowSheet = false
            } catch is CancellationError {
                // cancelled
            } catch {
                authError = error.localizedDescription
                showDeviceFlowSheet = false
            }
            isAuthenticating = false
        }
    }

    private func formatUserCode(_ code: String) -> String {
        let clean = code.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        if clean.count == 8 { return "\(clean.prefix(4)) - \(clean.suffix(4))" }
        return code
    }
}
