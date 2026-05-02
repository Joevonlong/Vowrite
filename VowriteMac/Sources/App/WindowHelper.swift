import AppKit
import SwiftUI

enum WindowHelper {
    private static var mainWindow: NSWindow?

    /// When true, `updateActivationPolicy` should not switch back to .accessory.
    static var isOpeningWindow = false

    static func openMainWindow() {
        // If window already exists and is visible, just bring it to front
        if let window = mainWindow, window.isVisible {
            NSApp.setActivationPolicy(.regular)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        isOpeningWindow = true
        NSApp.setActivationPolicy(.regular)

        // Create the window ourselves — bypasses unreliable showSettingsWindow: selector
        guard let appState = AppStateHolder.shared else {
            isOpeningWindow = false
            return
        }

        let contentView = MainWindowView()
            .environmentObject(appState)
            .modelContainer(appState.modelContainer)

        let hosting = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vowrite"
        window.setContentSize(NSSize(width: 860, height: 580))
        window.minSize = NSSize(width: 780, height: 520)
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        mainWindow = window

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isOpeningWindow = false
        }
    }
}

/// Holds a reference to AppState so WindowHelper can access it
enum AppStateHolder {
    static var shared: AppState?
}
