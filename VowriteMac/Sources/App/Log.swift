import os

/// Unified logging surface for VowriteMac. Mirrors the pattern already used by
/// `DictationEngine` in VowriteKit (`Logger(subsystem: "com.vowrite.kit", ...)`),
/// scoped to the app's own subsystem so Mac-only failures are easy to isolate
/// in Console.app / sysdiagnose.
enum Log {
    static let injector = Logger(subsystem: "com.vowrite.app", category: "injector")
    static let hotkey = Logger(subsystem: "com.vowrite.app", category: "hotkey")
    static let window = Logger(subsystem: "com.vowrite.app", category: "window")
    static let history = Logger(subsystem: "com.vowrite.app", category: "history")
    static let settings = Logger(subsystem: "com.vowrite.app", category: "settings")
    static let models = Logger(subsystem: "com.vowrite.app", category: "models")
}
