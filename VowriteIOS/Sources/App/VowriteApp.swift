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
    @State private var showActivationOverlay = false

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

        // Pre-generate sound feedback tones
        SoundFeedback.warmUp()

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
                            // Deep link from keyboard extension: activate bg service with saved duration
                            if !appState.backgroundService.isActive {
                                let duration = savedBGServiceDuration
                                appState.backgroundService.activate(duration: duration)
                                VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                                VowriteStorage.defaults.set(duration.rawValue, forKey: "bgServiceDuration")
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
                    .overlay {
                        if showActivationOverlay {
                            ActivationOverlay()
                                .transition(.opacity)
                                .zIndex(100)
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

    /// Reads user's saved duration preference, defaulting to 5 minutes for session-based approach.
    private var savedBGServiceDuration: BGServiceDuration {
        let raw = VowriteStorage.defaults.integer(forKey: "bgServiceDuration")
        return BGServiceDuration(rawValue: raw) ?? .fiveMinutes
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
            // Keyboard extension requested bg service activation
            selectedTab = .dashboard
            if !appState.backgroundService.isActive {
                let duration = savedBGServiceDuration
                appState.backgroundService.activate(duration: duration)
                VowriteStorage.defaults.set(true, forKey: "bgServiceEnabled")
                VowriteStorage.defaults.set(duration.rawValue, forKey: "bgServiceDuration")
            }
            pendingDeepLink = "activate"
            // Show activation overlay — iOS shows "← Back to X" at top-left
            // for the user to return to the previous app
            withAnimation(.easeInOut(duration: 0.3)) {
                showActivationOverlay = true
            }
            // Auto-dismiss overlay after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showActivationOverlay = false
                }
            }
        default:
            break
        }
    }
}

// MARK: - Activation Overlay

/// Full-screen overlay shown briefly after the keyboard extension activates the background service.
/// Instructs the user to tap iOS's "Back to" button to return to the previous app.
private struct ActivationOverlay: View {
    @State private var checkmarkScale: CGFloat = 0.3
    @State private var checkmarkOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }

                Text("Service Activated")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                // Return instruction
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("Tap the back button at the top left")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text("to return to your keyboard")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                checkmarkScale = 1.0
                checkmarkOpacity = 1.0
            }
        }
    }
}
