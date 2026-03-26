import AVFoundation
import Foundation

/// Pure-code sound feedback: generates short WAV tones at runtime, no bundled audio files.
/// Supports preheating (pre-generate + cache) and a user-facing enable/disable toggle.
public enum SoundFeedback {

    private static let storageKey = "soundFeedbackEnabled"

    public static var isEnabled: Bool {
        get { !VowriteStorage.defaults.bool(forKey: "soundFeedbackDisabled") }
        set { VowriteStorage.defaults.set(!newValue, forKey: "soundFeedbackDisabled") }
    }

    // MARK: - Cached players

    private static var startPlayer: AVAudioPlayer?
    private static var successPlayer: AVAudioPlayer?
    private static var errorPlayer: AVAudioPlayer?

    /// Pre-generate all WAV data so first playback is instant. Call once at app launch.
    public static func warmUp() {
        startPlayer = makePlayer(tone: .start)
        successPlayer = makePlayer(tone: .success)
        errorPlayer = makePlayer(tone: .error)
    }

    // MARK: - Playback

    public static func playStart() {
        guard isEnabled else { return }
        play(startPlayer ?? makePlayer(tone: .start))
    }

    public static func playSuccess() {
        guard isEnabled else { return }
        play(successPlayer ?? makePlayer(tone: .success))
    }

    public static func playError() {
        guard isEnabled else { return }
        play(errorPlayer ?? makePlayer(tone: .error))
    }

    private static func play(_ player: AVAudioPlayer?) {
        player?.currentTime = 0
        player?.play()
    }

    // MARK: - Tone generation

    private enum Tone {
        case start, success, error
    }

    private static func makePlayer(tone: Tone) -> AVAudioPlayer? {
        let data: Data
        switch tone {
        case .start:
            // Short rising ping: C5→E5 (523→659 Hz), 80ms
            data = generateTone(frequencies: [523, 659], durations: [0.04, 0.04], volume: 0.3)
        case .success:
            // Cheerful two-note chime: G5→C6 (784→1047 Hz), 120ms
            data = generateTone(frequencies: [784, 1047], durations: [0.06, 0.06], volume: 0.25)
        case .error:
            // Low thud: A3 (220 Hz), 100ms
            data = generateTone(frequencies: [220], durations: [0.10], volume: 0.35)
        }
        return try? AVAudioPlayer(data: data)
    }

    /// Generate a WAV with sequential sine wave segments, each with a fade envelope.
    private static func generateTone(frequencies: [Double], durations: [Double], volume: Float) -> Data {
        let sampleRate: Double = 44100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16

        var samples = [Int16]()
        for (freq, dur) in zip(frequencies, durations) {
            let count = Int(sampleRate * dur)
            for i in 0..<count {
                let t = Double(i) / sampleRate
                // Sine wave with fade-in/fade-out envelope
                let fadeIn = min(Double(i) / (sampleRate * 0.005), 1.0) // 5ms fade-in
                let fadeOut = min(Double(count - i) / (sampleRate * 0.01), 1.0) // 10ms fade-out
                let envelope = fadeIn * fadeOut
                let sample = sin(2.0 * .pi * freq * t) * envelope * Double(volume)
                samples.append(Int16(clamping: Int(sample * Double(Int16.max))))
            }
        }

        return wavData(samples: samples, sampleRate: UInt32(sampleRate), channels: channels, bitsPerSample: bitsPerSample)
    }

    private static func wavData(samples: [Int16], sampleRate: UInt32, channels: UInt16, bitsPerSample: UInt16) -> Data {
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count) * UInt32(blockAlign)

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1)) // PCM
        data.appendLittleEndian(channels)
        data.appendLittleEndian(sampleRate)
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)
        data.append("data".data(using: .ascii)!)
        data.appendLittleEndian(dataSize)

        for sample in samples {
            data.appendLittleEndian(sample)
        }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}
