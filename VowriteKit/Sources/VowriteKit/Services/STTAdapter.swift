import Foundation

/// Protocol for speech-to-text adapters. Each adapter handles a specific API format.
public protocol STTAdapter {
    func transcribe(
        audioURL: URL,
        model: String,
        language: String?,
        prompt: String?,
        apiKey: String?,
        baseURL: String,
        provider: APIProvider
    ) async throws -> String
}
