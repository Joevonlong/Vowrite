import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 12) {
            // Status header
            HStack {
                Text("Voxa")
                    .font(.headline)
                Spacer()
                statusBadge
            }

            // No API key warning
            if !appState.hasAPIKey {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                    Text("Set your OpenAI API Key in Settings to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(.orange.opacity(0.1))
                .cornerRadius(6)
            }

            Divider()

            // Record button
            Button(action: { appState.toggleRecording() }) {
                HStack {
                    Image(systemName: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title2)
                        .foregroundColor(appState.isRecording ? .red : .accentColor)
                    Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text("⌥ Space")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!appState.hasAPIKey)

            // Recording indicator
            if appState.isRecording {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(appState.audioLevel > 0.1 ? 1 : 0.5)
                    Text(formatDuration(appState.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    AudioLevelBar(level: appState.audioLevel)
                        .frame(width: 60, height: 12)
                }
                .padding(.vertical, 4)
            }

            // Processing indicator
            if case .processing = appState.state {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Processing...")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }

            // Error
            if case .error(let msg) = appState.state {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Last result
            if let result = appState.lastResult {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Last Result")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(result)
                        .font(.body)
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
            }

            Divider()

            // Bottom actions
            HStack {
                Button("History") {
                    WindowHelper.openHistory()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("Settings...") {
                    WindowHelper.openSettings()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 320)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch appState.state {
        case .idle:
            Text("Ready")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.2))
                .cornerRadius(4)
        case .recording:
            Text("Recording")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.2))
                .cornerRadius(4)
        case .processing:
            Text("Processing")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .cornerRadius(4)
        case .error:
            Text("Error")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.2))
                .cornerRadius(4)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }
}

struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.2))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(level > 0.7 ? .red : level > 0.4 ? .orange : .green)
                        .frame(width: geo.size.width * CGFloat(level))
                }
        }
    }
}
