import SwiftUI
import VowriteKit

// MARK: - Spectrum Arc Recording Indicator

struct SpectrumArcIndicator: View {
    @ObservedObject var appState: AppState

    private let barCount = 12

    @State private var barLevels: [CGFloat] = Array(repeating: 0.15, count: 12)
    @State private var isRotating = false
    @State private var timer: Timer?

    var body: some View {
        Group {
            switch appState.state {
            case .recording:
                recordingArc
            case .processing:
                processingArc
            default:
                EmptyView()
            }
        }
        .animation(VW.Anim.easeStandard, value: appState.state)
    }

    // MARK: - Recording State

    private var recordingArc: some View {
        ZStack {
            // Arc of bars arranged in a semicircle
            ForEach(0..<barCount, id: \.self) { i in
                let angle = Angle.degrees(-90 + (180.0 / Double(barCount - 1)) * Double(i))
                let barHeight = 6 + barLevels[i] * 20

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: i))
                    .frame(width: 4, height: barHeight)
                    .offset(y: -42)
                    .rotationEffect(angle)
                    .animation(.easeOut(duration: 0.12), value: barLevels[i])
            }

            // Center mic icon
            Image(systemName: "mic.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(width: 120, height: 120)
        .onAppear { startBarAnimation() }
        .onDisappear { stopBarAnimation() }
    }

    // MARK: - Processing State

    private var processingArc: some View {
        ZStack {
            // Rotating arc with reduced bars
            ForEach(0..<barCount, id: \.self) { i in
                let angle = Angle.degrees(-90 + (180.0 / Double(barCount - 1)) * Double(i))

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple.opacity(0.4 + Double(i % 3) * 0.1))
                    .frame(width: 4, height: 10)
                    .offset(y: -42)
                    .rotationEffect(angle)
            }
            .rotationEffect(.degrees(isRotating ? 360 : 0))

            // Processing icon
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: 120, height: 120)
        .onAppear {
            isRotating = false
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                isRotating = true
            }
        }
        .onDisappear { isRotating = false }
    }

    // MARK: - Helpers

    private func barColor(for index: Int) -> Color {
        let t = Double(index) / Double(barCount - 1)
        return Color(hue: 0.75 - t * 0.2, saturation: 0.7, brightness: 0.9)
    }

    private func startBarAnimation() {
        updateBars()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            Task { @MainActor in updateBars() }
        }
    }

    private func stopBarAnimation() {
        timer?.invalidate()
        timer = nil
    }

    private func updateBars() {
        let level = CGFloat(appState.audioLevel)
        for i in 0..<barCount {
            let jitter = CGFloat.random(in: -0.15...0.15)
            barLevels[i] = max(0.08, min(1.0, level + jitter))
        }
    }
}
