import AppKit
import SwiftUI

enum WindowHelper {
    private static var mainWindow: NSWindow?

    static func openSettings() { openMainWindow() }
    static func openHistory() { openMainWindow() }

    static func openMainWindow() {
        // F-025: Open the SwiftUI Settings scene window
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Holds a reference to AppState so WindowHelper can access it
enum AppStateHolder {
    static var shared: AppState?
}
