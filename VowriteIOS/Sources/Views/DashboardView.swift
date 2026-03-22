import SwiftUI
import VowriteKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var sttTestResult: TestResult?
    @State private var polishTestResult: TestResult?
    @State private var isTesting = false
    @State private var selectedDuration: BGServiceDuration = {
        let raw = VowriteStorage.defaults.integer(forKey: "bgServiceDuration")
        return BGServiceDuration(rawValue: raw) ?? .always
    }()

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
                VStack(spacing: 20) {
                    // Background Recording Service
                    backgroundRecordingCard

                    // Keyboard Status Card
                    statusCard

                    // Usage Stats
                    statsCard

                    // Quick Test
                    testCard
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }

    // MARK: - Background Recording Card

    private var backgroundRecordingCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Background Recording", systemImage: "waveform.circle.fill")
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
                        .fill(appState.bgServiceActive ? Color.green : Color.gray.opacity(0.4))
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Usage Statistics", systemImage: "chart.bar.fill")
                .font(.headline)

            HStack(spacing: 16) {
                StatItem(value: "\(appState.totalDictations)", label: "Dictations")
                StatItem(value: formatDuration(appState.totalDictationTime), label: "Total Time")
                StatItem(value: "\(appState.totalWords)", label: "Words")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Test Card

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Test", systemImage: "checkmark.seal.fill")
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
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
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

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
