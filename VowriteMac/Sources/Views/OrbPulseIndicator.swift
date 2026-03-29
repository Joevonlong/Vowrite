import SwiftUI
import VowriteKit

// MARK: - Orb Pulse Recording Indicator

struct OrbPulseIndicator: View {
    @ObservedObject var appState: AppState

    @State private var breathScale: CGFloat = 1.0
    @State private var breathOpacity: Double = 0.7
    @State private var rotationAngle: Double = 0.0
    @State private var timer: Timer?

    // Breathing cycle parameters
    private let breathPeriod: Double = 1.2

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
        ZStack {
            // Background glow layer
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 90, height: 90)
                .scaleEffect(breathScale * (1.0 + CGFloat(appState.audioLevel) * 0.4))
                .blur(radius: 20)

            // Audio-reactive outer ring
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 80, height: 80)
                .scaleEffect(1.0 + CGFloat(appState.audioLevel) * 0.5)
                .blur(radius: 15)

            // Core orb with radial gradient
            Circle()
                .fill(RadialGradient(
                    colors: [.orange, .orange.opacity(0.3), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 50
                ))
                .frame(width: 80, height: 80)
                .scaleEffect(breathScale + CGFloat(appState.audioLevel) * 0.2)
                .opacity(breathOpacity)

            // Center mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 100, height: 100)
        .onAppear { startBreathingAnimation() }
        .onDisappear { stopAnimation() }
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
                .rotationEffect(.degrees(rotationAngle))
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
                .symbolEffect(.variableColor.iterative, options: .repeating)
        }
        .frame(width: 100, height: 100)
        .onAppear { startProcessingAnimation() }
        .onDisappear { stopAnimation() }
    }

    // MARK: - Animation Control

    private func startBreathingAnimation() {
        stopAnimation()
        var phase: Double = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                phase += (1.0 / 60.0) / breathPeriod * .pi * 2
                let sine = sin(phase)

                // Base breathing: 1.0 to 1.3
                let baseScale = 1.0 + 0.15 * (1.0 + sine)
                // Audio amplifies scale up to 1.5 at loud levels
                let audioBoost = CGFloat(appState.audioLevel) * 0.2
                breathScale = CGFloat(baseScale) + audioBoost

                // Opacity oscillates 0.5 to 0.9
                breathOpacity = 0.7 + 0.2 * sine
            }
        }
    }

    private func startProcessingAnimation() {
        stopAnimation()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            Task { @MainActor in
                // Slow rotation: ~8 seconds per full turn
                rotationAngle += 360.0 / (8.0 * 60.0)
                if rotationAngle >= 360 { rotationAngle -= 360 }
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
