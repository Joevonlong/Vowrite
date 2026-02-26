import AppKit
import SwiftUI

enum WindowHelper {
    private static var mainWindow: NSWindow?

    static func openSettings() { openMainWindow() }
    static func openHistory() { openMainWindow() }

    static func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // If window already exists, just bring it forward
        if let win = mainWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            return
        }

        // Get appState from the running app
        guard let appState = AppStateHolder.shared else { return }

        let view = MainWindowView()
            .environmentObject(appState)
            .modelContainer(appState.modelContainer)

        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "Vowrite"
        window.setContentSize(NSSize(width: 820, height: 560))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.minSize = NSSize(width: 700, height: 450)
        window.center()
        window.makeKeyAndOrderFront(nil)

        mainWindow = window
    }
}

/// Holds a reference to AppState so WindowHelper can access it
enum AppStateHolder {
    static var shared: AppState?
}
