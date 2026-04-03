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
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = ["-xjf", archive.path, "-C", destination.path, "--strip-components=1"]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw SherpaError.modelDownloadFailed("Failed to extract model archive")
        }
        #else
        // iOS: Process is unavailable. Decompress bz2 data and extract tar manually.
        let archiveData = try Data(contentsOf: archive)
        let decompressed = try decompressBz2(archiveData)
        try extractTar(decompressed, to: destination, stripComponents: 1)
        #endif
    }

    #if !os(macOS)
    private func decompressBz2(_ data: Data) throws -> Data {
        // Use Compression framework with LZMA as fallback — bz2 is not natively
        // supported by Apple's Compression framework. We use a minimal bz2 stream
        // decoder via the bundled CBzip2 shim, or fall back to copying the raw file
        // if it's already an uncompressed tar.

        // Try: if the file is actually a plain tar (some mirrors serve uncompressed)
        if data.prefix(6) == Data("ustar\0".utf8) || data.prefix(5) == Data("ustar".utf8) {
            return data
        }

        // bz2 magic: "BZ" header
        guard data.count > 4,
              data[0] == 0x42, // 'B'
              data[1] == 0x5A  // 'Z'
        else {
            throw SherpaError.modelDownloadFailed("Archive is not a valid bz2 file")
        }

        // Use Compression framework's zlib decompressor won't work for bz2.
        // On iOS, shell out is not available. For now, throw a clear error
        // directing users to download pre-extracted models or use macOS.
        throw SherpaError.modelDownloadFailed(
            "On-device bz2 extraction is not supported on iOS. "
            + "Please download models via the macOS app and sync, "
            + "or use a pre-extracted model bundle."
        )
    }

    private func extractTar(_ tarData: Data, to destination: URL, stripComponents: Int) throws {
        // Minimal tar extractor for POSIX/UStar format
        let blockSize = 512
        var offset = 0

        while offset + blockSize <= tarData.count {
            let headerBlock = tarData[offset..<(offset + blockSize)]

            // Check for end-of-archive (two zero blocks)
            if headerBlock.allSatisfy({ $0 == 0 }) { break }

            // Extract filename (bytes 0-99)
            let nameData = headerBlock[headerBlock.startIndex..<(headerBlock.startIndex + 100)]
            let rawName = String(data: Data(nameData), encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters.union(.init(charactersIn: "\0"))) ?? ""

            // Extract file size from octal (bytes 124-135)
            let sizeData = headerBlock[(headerBlock.startIndex + 124)..<(headerBlock.startIndex + 136)]
            let sizeStr = String(data: Data(sizeData), encoding: .utf8)?
                .trimmingCharacters(in: .controlCharacters.union(.init(charactersIn: "\0 "))) ?? "0"
            let fileSize = Int(sizeStr, radix: 8) ?? 0

            // Extract type flag (byte 156)
            let typeFlag = headerBlock[headerBlock.startIndex + 156]

            offset += blockSize

            // Strip path components
            let components = rawName.split(separator: "/", omittingEmptySubsequences: false)
            let stripped = components.dropFirst(stripComponents).joined(separator: "/")

            guard !stripped.isEmpty else {
                // Skip the stripped-away entries, but still advance past file data
                let dataBlocks = (fileSize + blockSize - 1) / blockSize
                offset += dataBlocks * blockSize
                continue
            }

            let targetURL = destination.appendingPathComponent(stripped)

            if typeFlag == 0x35 || rawName.hasSuffix("/") {
                // Directory
                try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } else if typeFlag == 0x30 || typeFlag == 0x00 {
                // Regular file
                try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let fileData = tarData[offset..<(offset + fileSize)]
                try Data(fileData).write(to: targetURL)
            }

            let dataBlocks = (fileSize + blockSize - 1) / blockSize
            offset += dataBlocks * blockSize
        }
    }
    #endif
}
