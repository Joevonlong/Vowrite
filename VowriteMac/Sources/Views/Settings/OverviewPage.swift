import VowriteKit
import SwiftUI
import SwiftData

struct OverviewPageView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var modeManager = ModeManager.shared
    @Query(sort: \DictationRecord.createdAt, order: .reverse) private var records: [DictationRecord]
    @State private var showMoreStats = false

    private var shortcut: String {
        HotkeyDisplay.string(keyCode: appState.hotkeyManager.keyCode, modifiers: appState.hotkeyManager.modifiers)
    }

    private var statusLabel: String {
        switch appState.state {
        case .recording: return "Recording"
        case .processing: return "Processing"
        case .error: return "Needs attention"
        case .idle:
            guard appState.hasAPIKey else { return "Setup needed" }
            return MacPermissionManager.hasMicrophoneAccess() ? "Ready to record" : "Microphone needed"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview").font(.system(size: 32, weight: .semibold))
                            Text("Make room for your next thought.")
                                .foregroundStyle(VW.Colors.Text.secondary)
                        }
                        Spacer(minLength: 0)
                        Label(statusLabel, systemImage: appState.isRecording ? "mic.fill" : "circle.fill")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(VW.Colors.Action.soft, in: Capsule())
                            .foregroundStyle(VW.Colors.Action.primary)
                    }

                    hero(showArtwork: geometry.size.width > 700)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 16) {
                        LargeStatCard(icon: "text.bubble", value: "\(records.count)", label: "Dictations")
                        LargeStatCard(icon: "waveform", value: formatWordCount(appState.totalWords), label: "Words dictated")
                        LargeStatCard(icon: "clock", value: formatDuration(appState.totalDictationTime), label: "Recording time")
                    }
                    DisclosureGroup("More statistics", isExpanded: $showMoreStats) {
                        HStack(spacing: 16) {
                            LargeStatCard(icon: "hourglass", value: formatTimeSaved(appState.totalWords), label: "Estimated time saved")
                            LargeStatCard(icon: "bolt", value: formatWPM(words: appState.totalWords, seconds: appState.totalDictationTime), label: "Average dictation speed")
                        }
                        .padding(.top, 12)
                        Text("Time saved compares your dictation time with typing at 40 words per minute.")
                            .font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    .font(.callout)

                    sceneSection

                    if geometry.size.width > 920 {
                        HStack(alignment: .top, spacing: 24) {
                            recentSection.frame(maxWidth: .infinity)
                            configurationSection.frame(width: 260)
                        }
                    } else {
                        recentSection
                        configurationSection
                    }
                }
                .frame(maxWidth: 1160, alignment: .leading)
                .padding(32)
                .frame(maxWidth: .infinity)
            }
            .background(VW.Colors.Surface.canvas)
        }
    }

    private func hero(showArtwork: Bool) -> some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 16) {
                Label("YOUR VOICE, CLEARLY EXPRESSED", systemImage: "waveform")
                    .font(.system(size: 11, weight: .semibold)).tracking(1)
                    .foregroundStyle(VW.Colors.Action.primary)
                Text("Speak naturally.\nWrite beautifully.")
                    .font(.system(size: 34, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Capture a thought and let Vowrite help you shape it.")
                    .foregroundStyle(VW.Colors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Button {
                        appState.toggleRecording()
                    } label: {
                        Label(appState.isRecording ? "Finish recording" : appState.state == .processing ? "Processing…" : "Start speaking", systemImage: appState.isRecording ? "checkmark" : "mic")
                            .padding(.horizontal, 8).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!appState.hasAPIKey || appState.state == .processing)
                    .accessibilityIdentifier("overview.record")
                    Text(shortcut)
                        .font(.system(.callout, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(VW.Colors.Surface.secondary, in: RoundedRectangle(cornerRadius: 6))
                }
                if appState.isRecording {
                    Button("Cancel recording", role: .cancel) { appState.cancelRecording() }
                }
                if case .error(let message) = appState.state {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(VW.Colors.Status.error)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showArtwork {
                HStack(spacing: 6) {
                    ForEach(Array([28.0, 48, 76, 106, 64, 88, 40, 24].enumerated()), id: \.offset) { _, height in
                        Capsule().fill(VW.Colors.Action.primary).frame(width: 6, height: height)
                    }
                }
                .frame(width: 160, height: 160)
                .background(VW.Colors.Surface.canvas, in: Circle())
                .accessibilityHidden(true)
            }
        }
        .padding(32)
        .overviewPanel()
    }

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Your scenes", action: "Manage", destination: .personalization)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                ForEach(modeManager.modes) { mode in
                    let selected = mode.id == modeManager.currentModeId
                    Button {
                        modeManager.select(mode)
                        PerAppModeManager.shared.noteManualModeSwitch()
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: mode.icon).font(.title3)
                                Spacer()
                                if selected { Image(systemName: "checkmark.circle.fill") }
                            }
                            Text(mode.name).font(.body.weight(.medium))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(mode.isTranslation ? "Translate your voice" : mode.polishEnabled ? "Polished expression" : "Natural dictation")
                                .font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .padding(16)
                        .background(selected ? VW.Colors.Action.soft : VW.Colors.Surface.panel)
                        .clipShape(RoundedRectangle(cornerRadius: VW.Radius.panel))
                        .overlay(RoundedRectangle(cornerRadius: VW.Radius.panel).stroke(selected ? VW.Colors.Action.primary : VW.Colors.Border.standard))
                        .foregroundStyle(selected ? VW.Colors.Action.primary : VW.Colors.Text.primary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Recent dictations", action: "View all", destination: .history)
            VStack(alignment: .leading, spacing: 16) {
                if let result = appState.lastResult {
                    HStack {
                        Text("Last result").font(.callout.weight(.medium))
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        } label: { Label("Copy", systemImage: "doc.on.doc") }
                        .buttonStyle(.borderless)
                    }
                    Text(result).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    if !records.isEmpty { Divider() }
                }
                ForEach(Array(records.prefix(3))) { record in
                    Button { WindowHelper.openMainWindow(destination: .history, recordID: record.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.createdAt, style: .date)
                                Text(record.createdAt, style: .time)
                                Spacer()
                                Text(formatDuration(record.duration)).monospacedDigit()
                            }
                            .font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                            Text(record.polishedText).lineLimit(2).multilineTextAlignment(.leading)
                                .foregroundStyle(VW.Colors.Text.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if record.id != records.prefix(3).last?.id { Divider() }
                }
                if records.isEmpty && appState.lastResult == nil {
                    Label("Your first dictation will appear here.", systemImage: "text.bubble")
                        .foregroundStyle(VW.Colors.Text.secondary)
                        .frame(maxWidth: .infinity, minHeight: 96)
                }
                if appState.historyUnavailable {
                    Label("History is temporarily unavailable. This session will not be saved.", systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(VW.Colors.Status.warning)
                }
            }
            .padding(24).overviewPanel()
        }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeading("Your setup", action: "Configure", destination: .models)
            VStack(alignment: .leading, spacing: 20) {
                setupValue("Speech recognition", value: APIConfig.current.stt.model, icon: "waveform")
                setupValue("Text polish", value: APIConfig.current.polish.model, icon: "sparkles")
                Divider()
                Button { WindowHelper.openMainWindow(destination: .apiKeys) } label: {
                    Label(appState.hasAPIKey ? "Credentials configured" : "Set up provider keys", systemImage: appState.hasAPIKey ? "checkmark.circle" : "key")
                        .foregroundStyle(appState.hasAPIKey ? VW.Colors.Status.success : VW.Colors.Status.warning)
                }.buttonStyle(.plain)
                Button { WindowHelper.openMainWindow(destination: .general) } label: {
                    Label(MacPermissionManager.hasMicrophoneAccess() && MacPermissionManager.hasAccessibilityAccess() ? "All permissions granted" : "Review permissions", systemImage: "lock.shield")
                }.buttonStyle(.plain)
            }
            .font(.callout)
            .padding(24).overviewPanel()
        }
    }

    private func setupValue(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(VW.Colors.Text.secondary)
            Text(value).font(.callout.weight(.medium)).textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionHeading(_ title: String, action: String, destination: SidebarItem) -> some View {
        HStack {
            Text(title).font(.system(size: 20, weight: .semibold))
            Spacer()
            Button(action) { WindowHelper.openMainWindow(destination: destination) }
                .buttonStyle(.borderless).font(.callout)
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

// MARK: - Overview Surfaces

private extension View {
    func overviewPanel() -> some View {
        background(VW.Colors.Surface.panel, in: RoundedRectangle(cornerRadius: VW.Radius.panel))
            .overlay(RoundedRectangle(cornerRadius: VW.Radius.panel).stroke(VW.Colors.Border.standard))
    }
}

struct LargeStatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).foregroundStyle(VW.Colors.Action.primary)
            Text(value)
                .font(.system(size: 26, weight: .medium))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(label).font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .padding(20).overviewPanel()
    }
}
