import SwiftUI
import SwiftData
import Sparkle
import VowriteKit

@main
struct VowriteApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VowriteMenuView()
                .environmentObject(appState)
                .onAppear {
                    AppStateHolder.shared = appState
                    // F-017: Show onboarding on first launch
                    if !OnboardingManager.isComplete {
                        showOnboarding()
                    }
                }
        } label: {
            Image(systemName: appState.menuBarIcon)
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)

        // F-025: Commands for the menu bar when the window is active
        .commands {
            // Vowrite menu: About
            CommandGroup(replacing: .appInfo) {
                Button("About Vowrite") {
                    WindowHelper.openMainWindow()
                }
            }
            // Vowrite menu: Check for Updates
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    appDelegate.checkForUpdates()
                }
            }
            // ⌘, opens our custom settings window
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    WindowHelper.openMainWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private func showOnboarding() {
        NSApp.activate(ignoringOtherApps: true)
        let onboardingView = OnboardingView {
            // Close onboarding window
            NSApp.keyWindow?.close()
        }
        .environmentObject(appState)

        let hosting = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Welcome to Vowrite"
        window.setContentSize(NSSize(width: 600, height: 500))
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let updateManager = MacUpdateManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        SoundFeedback.warmUp()
        // Clean up any legacy user-modified system prompt from UserDefaults
        PromptConfig.migrateLegacySystemPrompt()

        // F-025: Monitor window lifecycle for activation policy switching
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateActivationPolicy()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay so the window has finished closing before we re-check
            DispatchQueue.main.async {
                self?.updateActivationPolicy()
            }
        }
    }

    // F-026: Public method to trigger update check
    func checkForUpdates() {
        updateManager.checkForUpdates()
    }

    // F-025: Switch activation policy based on visible windows
    private func updateActivationPolicy() {
        // Don't switch back to .accessory while WindowHelper is in the middle
        // of opening a window — the Settings window may not be visible yet.
        if WindowHelper.isOpeningWindow { return }

        let hasVisibleWindows = NSApp.windows.contains {
            $0.isVisible && $0.styleMask.contains(.titled)
        }

        if hasVisibleWindows {
            if NSApp.activationPolicy() != .regular {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            if NSApp.activationPolicy() != .accessory {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
