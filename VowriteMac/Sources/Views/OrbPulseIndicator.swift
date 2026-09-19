import SwiftUI
import VowriteKit

struct OrbPulseIndicator: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.035)).frame(width: 72, height: 72)
            if appState.isRecording {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(pulse ? 1.22 : 1)
                    .opacity(pulse ? 0.1 : 0.7)
                Circle().fill(Color.white.opacity(0.14))
                    .frame(width: 44 + CGFloat(appState.audioLevel) * 20, height: 44 + CGFloat(appState.audioLevel) * 20)
                Image(systemName: "mic.fill").font(.system(size: 24)).foregroundStyle(.white)
            } else if appState.state == .processing {
                ProgressView().progressViewStyle(OverlayProcessingProgressStyle())
            }
        }
        .frame(width: 100, height: 100)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: appState.audioLevel)
        .onAppear { animatePulse() }
        .onChange(of: reduceMotion) { _, _ in animatePulse() }
        .onChange(of: appState.state) { _, _ in animatePulse() }
        .onDisappear { pulse = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.isRecording ? "Recording" : "Processing")
        .help(appState.isRecording ? "Recording — use your shortcut to finish or Escape to cancel" : "Processing your recording")
    }

    private func animatePulse() {
        pulse = false
        guard !reduceMotion, appState.isRecording else { return }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
    }
}
