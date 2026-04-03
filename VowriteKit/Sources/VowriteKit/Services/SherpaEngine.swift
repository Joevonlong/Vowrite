import Foundation

/// Wrapper around the sherpa-onnx C API for offline speech recognition.
/// All framework calls are behind `#if canImport(SherpaOnnx)` so this file
/// compiles without the XCFramework linked.
@MainActor
final class SherpaEngine {
    static let shared = SherpaEngine()

    #if canImport(SherpaOnnx)
    private var recognizer: OpaquePointer?
    private var currentModelID: String?
    #endif

    private init() {}

    func transcribe(audioURL: URL, modelID: String, samples: [Float]) async throws -> String {
        #if canImport(SherpaOnnx)
        // Re-create recognizer only if model changed
        if currentModelID != modelID {
            let modelPath = await SherpaModelManager.shared.modelPath(for: modelID)
            recognizer = try createRecognizer(modelPath: modelPath, modelID: modelID)
            currentModelID = modelID
        }
        guard let rec = recognizer else { throw SherpaError.engineNotAvailable }

        let stream = SherpaOnnxCreateOfflineStream(rec)
        defer {
            SherpaOnnxDestroyOfflineStream(stream)
        }

        samples.withUnsafeBufferPointer { ptr in
            SherpaOnnxAcceptWaveformOffline(stream, 16000, ptr.baseAddress, Int32(samples.count))
        }
        SherpaOnnxDecodeOfflineStream(rec, stream)

        let resultPtr = SherpaOnnxGetOfflineStreamResult(stream)
        defer { SherpaOnnxDestroyOfflineStreamResult(resultPtr) }
        let text = resultPtr.flatMap { String(validatingUTF8: $0.pointee.text) } ?? ""
        return text
        #else
        throw SherpaError.engineNotAvailable
        #endif
    }

    #if canImport(SherpaOnnx)
    private func createRecognizer(modelPath: URL, modelID: String) throws -> OpaquePointer {
        var config = SherpaOnnxOfflineRecognizerConfig()
        config.model_config.num_threads = 4
        config.decoding_method = "greedy_search"

        switch modelID {
        case "sensevoice-small":
            config.model_config.sense_voice.model = "\(modelPath.path)/model.int8.onnx"
            config.model_config.sense_voice.tokens = "\(modelPath.path)/tokens.txt"
            config.model_config.sense_voice.use_itn = 1
        case "zipformer-en":
            config.model_config.transducer.encoder = "\(modelPath.path)/encoder-epoch-99-avg-1.int8.onnx"
            config.model_config.transducer.decoder = "\(modelPath.path)/decoder-epoch-99-avg-1.onnx"
            config.model_config.transducer.joiner = "\(modelPath.path)/joiner-epoch-99-avg-1.int8.onnx"
            config.model_config.tokens = "\(modelPath.path)/tokens.txt"
        case "fire-red-asr2":
            config.model_config.fire_red_asr.model = "\(modelPath.path)/model.int8.onnx"
            config.model_config.fire_red_asr.tokens = "\(modelPath.path)/tokens.txt"
        default:
            // sensevoice-small as fallback
            config.model_config.sense_voice.model = "\(modelPath.path)/model.int8.onnx"
            config.model_config.sense_voice.tokens = "\(modelPath.path)/tokens.txt"
        }

        guard let rec = SherpaOnnxCreateOfflineRecognizer(&config) else {
            throw SherpaError.engineNotAvailable
        }
        return rec
    }
    #endif

    func releaseRecognizer() {
        #if canImport(SherpaOnnx)
        if let rec = recognizer {
            SherpaOnnxDestroyOfflineRecognizer(rec)
            recognizer = nil
            currentModelID = nil
        }
        #endif
    }
}
