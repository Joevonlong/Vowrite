import Foundation

/// Platform-specific update mechanism — macOS uses Sparkle, iOS uses App Store
public protocol UpdateProvider {
    func checkForUpdates()
}
