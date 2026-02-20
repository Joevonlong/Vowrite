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
        var sum: Float = 0
        for i in 0..<count {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrtf(sum / Float(max(count, 1)))
        let db = 20 * log10f(max(rms, 1e-6))
        let normalized = max(0, min(1, (db + 50) / 50))
        DispatchQueue.main.async { [weak self] in
            self?.currentLevel = normalized
        }
    }
}
