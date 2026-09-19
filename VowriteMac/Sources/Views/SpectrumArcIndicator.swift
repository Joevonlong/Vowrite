import SwiftUI
import VowriteKit

struct SpectrumArcIndicator: View {
    @ObservedObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(Color(white: 0.035)).frame(width: 96, height: 96)
            if appState.isRecording {
                ForEach(0..<12, id: \.self) { index in
                    let angle = Angle.degrees(-90 + 180 / 11 * Double(index))
                    let weight = 1 - abs(CGFloat(index) - 5.5) / 11
                    Capsule().fill(Color.white.opacity(0.65 + Double(weight) * 0.35))
                        .frame(width: 3, height: 5 + CGFloat(appState.audioLevel) * weight * 18)
                        .offset(y: -38)
                        .rotationEffect(angle)
                }
                Image(systemName: "mic.fill").font(.system(size: 20)).foregroundStyle(.white)
            } else if appState.state == .processing {
                Circle().trim(from: 0.1, to: 0.9)
                    .stroke(Color.white.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 76, height: 76)
                ProgressView().progressViewStyle(OverlayProcessingProgressStyle())
            }
        }
        .frame(width: 120, height: 120)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: appState.audioLevel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appState.isRecording ? "Recording" : "Processing")
        .help(appState.isRecording ? "Recording — use your shortcut to finish or Escape to cancel" : "Processing your recording")
    }
}
