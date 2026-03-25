import SwiftUI
import SwiftData
import VowriteKit

@main
struct VowriteApp: App {
    @StateObject private var appState: AppState

    @AppStorage("hasCompletedOnboarding", store: UserDefaults(suiteName: VowriteStorage.appGroupID))
    private var hasCompletedOnboarding = false

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Tab = .dashboard
    @State private var pendingDeepLink: String?

    enum Tab {
        case dashboard, settings, personalization, history
    }

    init() {
        // 1. Configure shared storage (must be first)
        VowriteStorage.configure(suiteName: VowriteStorage.appGroupID)

        // 2. Migrate old data (UserDefaults.standard -> App Group)
        StorageMigration.runIfNeeded()

        // 3. Migrate old Keychain (no access group -> with access group)
        #if os(iOS)
        KeychainHelper.migrateToAccessGroup()
        #endif

        // 4. Run v0.1.x legacy migration (if needed)
        APIConfigMigration.runIfNeeded()
        APIConfig.migratePresetIDs()

        // Initialize AppState after all migrations
        _appState = StateObject(wrappedValue: AppState())
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                contentView
                    .environmentObject(appState)
                    .modelContainer(appState.modelContainer)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .onAppear {
                        appState.importPendingRecords()
                        // Auto-activate background recording service with saved duration
                        autoActivateIfNeeded()
                    }
                    .onChange(of: pendingDeepLink) { _, link in
                        if let link, link == "activate" {
                            // Deep link from keyboard extension: activate bg service (Always duration)
                            if !appState.backgroundService.isActive {
                                appState.backgroundService.activate(duration: .always)
                                VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                                VowriteStorage.defaults.set(BGServiceDuration.always.rawValue, forKey: "bgServiceDuration")
                            }
                            pendingDeepLink = nil
                        }
                    }
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .active {
                            // App returned to foreground: import pending records & re-activate service if needed
                            appState.importPendingRecords()
                            if !appState.backgroundService.isActive {
                                autoActivateIfNeeded()
                            }
                        }
                    }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .environmentObject(appState)
            }
        }
    }

    private var contentView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.open.with.lines.needle.33percent")
                }
                .tag(Tab.dashboard)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)

            PersonalizationView()
                .tabItem {
                    Label("Style", systemImage: "paintbrush.fill")
                }
                .tag(Tab.personalization)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)
        }
    }

    /// Auto-activate background service if enabled, respecting saved duration and checking for expiry.
    private func autoActivateIfNeeded() {
        guard VowriteStorage.defaults.bool(forKey: "bgServiceEnabled") else { return }

        let durationRaw = VowriteStorage.defaults.integer(forKey: "bgServiceDuration")
        let duration = BGServiceDuration(rawValue: durationRaw) ?? .always

        // For finite durations, check if the timer has already expired
        if let seconds = duration.seconds {
            let activatedAt = VowriteStorage.defaults.double(forKey: "bgServiceActivatedAt")
            if activatedAt > 0 {
                let elapsed = Date().timeIntervalSince1970 - activatedAt
                if elapsed >= seconds {
                    // Timer expired while app was not running — don't reactivate
                    VowriteStorage.defaults.set(false, forKey: "bgServiceEnabled")
                    VowriteStorage.defaults.removeObject(forKey: "bgServiceActivatedAt")
                    return
                }
            }
        }

        appState.backgroundService.activate(duration: duration)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "vowrite" else { return }
        #if DEBUG
        print("[Vowrite App] Deep link received: \(url.absoluteString)")
        #endif
        switch url.host {
        case "settings":
            selectedTab = .settings
        case "setup":
            hasCompletedOnboarding = false
        case "activate":
            // Keyboard extension requested bg service activation (use Always duration)
            if !appState.backgroundService.isActive {
                appState.backgroundService.activate(duration: .always)
                VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                VowriteStorage.defaults.set(BGServiceDuration.always.rawValue, forKey: "bgServiceDuration")
            }
            pendingDeepLink = "activate"
        default:
            break
        }
    }
}
