import VowriteKit
import SwiftUI

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case general = "General"
    case history = "History"
    case apiKeys = "API Keys"
    case models = "Models"
    case personalization = "Personalization"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "house"
        case .general: return "gearshape"
        case .history: return "clock.arrow.circlepath"
        case .apiKeys: return "key"
        case .models: return "cpu"
        case .personalization: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Main Window

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: SidebarItem = .overview
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    private var currentAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 780, minHeight: 520)
        .preferredColorScheme(currentAppearance.colorScheme)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Vowrite")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Nav items
            ForEach(SidebarItem.allCases) { item in
                SidebarButton(
                    title: item.rawValue,
                    icon: item.icon,
                    isSelected: selectedItem == item
                ) {
                    selectedItem = item
                }
            }

            Spacer()

            // Version
            Text("Version \(AppVersion.current)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(width: 180)
    }

    // MARK: Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .overview:
            OverviewPageView()
                .environmentObject(appState)
        case .general:
            GeneralPageView()
                .environmentObject(appState)
        case .history:
            HistoryPageView()
                .environmentObject(appState)
        case .apiKeys:
            APIKeysPageView()
        case .models:
            ModelsPageView()
                .environmentObject(appState)
        case .personalization:
            PersonalizationPageView()
        case .about:
            AboutPageView()
        }
    }
}

// MARK: - Sidebar Button

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .frame(width: 20)
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - History Page

struct HistoryPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HistoryView()
            .environmentObject(appState)
            .modelContainer(appState.modelContainer)
    }
}
