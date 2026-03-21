import SwiftUI
import SwiftData
import VowriteKit

@main
struct VowriteApp: App {
    @StateObject private var appState: AppState

    @AppStorage("hasCompletedOnboarding", store: UserDefaults(suiteName: VowriteStorage.appGroupID))
    private var hasCompletedOnboarding = false

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

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "vowrite" else { return }
        switch url.host {
        case "settings":
            selectedTab = .settings
        case "setup":
            hasCompletedOnboarding = false
        default:
            break
        }
    }
}
