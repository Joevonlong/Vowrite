// VowriteMac/Sources/Views/Settings/KimiCodeOAuthCard.swift
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
    private var hasAPIKey: Bool { KeyVault.hasKey(for: .kimi) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kimi（月之暗面）").font(.headline)
                Spacer()
                statusBadge
            }

            if hasOAuth || hasAPIKey {
                Picker("认证方式", selection: Binding(
                    get: { isOAuthMode ? "oauth" : "apiKey" },
                    set: { KeyVault.setPreferredAuthMethod($0, for: .kimi) }
                )) {
                    Text("API Key").tag("apiKey")
                    Text("Kimi Code 账号").tag("oauth")
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
        .sheet(isPresented: $showDeviceFlowSheet, onDismiss: {
            if isAuthenticating { KimiCodeOAuthService.cancelSignIn() }
        }) {
            deviceFlowSheet
        }
    }

    private var statusBadge: some View {
        Group {
            if isExpired && isOAuthMode {
                Label("会话过期", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange).font(.caption)
            } else if isOAuthMode && hasOAuth {
                Label("Kimi Code 登录", systemImage: "checkmark.circle.fill")
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
            Text("Kimi Code Coding Plan").font(.caption).foregroundColor(.secondary)
            Text("Token 消耗计入 Kimi Code 订阅").font(.caption2).foregroundColor(.secondary)
            Text("API 端点：api.kimi.com/coding/v1").font(.caption2.monospaced()).foregroundColor(.secondary)
            Button("退出登录") { KimiCodeOAuthService.signOut() }
                .foregroundColor(.red).buttonStyle(.borderless).font(.caption)

            Divider()
            Text("── 备用 API Key ──").font(.caption2).foregroundColor(.secondary)
            if hasAPIKey {
                Text(KeyVault.maskedKey(for: .kimi) ?? "").font(.caption2.monospaced())
            } else {
                Text("未配置（OAuth 失效时自动降级）").font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private var expiredStateContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(storedToken?.email ?? "user") 的 Kimi Code 会话已过期")
                .font(.callout).foregroundColor(.secondary)
            HStack(spacing: 12) {
                Button("重新登录") { startDeviceFlow() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("切换到 API Key") { KeyVault.setPreferredAuthMethod("apiKey", for: .kimi) }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let masked = KeyVault.maskedKey(for: .kimi) {
                Text("API Key: \(masked)").font(.caption.monospaced()).foregroundColor(.secondary)
            }
        }
    }

    private var signInSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("── 或登录 Kimi Code 订阅账号 ──")
                .font(.caption).foregroundColor(.secondary)
            Button {
                startDeviceFlow()
            } label: {
                Label("Sign in with Kimi Code", systemImage: "lock.fill")
            }
            .buttonStyle(.bordered)
            .disabled(isAuthenticating)
            Text("需要 Kimi Code Coding Plan 订阅")
                .font(.caption2).foregroundColor(.secondary)
        }
    }

    private var deviceFlowSheet: some View {
        VStack(spacing: 24) {
            Text("Sign in with Kimi Code").font(.headline)

            if let code = userCode {
                VStack(spacing: 16) {
                    Text("在浏览器中：").font(.subheadline)
                    VStack(alignment: .leading, spacing: 8) {
                        Label("页面已自动打开 kimi.com/code/activate", systemImage: "1.circle.fill")
                        Label("输入以下授权码：", systemImage: "2.circle.fill")
                    }
                    .font(.callout)

                    HStack(spacing: 12) {
                        Text(formatUserCode(code))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .padding()
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 1.5))

                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(code, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("等待你在浏览器完成登录...").font(.callout).foregroundColor(.secondary)
                    ProgressView().scaleEffect(0.8)
                }
            } else {
                ProgressView("正在获取授权码...")
            }

            HStack(spacing: 12) {
                if let uri = verificationURI {
                    Button("未自动打开？点此手动打开") {
                        if let url = URL(string: uri) { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.borderless).font(.caption).foregroundColor(.accentColor)
                }
                Spacer()
                Button("取消") {
                    KimiCodeOAuthService.cancelSignIn()
                    showDeviceFlowSheet = false
                    isAuthenticating = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(width: 400)
    }

    private func startDeviceFlow() {
        isAuthenticating = true
        authError = nil
        showDeviceFlowSheet = true
        userCode = nil
        verificationURI = nil

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
                // User cancelled
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
