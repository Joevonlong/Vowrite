import AVFoundation
import Foundation

final class AudioEngine {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var outputURL: URL?
    private(set) var currentLevel: Float = 0

    func startRecording() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("voxa_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? file.write(from: buffer)
            self?.updateLevel(buffer: buffer)
        }

        try engine.start()
        self.audioEngine = engine
        self.audioFile = file
        self.outputURL = url
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil
        currentLevel = 0
        return outputURL
    }

    private func updateLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)

        var peak: Float = 0
        for i in 0..<count {
            let abs = fabsf(channelData[i])
            if abs > peak { peak = abs }
        }

        // Any sound above noise floor → random high value (0.6-1.0) each frame
        // Silent → 0. This keeps the waveform constantly jumping while speaking.
        let db = 20 * log10f(max(peak, 1e-6))
        let output: Float = db > -45 ? Float.random(in: 0.6...1.0) : 0.0

        DispatchQueue.main.async { [weak self] in
            self?.currentLevel = output
        }
    }
}
