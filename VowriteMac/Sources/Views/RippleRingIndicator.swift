import SwiftUI
import VowriteKit

// MARK: - Ripple Ring Recording Indicator

struct RippleRingIndicator: View {
    @ObservedObject var appState: AppState

    @State private var ripplePhase = false
    @State private var isBreathing = false

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingRipple
            case .processing:
                processingRipple
            default:
                EmptyView()
            }
        }
        .animation(VW.Anim.easeStandard, value: appState.state)
    }

    // MARK: - Recording State

    private var recordingRipple: some View {
        let level = CGFloat(appState.audioLevel)

        return ZStack {
            // Ripple rings — 4 concentric circles expanding outward
            ForEach(0..<4, id: \.self) { i in
                let delay = Double(i) * 0.3
                let baseScale: CGFloat = 0.4 + CGFloat(i) * 0.25
                let audioBoost: CGFloat = level * 0.3

                Circle()
                    .stroke(Color.cyan.opacity(ripplePhase ? 0.0 : 0.4 - Double(i) * 0.08), lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(ripplePhase ? baseScale + 0.6 + audioBoost : baseScale)
                    .animation(
                        .easeOut(duration: 1.5 - level * 0.4)
                            .repeatForever(autoreverses: false)
                            .delay(delay),
                        value: ripplePhase
                    )
            }

            // Audio-reactive glow
            Circle()
                .fill(Color.cyan.opacity(0.15 + Double(level) * 0.15))
                .frame(width: 40, height: 40)
                .scaleEffect(1.0 + level * 0.3)
                .blur(radius: 8)
                .animation(.easeOut(duration: 0.1), value: appState.audioLevel)

            // Center mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            ripplePhase = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                ripplePhase = true
            }
        }
        .onDisappear { ripplePhase = false }
    }

    // MARK: - Processing State

    private var processingRipple: some View {
        ZStack {
            // Gentle breathing rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.cyan.opacity(0.2 - Double(i) * 0.05), lineWidth: 1.5)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isBreathing ? 0.7 + CGFloat(i) * 0.15 : 0.5 + CGFloat(i) * 0.15)
            }

            // Steady glow
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 36, height: 36)
                .blur(radius: 6)

            // Processing icon
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 100, height: 100)
        .onAppear {
            isBreathing = false
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onDisappear { isBreathing = false }
    }
}
