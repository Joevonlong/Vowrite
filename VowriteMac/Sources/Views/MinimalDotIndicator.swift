import SwiftUI
import VowriteKit

struct MinimalDotIndicator: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.035)).frame(width: 44, height: 44)
                .overlay(Circle().stroke(Color.white.opacity(0.25)))
            if appState.isRecording {
                let size: CGFloat = 10 + CGFloat(appState.audioLevel) * 16
                Circle().fill(Color.white).frame(width: size, height: size)
            } else if appState.state == .processing {
                ProgressView().progressViewStyle(OverlayProcessingProgressStyle(diameter: 12))
            }
        }
        .frame(width: 60, height: 60)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: appState.audioLevel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.isRecording ? "Recording" : "Processing")
        .help(appState.isRecording ? "Recording — use your shortcut to finish or Escape to cancel" : "Processing your recording")
    }
}
