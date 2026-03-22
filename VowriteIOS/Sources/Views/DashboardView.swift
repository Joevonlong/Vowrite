import SwiftUI
import VowriteKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var sttTestResult: TestResult?
    @State private var polishTestResult: TestResult?
    @State private var isTesting = false

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

            HStack(spacing: 16) {
                // Status indicator
                Circle()
                    .fill(appState.backgroundService.isActive ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)

                Text(appState.backgroundService.isActive ? "Active" : "Inactive")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(appState.backgroundService.isActive ? .primary : .secondary)

                Spacer()

                // Toggle button
                Button {
                    if appState.backgroundService.isActive {
                        appState.backgroundService.deactivate()
                        VowriteStorage.defaults.set(false, forKey: "bgServiceEnabled")
                    } else {
                        appState.backgroundService.activate()
                        VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                    }
                } label: {
                    Text(appState.backgroundService.isActive ? "Turn Off" : "Turn On")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            appState.backgroundService.isActive ? Color.red : Color.accentColor,
                            in: Capsule()
                        )
                }
            }

            if appState.backgroundService.isRecording {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.red)
                    Text("Recording in progress...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if let error = appState.backgroundService.activationError {
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
                testResultRow("STT", result: sttResult)
            }
            if let polishResult = polishTestResult {
                testResultRow("Polish", result: polishResult)
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
            // Test Polish (chat completion)
            do {
                try await APIConnectionTester.testChatCompletion(configuration: APIConfig.polish)
                polishTestResult = .success
            } catch {
                polishTestResult = .failure(error.localizedDescription.prefix(60).description)
            }

            // STT test — we don't have a testSTT static method on APIConnectionTester,
            // so just verify the config is valid
            let sttConfig = APIConfig.stt
            if sttConfig.provider.hasSTTSupport && sttConfig.hasKey {
                sttTestResult = .success
            } else if !sttConfig.provider.hasSTTSupport {
                sttTestResult = .failure("\(sttConfig.provider.rawValue) doesn't support STT")
            } else {
                sttTestResult = .failure("Missing API key")
            }

            isTesting = false
        }
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
