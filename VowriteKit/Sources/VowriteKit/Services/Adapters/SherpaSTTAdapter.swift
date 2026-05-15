import Foundation
import AVFoundation

/// STT adapter for SherpaOnnx local offline speech recognition.
/// Requires sherpa-onnx XCFramework to be linked.
///
/// Models are downloaded on-demand via SherpaModelManager.
/// Three model tiers:
/// - sensevoice-small (~20MB): Chinese/English/Japanese/Korean/Cantonese, fastest
/// - zipformer-en (~236MB): High-accuracy English
/// - fire-red-asr2 (~1GB): Chinese + English + 20+ dialects
///
/// This adapter is a scaffold — actual sherpa-onnx C API calls are behind
/// `#if canImport(SherpaOnnx)` guards. Without the framework, transcribe()
/// throws .engineNotAvailable.
public final class SherpaSTTAdapter: STTAdapter {

    public func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String {
        defer { try? FileManager.default.removeItem(at: audioURL) }
        // 1. Ensure model is downloaded
        let modelID = model.isEmpty ? "sensevoice-small" : model
        let modelPath = try await SherpaModelManager.shared.ensureModel(modelID)

        // 2. Convert audio to PCM Float32 16kHz mono (sherpa-onnx format)
        let samples = try readAudioSamples(audioURL)

        // 3. Run offline recognition
        #if canImport(SherpaOnnx)
        return try performRecognition(modelPath: modelPath, modelID: modelID, samples: samples)
        #else
        throw SherpaError.engineNotAvailable
        #endif
    }

    // MARK: - Audio Reading

    /// Read audio file and convert to Float32 samples at 16kHz mono.
    private func readAudioSamples(_ audioURL: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: audioURL)
        let sourceFormat = file.processingFormat

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw SherpaError.audioConversionFailed
        }

        let ratio = 16000.0 / sourceFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(file.length) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            throw SherpaError.audioConversionFailed
        }

        let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: sourceBuffer)

        var error: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error {
            throw SherpaError.audioConversionError(error.localizedDescription)
        }

        guard let floatData = outputBuffer.floatChannelData else {
            throw SherpaError.audioConversionFailed
        }
        let count = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: floatData[0], count: count))
    }

    // MARK: - Recognition (requires SherpaOnnx framework)

    #if canImport(SherpaOnnx)
    private func performRecognition(modelPath: URL, modelID: String, samples: [Float]) throws -> String {
        // TODO: Implement when sherpa-onnx XCFramework is integrated
        // 1. Create SherpaOnnxOfflineRecognizerConfig based on modelID
        // 2. Create recognizer
        // 3. Create stream, accept waveform, decode
        // 4. Return result text
        throw SherpaError.engineNotAvailable
    }
    #endif
}

// MARK: - Errors

public enum SherpaError: LocalizedError {
    case engineNotAvailable
    case modelNotFound(String)
    case modelDownloadFailed(String)
    case audioConversionFailed
    case audioConversionError(String)
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .engineNotAvailable:
            return "Sherpa offline ASR engine is not available. The SherpaOnnx framework needs to be integrated."
        case .modelNotFound(let id):
            return "Sherpa model '\(id)' not found. Please download it in Settings."
        case .modelDownloadFailed(let msg):
            return "Failed to download Sherpa model: \(msg)"
        case .audioConversionFailed:
            return "Failed to convert audio for offline recognition"
        case .audioConversionError(let msg):
            return "Audio conversion error: \(msg)"
        case .recognitionFailed(let msg):
            return "Offline recognition failed: \(msg)"
        }
    }
}
