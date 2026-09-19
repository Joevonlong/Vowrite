import SwiftUI
import VowriteKit

struct RippleRingIndicator: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ripple = false

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.035)).frame(width: 64, height: 64)
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.5 - Double(index) * 0.12), lineWidth: 1.5)
                    .frame(width: 48 + CGFloat(index) * 16, height: 48 + CGFloat(index) * 16)
                    .scaleEffect(appState.isRecording ? 1 + CGFloat(appState.audioLevel) * 0.1 + (ripple ? 0.08 : 0) : 1)
            }
            if appState.isRecording {
                Image(systemName: "mic.fill").font(.system(size: 22)).foregroundStyle(.white)
            } else if appState.state == .processing {
                ProgressView().progressViewStyle(OverlayProcessingProgressStyle())
            }
        }
        .frame(width: 100, height: 100)
        .onAppear { animateRipple() }
        .onChange(of: reduceMotion) { _, _ in animateRipple() }
        .onChange(of: appState.state) { _, _ in animateRipple() }
        .onDisappear { ripple = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.isRecording ? "Recording" : "Processing")
        .help(appState.isRecording ? "Recording — use your shortcut to finish or Escape to cancel" : "Processing your recording")
    }

    private func animateRipple() {
        ripple = false
        guard !reduceMotion, appState.isRecording else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { ripple = true }
    }
}
