import SwiftUI
import SwiftData
import VowriteKit

@main
struct VowriteApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(appState)
                    .modelContainer(appState.modelContainer)
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .environmentObject(appState)
            }
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab {
        case home, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(Tab.home)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
    }
}
