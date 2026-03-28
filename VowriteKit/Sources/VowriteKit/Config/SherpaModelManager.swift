import Foundation

/// Manages sherpa-onnx model downloads and lifecycle.
/// Models are stored in ~/Library/Application Support/Vowrite/models/
@MainActor
public final class SherpaModelManager: ObservableObject {
    public static let shared = SherpaModelManager()

    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var downloadedModels: Set<String> = []

    // MARK: - Model Definitions

    public struct ModelInfo: Identifiable {
        public let id: String
        public let name: String
        public let size: String
        public let languages: String
        public let downloadURL: String
        public let files: [String]  // Expected files after extraction

        // Check isDownloaded via SherpaModelManager.shared.downloadedModels on MainActor
    }

    public static let availableModels: [ModelInfo] = [
        ModelInfo(
            id: "sensevoice-small",
            name: "SenseVoice Small (极速)",
            size: "~20MB",
            languages: "中 英 日 韩 粤",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17-int8.tar.bz2",
            files: ["model.int8.onnx", "tokens.txt"]
        ),
        ModelInfo(
            id: "zipformer-en",
            name: "Zipformer English (高精度)",
            size: "~236MB",
            languages: "English",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-zipformer-en-2023-06-26.tar.bz2",
            files: ["encoder-epoch-99-avg-1.int8.onnx", "decoder-epoch-99-avg-1.onnx", "joiner-epoch-99-avg-1.int8.onnx", "tokens.txt"]
        ),
        ModelInfo(
            id: "fire-red-asr2",
            name: "Fire Red ASR2 (中英+方言)",
            size: "~1GB",
            languages: "中 英 + 20方言",
            downloadURL: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-fire-red-asr2-zh_en-int8-2026-02-25.tar.bz2",
            files: ["model.int8.onnx", "tokens.txt"]
        ),
    ]

    // MARK: - Paths

    private var modelsDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Vowrite/models", isDirectory: true)
    }

    public func modelPath(for modelID: String) -> URL {
        modelsDirectory.appendingPathComponent(modelID, isDirectory: true)
    }

    // MARK: - Lifecycle

    private init() {
        scanDownloadedModels()
    }

    private func scanDownloadedModels() {
        for model in Self.availableModels {
            let dir = modelPath(for: model.id)
            if FileManager.default.fileExists(atPath: dir.path) {
                downloadedModels.insert(model.id)
            }
        }
    }

    // MARK: - Ensure Model

    /// Ensure a model is downloaded. Returns the model directory path.
    public func ensureModel(_ modelID: String) async throws -> URL {
        let dir = modelPath(for: modelID)
        if downloadedModels.contains(modelID) {
            return dir
        }

        guard let model = Self.availableModels.first(where: { $0.id == modelID }) else {
            throw SherpaError.modelNotFound(modelID)
        }

        return try await downloadModel(model)
    }

    // MARK: - Download

    /// Download and extract a model. Reports progress via downloadProgress[modelID].
    public func downloadModel(_ model: ModelInfo) async throws -> URL {
        let destDir = modelPath(for: model.id)

        guard let url = URL(string: model.downloadURL) else {
            throw SherpaError.modelDownloadFailed("Invalid download URL")
        }

        // Create models directory
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        // Download with progress
        downloadProgress[model.id] = 0

        let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: nil)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SherpaError.modelDownloadFailed("HTTP error")
        }

        downloadProgress[model.id] = 0.9

        // Extract tar.bz2
        try await extractTarBz2(tempURL, to: destDir)

        downloadProgress[model.id] = 1.0
        downloadedModels.insert(model.id)

        // Clean up progress after a delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            downloadProgress.removeValue(forKey: model.id)
        }

        return destDir
    }

    // MARK: - Delete

    public func deleteModel(_ modelID: String) throws {
        let dir = modelPath(for: modelID)
        try FileManager.default.removeItem(at: dir)
        downloadedModels.remove(modelID)
    }

    // MARK: - Extraction

    private func extractTarBz2(_ archive: URL, to destination: URL) async throws {
        // Use tar command to extract (available on macOS and iOS simulator)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archive.path, "-C", destination.path, "--strip-components=1"]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SherpaError.modelDownloadFailed("Failed to extract model archive")
        }
    }
}
