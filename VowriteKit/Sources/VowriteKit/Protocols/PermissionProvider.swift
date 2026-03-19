import Foundation

/// Platform-specific permission handling — macOS needs Accessibility, iOS doesn't
public protocol PermissionProvider {
    func hasMicrophoneAccess() -> Bool
    func requestMicrophoneAccess() async -> Bool
    func hasRequiredPermissions() -> Bool
}
