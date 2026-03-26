import VowriteKit
import SwiftUI

// MARK: - Overview Page (formerly Home)

struct OverviewPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
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

                // Statistics — 2x2 grid like Typeless
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    LargeStatCard(
                        icon: "clock",
                        value: formatDuration(appState.totalDictationTime),
                        label: "Total dictation time"
                    )
                    LargeStatCard(
                        icon: "mic",
                        value: formatWordCount(appState.totalWords),
                        label: "Words dictated"
                    )
                    LargeStatCard(
                        icon: "hourglass",
                        value: formatTimeSaved(appState.totalWords),
                        label: "Time saved"
                    )
                    LargeStatCard(
                        icon: "bolt",
                        value: formatWPM(words: appState.totalWords, seconds: appState.totalDictationTime),
                        label: "Average dictation speed"
                    )
                }

                // Quick status cards
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

                // Last dictation preview
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

    // MARK: - Formatting Helpers

    /// Format duration as "X hr Y min" or "Xs" for short durations
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else if totalMinutes > 0 {
            return "\(totalMinutes) min"
        } else {
            return "\(Int(seconds))s"
        }
    }

    /// Format word count with K suffix for large numbers
    private func formatWordCount(_ count: Int) -> String {
        if count >= 10_000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fK words", k)
        } else if count > 0 {
            return "\(count) words"
        }
        return "0 words"
    }

    /// Estimate time saved vs typing (assume ~40 WPM typing speed)
    private func formatTimeSaved(_ totalWords: Int) -> String {
        let typingWPM = 40.0
        let typingMinutes = Double(totalWords) / typingWPM
        let dictationMinutes = appState.totalDictationTime / 60.0
        let savedMinutes = max(0, typingMinutes - dictationMinutes)

        let hours = Int(savedMinutes) / 60
        let minutes = Int(savedMinutes) % 60

        if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "\(minutes) min"
        }
        return "0 min"
    }

    /// Calculate words per minute
    private func formatWPM(words: Int, seconds: TimeInterval) -> String {
        guard seconds > 0 && words > 0 else { return "— WPM" }
        let wpm = Int(Double(words) / (seconds / 60.0))
        return "\(wpm) WPM"
    }
}

// MARK: - Large Stat Card (Typeless-style)

struct LargeStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.body)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
    }
}
