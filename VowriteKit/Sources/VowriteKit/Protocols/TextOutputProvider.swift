import Foundation

/// Platform-specific text output — macOS injects at cursor, iOS copies to clipboard
public protocol TextOutputProvider {
    func output(text: String) async
    func prepareForOutput()
}
