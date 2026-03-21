import SwiftUI
import VowriteKit

struct RecordArea: View {
    @ObservedObject var state: KeyboardState
    @State private var isPushToTalk = false

    var body: some View {
        Group {
            switch state.viewState {
            case .idle:
                idleContent
            case .recording:
                recordingContent
            case .processing:
                processingContent
            case .error(let message):
                errorContent(message)
            case .noFullAccess:
                StatusBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: "Please enable Full Access for Vowrite keyboard",
                    actionLabel: "Open Vowrite",
                    action: openContainerApp
                )
            case .noAPIKey:
                StatusBanner(
                    icon: "key.fill",
                    message: "Please configure API Key in Vowrite App",
                    actionLabel: "Open Vowrite",
                    action: { openContainerApp(path: "settings") }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(spacing: 12) {
            recordButton
            Text("Tap to record")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var recordButton: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 80, height: 80)
                .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 2)

            Image(systemName: "mic.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    isPushToTalk = true
                    state.startRecording()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    if isPushToTalk {
                        state.stopRecording()
                        isPushToTalk = false
                    }
                }
        )
        .onTapGesture {
            if state.viewState == .idle {
                state.startRecording()
            }
        }
    }

    // MARK: - Recording

    private var recordingContent: some View {
        VStack(spacing: 16) {
            // Timer
            HStack {
                Spacer()
                Text(formatDuration(state.recordingDuration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)

            // Waveform placeholder
            WaveformView(level: state.audioLevel)
                .frame(height: 40)
                .padding(.horizontal, 24)

            // Controls
            HStack(spacing: 40) {
                Button {
                    state.cancelRecording()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }

                Button {
                    state.stopRecording()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text("Done")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.accentColor)
                }
            }
        }
    }

    // MARK: - Processing

    private var processingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Processing...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .onAppear {
            // Auto-dismiss error after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .error = state.viewState {
                    state.reloadConfiguration()
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration - Double(Int(duration))) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    private func openContainerApp(path: String = "setup") {
        guard let url = URL(string: "vowrite://\(path)") else { return }
        // Extension cannot directly open URLs; use shared UIApplication via selector
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = state.inputViewController
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 3, height: barHeight(for: i))
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let normalizedLevel = CGFloat(min(max(level, 0), 1))
        let centerIndex = CGFloat(barCount) / 2.0
        let distance = abs(CGFloat(index) - centerIndex) / centerIndex
        let base: CGFloat = 4
        let maxExtra: CGFloat = 32
        return base + maxExtra * normalizedLevel * (1.0 - distance * 0.6)
    }
}
