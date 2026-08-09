import Foundation

/// Builds caller-visible provider failures without exposing provider response bodies.
///
/// Provider bodies can contain echoed prompts, transcripts, credentials, or very large
/// diagnostics. They must never be copied into `localizedDescription` (and therefore
/// into UI or logs). Only a numeric status/code and a bounded, token-safe request ID
/// are allowed through this boundary.
public enum ProviderHTTPErrorPolicy {
    public static let maximumRequestIDLength = 64

    public enum Context: String, Sendable {
        case polishRequest = "Polish API request"
        case polishStreamingRequest = "Polish streaming request"
        case claudePolishRequest = "Claude API request"
        case connectionTest = "Connection test"
        case claudeConnectionTest = "Claude connection test"
        case sttConnectionTest = "STT connection test"
        case deepgramConnectionTest = "Deepgram connection test"
        case sttRequest = "STT API request"
        case deepgramSTTRequest = "Deepgram STT request"
        case qwenASRRequest = "Qwen ASR request"
        case qwenASRSubmitRequest = "Qwen ASR submit request"
        case qwenASRStatusRequest = "Qwen ASR status request"
        case qwenASRTask = "Qwen ASR task"
        case iflytekSTTRequest = "iFlytek API request"
    }

    /// Produces an error from response metadata only. The response body is never read.
    public static func publicError(
        context: Context,
        response: HTTPURLResponse
    ) -> VowriteError {
        makeError(
            context: context,
            codeDescription: "HTTP \(response.statusCode)",
            requestID: requestID(from: response)
        )
    }

    /// Explicit non-streaming overload. The body is accepted only to make discarding it
    /// deliberate at call sites; it is never decoded, interpolated, or retained.
    public static func publicError(
        context: Context,
        response: HTTPURLResponse,
        discardingResponseBody _: Data
    ) -> VowriteError {
        publicError(context: context, response: response)
    }

    /// Produces a sanitized error for provider protocols that expose a numeric code
    /// outside HTTP status (for example, a WebSocket message).
    public static func publicError(
        context: Context,
        providerCode: Int,
        requestID: String? = nil
    ) -> VowriteError {
        makeError(
            context: context,
            codeDescription: "provider code \(providerCode)",
            requestID: sanitizedRequestID(requestID)
        )
    }

    /// Produces a sanitized semantic provider failure when no numeric code is available.
    public static func publicError(
        context: Context,
        requestID: String? = nil
    ) -> VowriteError {
        makeError(
            context: context,
            codeDescription: nil,
            requestID: sanitizedRequestID(requestID)
        )
    }

    /// Produces a semantic provider failure while still preserving a safe request ID
    /// from HTTP response metadata. The successful HTTP status is intentionally omitted.
    public static func publicError(
        context: Context,
        responseMetadata response: HTTPURLResponse
    ) -> VowriteError {
        makeError(
            context: context,
            codeDescription: nil,
            requestID: requestID(from: response)
        )
    }

    private static let requestIDHeaderNames = [
        "Request-ID",
        "X-Request-ID",
        "OpenAI-Request-ID",
        "Anthropic-Request-ID",
        "X-DashScope-Request-ID",
        "X-DG-Request-ID",
        "DG-Request-ID",
        "CF-Ray",
    ]

    private static let allowedRequestIDCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.:"
    )

    private static func requestID(from response: HTTPURLResponse) -> String? {
        for headerName in requestIDHeaderNames {
            if let requestID = sanitizedRequestID(response.value(forHTTPHeaderField: headerName)) {
                return requestID
            }
        }
        return nil
    }

    private static func sanitizedRequestID(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.unicodeScalars.allSatisfy({ allowedRequestIDCharacters.contains($0) }) else {
            return nil
        }
        return String(trimmed.prefix(maximumRequestIDLength))
    }

    private static func makeError(
        context: Context,
        codeDescription: String?,
        requestID: String?
    ) -> VowriteError {
        let details = [codeDescription, requestID.map { "request ID: \($0)" }].compactMap { $0 }
        let suffix = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
        return .apiError("\(context.rawValue) failed\(suffix).")
    }
}
