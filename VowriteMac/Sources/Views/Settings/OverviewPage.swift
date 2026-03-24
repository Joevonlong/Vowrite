import VowriteKit
import SwiftUI

// MARK: - Overview Page (formerly Home)

struct OverviewPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speak naturally, write perfectly")
                        .font(.system(size: 24, weight: .bold))
                    HStack(spacing: 4) {
                        Text("Press")
                        Text(HotkeyDisplay.string(
                            keyCode: appState.hotkeyManager.keyCode,
                            modifiers: appState.hotkeyManager.modifiers
                        ))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(5)
                        .font(.system(.body, design: .monospaced))
                        Text("to start and stop dictation.")
                    }
                    .foregroundColor(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(icon: "clock", value: formatMinutes(appState.totalDictationTime), label: "Total dictation time")
                    StatCard(icon: "mic", value: "\(appState.totalWords)", label: "Words dictated")
                    StatCard(icon: "text.badge.checkmark", value: "\(appState.totalDictations)", label: "Dictations")
                }

                HStack(spacing: 16) {
                    QuickActionCard(
                        title: "API Status",
                        description: appState.hasAPIKey ? "Connected and ready" : "Set up your provider keys to get started",
                        icon: appState.hasAPIKey ? "checkmark.circle.fill" : "key.fill",
                        iconColor: appState.hasAPIKey ? .green : .orange
                    )
                    QuickActionCard(
                        title: "Permissions",
                        description: MacPermissionManager.hasMicrophoneAccess() && MacPermissionManager.hasAccessibilityAccess()
                            ? "All permissions granted" : "Some permissions needed",
                        icon: MacPermissionManager.hasMicrophoneAccess() && MacPermissionManager.hasAccessibilityAccess()
                            ? "lock.open.fill" : "lock.fill",
                        iconColor: MacPermissionManager.hasMicrophoneAccess() && MacPermissionManager.hasAccessibilityAccess()
                            ? .green : .orange
                    )
                }

                if let result = appState.lastResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last dictation").font(.headline)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(result, forType: .string)
                            }
                            .buttonStyle(.bordered).controlSize(.small)
                        }
                        Text(result)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(32)
        }
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 1 { return "\(Int(seconds))s" }
        return "\(mins) min"
    }
}
