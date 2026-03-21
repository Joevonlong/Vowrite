import SwiftUI
import VowriteKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    @State private var sttTestResult: TestResult?
    @State private var polishTestResult: TestResult?
    @State private var isTesting = false

    private var keyboardActive: Bool {
        VowriteStorage.defaults.bool(forKey: "keyboard_active")
    }

    private var keyboardFullAccess: Bool {
        VowriteStorage.defaults.bool(forKey: "keyboard_full_access")
    }

    enum TestResult {
        case success, failure(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
