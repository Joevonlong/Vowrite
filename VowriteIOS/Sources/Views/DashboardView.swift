import SwiftUI
import SwiftData
import VowriteKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var modeManager = ModeManager.shared
    @Query(sort: \DictationRecord.createdAt, order: .reverse) private var records: [DictationRecord]

    @State private var sttTestResult: TestResult?
    @State private var polishTestResult: TestResult?
    @State private var isTesting = false
    @State private var selectedDuration: BGServiceDuration = BGServiceDuration.persisted(in: VowriteStorage.defaults)

    private var keyboardActive: Bool {
        // Primary: check system input modes for our keyboard bundle ID
        let systemDetected = UITextInputMode.activeInputModes.contains { mode in
            let identifier = mode.value(forKey: "identifier") as? String ?? ""
            return identifier.contains("com.vowrite")
        }
        // Fallback: UserDefaults written by the extension
        return systemDetected || VowriteStorage.defaults.bool(forKey: "keyboard_active")
    }

    private var keyboardFullAccess: Bool {
        // Only the extension knows this; requires the keyboard to have been opened at least once
        VowriteStorage.defaults.bool(forKey: "keyboard_full_access")
    }

    enum TestResult {
        case success, failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VW.Spacing.section) {
                    VWIOSPageHeader(title: "Let your thoughts flow.", subtitle: "Your voice is the best place to start.")
                    VStack(alignment: .leading, spacing: 16) {
                        Label("YOUR VOICE, CLEARER", systemImage: "waveform")
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(VW.Colors.Text.secondary)
                        Text("Say it.\nMake it yours.")
                            .font(.largeTitle.weight(.semibold))
                            .tracking(-1)
                        Text("Enable voice service, then use the Vowrite keyboard in any app.")
                            .foregroundStyle(VW.Colors.Text.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .vwIOSCard()
                    backgroundRecordingCard
                    statsCard
                    scenesCard
                    recentRecordsCard
                    statusCard
                    testCard
                }
                .padding(24)
            }
            .background(VW.Colors.Surface.canvas)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .tint(VW.Colors.Action.primary)
        }
    }

    private var scenesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Express it your way").font(.title3.weight(.semibold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .top)], spacing: 12) {
                ForEach(modeManager.modes) { mode in
                    Button { modeManager.select(mode) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: mode.icon).font(.title3)
                            Text(mode.name).font(.subheadline.weight(.semibold))
                            Text(mode.isTranslation ? "Translate your voice" : mode.polishEnabled ? "Clear, natural expression" : "Keep your original words")
                                .font(.caption)
                                .foregroundStyle(VW.Colors.Text.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
                        .padding(16)
                        .background(mode.id == modeManager.currentModeId ? VW.Colors.Action.soft : VW.Colors.Surface.panel, in: RoundedRectangle(cornerRadius: VW.Radius.panel))
                        .overlay(RoundedRectangle(cornerRadius: VW.Radius.panel).stroke(mode.id == modeManager.currentModeId ? VW.Colors.Action.primary : VW.Colors.Border.standard, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(VW.Colors.Action.primary)
                    .accessibilityAddTraits(mode.id == modeManager.currentModeId ? .isSelected : [])
                }
            }
        }
    }

    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent expressions").font(.title3.weight(.semibold))
            if records.isEmpty {
                Text("Your words will appear here after your first dictation.")
                    .foregroundStyle(VW.Colors.Text.secondary)
            } else {
                ForEach(Array(records.prefix(2))) { record in
                    NavigationLink {
                        ResultView(rawTranscript: record.rawTranscript, polishedText: record.polishedText, duration: record.duration, createdAt: record.createdAt)
                    } label: {
                        HistoryRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vwIOSCard()
    }

    // MARK: - Background Recording Card

    private var backgroundRecordingCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Voice Service", systemImage: "waveform")
                        .font(.headline)
                    Text("Keep Vowrite running in background for keyboard recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Toggle(isOn: Binding(
                get: { appState.bgServiceActive },
                set: { newValue in
                    if newValue {
                        appState.backgroundService.activate(duration: selectedDuration)
                        VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                        VowriteStorage.defaults.set(selectedDuration.rawValue, forKey: "bgServiceDuration")
                    } else {
                        appState.backgroundService.deactivate()
                        VowriteStorage.defaults.set(false, forKey: "bgServiceEnabled")
                        VowriteStorage.defaults.removeObject(forKey: "bgServiceActivatedAt")
                    }
                }
            )) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(appState.bgServiceActive ? VW.Colors.Status.success : VW.Colors.Text.secondary.opacity(0.4))
                        .frame(width: 10, height: 10)
                    Text(appState.bgServiceActive ? "Active" : "Inactive")
                        .font(.subheadline)
                        .foregroundStyle(appState.bgServiceActive ? .primary : .secondary)
                }
            }

            if appState.bgServiceActive {
                Picker("Duration", selection: $selectedDuration) {
                    ForEach(BGServiceDuration.allCases) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedDuration) { _, newValue in
                    VowriteStorage.defaults.set(newValue.rawValue, forKey: "bgServiceDuration")
                    VowriteStorage.defaults.removeObject(forKey: "bgServiceActivatedAt")
                    appState.backgroundService.activate(duration: newValue)
                }
            }

            if let remaining = appState.bgServiceRemainingTime, remaining > 0, appState.bgServiceActive {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text("Auto-off in \(formatCountdown(remaining))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                }
            }

            if appState.bgServiceRecording {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                    Text("Recording in progress...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let error = appState.bgServiceError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .vwIOSCard()
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Keyboard Status", systemImage: "keyboard")
                .font(.headline)

            StatusRow(
                title: "Keyboard Added",
                isOK: keyboardActive,
                fixAction: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            )

            StatusRow(
                title: "Full Access Enabled",
                isOK: keyboardFullAccess,
                fixAction: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            )

            if !keyboardFullAccess {
                Text("Please open the Vowrite keyboard at least once to sync status")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }

            StatusRow(
                title: "API Configured",
                isOK: appState.hasAPIKey,
                fixAction: nil
            )
        }
        .vwIOSCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your voice, in numbers", systemImage: "chart.bar")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VW.Spacing.xl) {
                StatCard(icon: "clock", value: formatDuration(appState.totalDictationTime), label: "Total Time")
                StatCard(icon: "mic", value: formatWordCount(appState.totalWords), label: "Words Dictated")
                StatCard(icon: "hourglass", value: formatTimeSaved(appState.totalWords), label: "Time Saved")
                StatCard(icon: "bolt", value: formatWPM(words: appState.totalWords, seconds: appState.totalDictationTime), label: "Avg Speed")
            }
        }
        .vwIOSCard()
    }

    // MARK: - Test Card

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Try your keyboard", systemImage: "keyboard")
                .font(.headline)

            TextField("Switch to Vowrite keyboard and try here...", text: .constant(""))
                .textFieldStyle(.roundedBorder)

            Button {
                runConnectionTest()
            } label: {
                HStack {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isTesting ? "Testing..." : "Test API Connection")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isTesting)

            if let sttResult = sttTestResult {
                testResultRow("STT (\(APIConfig.sttProvider.rawValue))", result: sttResult)
            }
            if let polishResult = polishTestResult {
                testResultRow("Polish (\(APIConfig.polishProvider.rawValue))", result: polishResult)
            }
        }
        .vwIOSCard()
    }

    private func testResultRow(_ label: String, result: TestResult) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            switch result {
            case .success:
                Label("OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            case .failure(let msg):
                Label(msg, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
    }

    private func runConnectionTest() {
        isTesting = true
        sttTestResult = nil
        polishTestResult = nil

        Task {
            // Test Polish (chat completion — real API call)
            do {
                try await APIConnectionTester.testChatCompletion(configuration: APIConfig.polish)
                polishTestResult = .success
            } catch {
                polishTestResult = .failure(error.localizedDescription.prefix(80).description)
            }

            // Test STT (validates API key via /models endpoint)
            do {
                try await APIConnectionTester.testSTTConnection(configuration: APIConfig.stt)
                sttTestResult = .success
            } catch {
                sttTestResult = .failure(error.localizedDescription.prefix(80).description)
            }

            isTesting = false
        }
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if totalMinutes > 0 {
            return "\(totalMinutes)m"
        }
        return "\(Int(seconds))s"
    }

    private func formatWordCount(_ count: Int) -> String {
        if count >= 10_000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else if count > 0 {
            return "\(count)"
        }
        return "0"
    }

    private func formatTimeSaved(_ totalWords: Int) -> String {
        let typingWPM = 40.0
        let typingMinutes = Double(totalWords) / typingWPM
        let dictationMinutes = appState.totalDictationTime / 60.0
        let savedMinutes = max(0, typingMinutes - dictationMinutes)
        let hours = Int(savedMinutes) / 60
        let minutes = Int(savedMinutes) % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return "0m"
    }

    private func formatWPM(words: Int, seconds: TimeInterval) -> String {
        guard seconds > 0 && words > 0 else { return "—" }
        let wpm = Int(Double(words) / (seconds / 60.0))
        return "\(wpm) WPM"
    }
}

// MARK: - Supporting Views

private struct StatusRow: View {
    let title: String
    let isOK: Bool
    let fixAction: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .red)
            Text(title)
                .font(.subheadline)
            Spacer()
            if !isOK, let action = fixAction {
                Button("Fix", action: action)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: VW.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.body)
            Text(value)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VW.Spacing.xl)
        .background(VW.Colors.Surface.secondary, in: RoundedRectangle(cornerRadius: VW.Radius.xl))
    }
}

// MARK: - Shared iOS presentation

/// Native counterparts of the Open Design panel and page heading.
/// These helpers only style content; their callers retain all state and actions.
struct VWIOSPageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title.weight(.semibold)).tracking(-0.6)
                .foregroundStyle(VW.Colors.Text.primary)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle).font(.subheadline)
                .foregroundStyle(VW.Colors.Text.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VWIOSCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(VW.Colors.Surface.panel, in: RoundedRectangle(cornerRadius: VW.Radius.panel))
            .overlay(RoundedRectangle(cornerRadius: VW.Radius.panel).stroke(VW.Colors.Border.standard, lineWidth: 1))
    }
}

private struct VWIOSForm: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(VW.Colors.Surface.canvas)
            .tint(VW.Colors.Action.primary)
            .accentColor(VW.Colors.Action.primary)
            .transaction { transaction in
                if reduceMotion { transaction.animation = nil; transaction.disablesAnimations = true }
            }
    }
}

extension View {
    func vwIOSCard() -> some View { modifier(VWIOSCard()) }
    func vwIOSForm() -> some View { modifier(VWIOSForm()) }
}
