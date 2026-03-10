import SwiftUI
import SwiftData

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
