import Foundation

extension String {
    /// Percent-encodes the string for use as an `application/x-www-form-urlencoded`
    /// component (key or value).
    ///
    /// Beyond the default URL-query escaping this also encodes `+`, `&`, and `=` —
    /// characters that are structurally significant in a form body — and space
    /// (→ `%20`). Without it, an OAuth authorization `code` that contains a `+`
    /// is corrupted on the wire (the server decodes `+` as a space), causing
    /// intermittent token-exchange failures.
    func formURLEncoded() -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
