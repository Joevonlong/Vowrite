import SwiftUI
import VowriteKit

// MARK: - Minimal Dot Recording Indicator

struct MinimalDotIndicator: View {
    @ObservedObject var appState: AppState

    @State private var isBreathing = false
    @State private var colorPhase: Double = 0

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingDot
            case .processing:
                processingDot
            default:
                EmptyView()
            }
        }
        .animation(VW.Anim.easeStandard, value: appState.state)
    }

    // MARK: - Recording State

    private var recordingDot: some View {
        let level = CGFloat(appState.audioLevel)
        let dotSize: CGFloat = 16 + level * 24
        let hue = 0.55 - Double(level) * 0.45

        return Circle()
            .fill(Color(hue: hue, saturation: 0.8, brightness: 0.95))
            .frame(width: dotSize, height: dotSize)
            .shadow(color: Color(hue: hue, saturation: 0.6, brightness: 1.0).opacity(0.5), radius: 8)
            .animation(.easeOut(duration: 0.08), value: appState.audioLevel)
            .frame(width: 60, height: 60)
    }

    // MARK: - Processing State

    private var processingDot: some View {
        let hue = colorPhase

        return Circle()
            .fill(Color(hue: hue, saturation: 0.6, brightness: 0.85))
            .frame(width: isBreathing ? 26 : 18, height: isBreathing ? 26 : 18)
            .shadow(color: Color(hue: hue, saturation: 0.5, brightness: 1.0).opacity(0.4), radius: 6)
            .frame(width: 60, height: 60)
            .onAppear {
                isBreathing = false
                colorPhase = 0.55
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    colorPhase = 1.55
                }
            }
            .onDisappear {
                isBreathing = false
                colorPhase = 0
            }
    }
}
