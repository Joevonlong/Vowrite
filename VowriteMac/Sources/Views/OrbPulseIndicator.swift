import SwiftUI
import VowriteKit

// MARK: - Orb Pulse Recording Indicator

struct OrbPulseIndicator: View {
    @ObservedObject var appState: AppState

    // Breathing cycle (SwiftUI animation-driven, no Timer)
    @State private var isBreathing = false
    // Processing rotation (SwiftUI animation-driven)
    @State private var isRotating = false

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingOrb
            case .processing:
                processingOrb
            default:
                EmptyView()
            }
        }
        .animation(VW.Anim.easeStandard, value: appState.state)
    }

    // MARK: - Recording State

    private var recordingOrb: some View {
        let level = CGFloat(appState.audioLevel)

        return ZStack {
            // Background glow layer
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 90, height: 90)
                .scaleEffect(isBreathing ? 1.3 : 1.0)
                .scaleEffect(1.0 + level * 0.4)
                .blur(radius: 20)

            // Audio-reactive outer ring
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(1.0 + level * 0.5)
                .blur(radius: 15)
                .animation(.easeOut(duration: 0.1), value: appState.audioLevel)

            // Core orb with radial gradient
            Circle()
                .fill(RadialGradient(
                    colors: [.orange, .orange.opacity(0.3), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 50
                ))
                .frame(width: 80, height: 80)
                .scaleEffect(isBreathing ? 1.3 : 1.0)
                .scaleEffect(1.0 + level * 0.2)
                .opacity(isBreathing ? 0.9 : 0.5)

            // Center mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            isBreathing = false
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
        .onDisappear {
            isBreathing = false
        }
    }

    // MARK: - Processing State

    private var processingOrb: some View {
        ZStack {
            // Background glow — dimmer during processing
            Circle()
                .fill(Color.orange.opacity(0.1))
                .frame(width: 90, height: 90)
                .scaleEffect(1.1)
                .blur(radius: 20)

            // Rotating gradient ring
            Circle()
                .fill(AngularGradient(
                    colors: [.orange.opacity(0.4), .orange.opacity(0.1), .orange.opacity(0.4)],
                    center: .center
                ))
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(isRotating ? 360 : 0))
                .opacity(0.6)

            // Core orb — steady, subdued
            Circle()
                .fill(RadialGradient(
                    colors: [.orange.opacity(0.6), .orange.opacity(0.2), .clear],
                    center: .center,
                    startRadius: 15,
                    endRadius: 45
                ))
                .frame(width: 70, height: 70)

            // Processing icon
            Image(systemName: "ellipsis")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 100, height: 100)
        .onAppear {
            isRotating = false
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
        .onDisappear {
            isRotating = false
        }
    }
}
