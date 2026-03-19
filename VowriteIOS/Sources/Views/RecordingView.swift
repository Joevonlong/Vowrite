import SwiftUI
import VowriteKit

struct RecordingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var waveformPhase: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            // Timer
            Text(formattedDuration)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            // Waveform
            WaveformView(level: appState.audioLevel, phase: waveformPhase)
                .frame(height: 60)
                .padding(.horizontal, 40)

            // Controls
            HStack(spacing: 48) {
                // Cancel button
                Button {
                    appState.cancelRecording()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial, in: Circle())
                }

                // Stop button (large)
                Button {
                    appState.stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 72, height: 72)
                            .shadow(color: .red.opacity(0.4), radius: 10, y: 4)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                waveformPhase = .pi * 2
            }
        }
    }

    private var formattedDuration: String {
        let minutes = Int(appState.recordingDuration) / 60
        let seconds = Int(appState.recordingDuration) % 60
        let tenths = Int((appState.recordingDuration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Waveform

struct WaveformView: View {
    let level: Float
    let phase: Double
    private let barCount = 24

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedIndex = Double(index) / Double(barCount)
                    let wave = sin(normalizedIndex * .pi * 3 + phase)
                    let amplitude = Double(max(level, 0.05))
                    let height = (0.2 + amplitude * (0.5 + wave * 0.3)) * geo.size.height

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(height: max(4, height))
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
}
