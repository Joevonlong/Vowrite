import Foundation
import AVFoundation

/// F-020: Transcribe audio/video files by splitting into chunks and sending to Whisper API.
final class FileTranscriptionService {

    static let supportedExtensions = ["mp3", "m4a", "wav", "mp4", "mov", "ogg", "opus", "flac", "webm", "aac"]

    /// Maximum file size for a single Whisper API call (25 MB)
    private static let maxChunkSize: Int = 25 * 1024 * 1024

    struct TranscriptionResult {
        let rawText: String
        let polishedText: String?
        let duration: TimeInterval
    }

    private let whisperService = WhisperService()
    private let aiPolishService = AIPolishService()

    /// Check if a file extension is supported
    static func isSupported(url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Transcribe a file. If polish is true, also runs AI polish on the result.
    func transcribe(
        fileURL: URL,
        polish: Bool = false,
        language: String? = nil,
        onProgress: ((String) -> Void)? = nil
    ) async throws -> TranscriptionResult {
        guard Self.isSupported(url: fileURL) else {
            throw VowriteError.recordingError("Unsupported file format: \(fileURL.pathExtension)")
        }

        let apiKey = KeychainHelper.getAPIKey() ?? ""
        guard !apiKey.isEmpty else {
            throw VowriteError.apiError("No API key configured")
        }

        // Get file duration
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration).seconds

        onProgress?("Transcribing...")

        // Check file size — if small enough, send directly
        let fileData = try Data(contentsOf: fileURL)
        let rawText: String

        if fileData.count <= Self.maxChunkSize {
            // Single chunk
            rawText = try await whisperService.transcribe(
                audioURL: fileURL,
                apiKey: apiKey,
                language: language,
                prompt: VocabularyManager.whisperPrompt
            )
        } else {
            // Split into chunks by extracting segments
            onProgress?("Large file — splitting into chunks...")
            rawText = try await transcribeLargeFile(
                fileURL: fileURL,
                apiKey: apiKey,
                language: language,
                totalDuration: duration,
                onProgress: onProgress
            )
        }

        // Optionally polish
        var polishedText: String? = nil
        if polish {
            onProgress?("Polishing...")
            do {
                polishedText = try await aiPolishService.polish(text: rawText, apiKey: apiKey)
            } catch {
                #if DEBUG
                print("[FileTranscription] Polish failed: \(error)")
                #endif
            }
        }

        return TranscriptionResult(
            rawText: rawText,
            polishedText: polishedText,
            duration: duration
        )
    }

    /// Split a large file into ~5-minute chunks and transcribe each
    private func transcribeLargeFile(
        fileURL: URL,
        apiKey: String,
        language: String?,
        totalDuration: TimeInterval,
        onProgress: ((String) -> Void)?
    ) async throws -> String {
        let chunkDuration: TimeInterval = 300 // 5 minutes
        let chunkCount = Int(ceil(totalDuration / chunkDuration))
        var results: [String] = []

        for i in 0..<chunkCount {
            let startTime = Double(i) * chunkDuration
            let endTime = min(startTime + chunkDuration, totalDuration)
            onProgress?("Chunk \(i + 1)/\(chunkCount)...")

            let chunkURL = try await extractAudioChunk(
                from: fileURL,
                start: startTime,
                end: endTime
            )

            let text = try await whisperService.transcribe(
                audioURL: chunkURL,
                apiKey: apiKey,
                language: language,
                prompt: VocabularyManager.whisperPrompt
            )
            results.append(text)

            // Clean up chunk file
            try? FileManager.default.removeItem(at: chunkURL)
        }

        return results.joined(separator: " ")
    }

    /// Extract an audio chunk from a file using AVFoundation
    private func extractAudioChunk(
        from fileURL: URL,
        start: TimeInterval,
        end: TimeInterval
    ) async throws -> URL {
        let asset = AVURLAsset(url: fileURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vowrite_chunk_\(UUID().uuidString).m4a")

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw VowriteError.recordingError("Failed to create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        await exportSession.export()

        if exportSession.status != .completed {
            let errorMsg = exportSession.error?.localizedDescription ?? "Unknown export error"
            throw VowriteError.recordingError("Audio export failed: \(errorMsg)")
        }

        return outputURL
    }
}
