import Foundation

extension URL {
    /// Builds a URL from `string`, throwing a descriptive `VowriteError.apiError`
    /// instead of force-unwrapping.
    ///
    /// `URL(string:)` returns nil for malformed input — an empty string, whitespace
    /// in the authority (e.g. a pasted `https://api x.com`), or leading control
    /// characters — so the previous `URL(string:)!` crashed when a user configured
    /// a malformed custom base URL. `label` names the call site so the surfaced
    /// error points at the right setting.
    static func validated(_ string: String, label: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw VowriteError.apiError("Invalid \(label) URL: \(string)")
        }
        return url
    }
}
