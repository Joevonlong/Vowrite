import Foundation

public enum VowriteError: LocalizedError {
    case networkError(String)
    case apiError(String)
    case recordingError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg): return msg
        case .apiError(let msg): return msg
        case .recordingError(let msg): return msg
        }
    }
}
