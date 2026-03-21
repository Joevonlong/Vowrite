import Foundation

/// Centralized storage abstraction.
/// - macOS: uses UserDefaults.standard (no need to call configure)
/// - iOS: App and Extension call configure(suiteName:) at launch
public enum VowriteStorage {
    public static let appGroupID = "group.com.vowrite.shared"

    /// Global UserDefaults instance. All VowriteKit storage must use this.
    public private(set) static var defaults: UserDefaults = .standard

    /// Call on iOS before any Config/Manager initialization.
    ///
    /// Call sites:
    /// - Container App: App.init
    /// - Keyboard Extension: KeyboardViewController.viewDidLoad()
    ///
    /// macOS does not need to call this.
    public static func configure(suiteName: String? = nil) {
        if let suite = suiteName,
           let suiteDefaults = UserDefaults(suiteName: suite) {
            defaults = suiteDefaults
        }
    }

    /// SwiftData store URL. iOS uses App Group shared container, macOS uses default.
    public static var swiftDataURL: URL? {
        #if os(iOS)
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("VowriteData.store")
        #else
        return nil  // macOS uses ModelConfiguration default location
        #endif
    }
}
