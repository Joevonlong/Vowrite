import VowriteKit
import SwiftUI

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case history = "History"
    case personalization = "Personalization"
    case vocabulary = "Vocabulary"
    case general = "General"
    case models = "Models"
    case apiKeys = "API Keys"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "house"
        case .general: return "slider.horizontal.3"
        case .history: return "clock.arrow.circlepath"
        case .apiKeys: return "key"
        case .models: return "cpu"
        case .personalization: return "sparkles"
        case .vocabulary: return "text.book.closed"
        case .about: return "info.circle"
        }
    }
}

/// Presentation-only selection shared with menu commands and window shortcuts.
/// It never changes a recording, mode, or persisted application preference.
final class MainWindowNavigation: ObservableObject {
    static let shared = MainWindowNavigation()
    @Published var selectedItem: SidebarItem = .overview
    @Published var historyRecordID: UUID?
}

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var navigation = MainWindowNavigation.shared
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    private var currentAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 260)
        } detail: {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text("Vowrite")
                    Image(systemName: "chevron.right").font(.caption2)
                    Text(navigation.selectedItem.rawValue)
                        .foregroundStyle(VW.Colors.Text.primary)
                    Spacer()
                }
                .font(.callout)
                .foregroundStyle(VW.Colors.Text.secondary)
                .padding(.horizontal, 32)
                .frame(height: 48)
                .background(VW.Colors.Surface.panel)
                Divider().overlay(VW.Colors.Border.standard)
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(VW.Colors.Surface.canvas)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 860, minHeight: 560)
        .tint(VW.Colors.Action.primary)
        .foregroundStyle(VW.Colors.Text.primary)
        .preferredColorScheme(currentAppearance.colorScheme)
        .transaction { transaction in
            if reduceMotion {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(VW.Colors.Action.primary)
                Text("Vowrite")
                    .font(.system(size: 23, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sidebarCaption("Workspace")
                    ForEach([SidebarItem.overview, .history, .personalization, .vocabulary]) { item in
                        navigationButton(item)
                    }
                    sidebarCaption("Configuration").padding(.top, 20)
                    ForEach([SidebarItem.general, .models, .apiKeys, .about]) { item in
                        navigationButton(item)
                    }
                }
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: 12) {
                Divider().overlay(VW.Colors.Border.standard)
                Label("Stored on this Mac", systemImage: "lock.shield")
                    .font(.caption)
                Text("Version \(AppVersion.current)")
                    .font(.caption)
            }
            .foregroundStyle(VW.Colors.Text.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(16)
        .background(VW.Colors.Surface.panel)
    }

    private func sidebarCaption(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(1)
            .foregroundStyle(VW.Colors.Text.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }

    private func navigationButton(_ item: SidebarItem) -> some View {
        SidebarButton(title: item.rawValue, icon: item.icon, isSelected: navigation.selectedItem == item) {
            navigation.selectedItem = item
        }
        .accessibilityIdentifier("navigation.\(item.id)")
    }

    @ViewBuilder
    private var detailView: some View {
        switch navigation.selectedItem {
        case .overview: OverviewPageView()
        case .general: GeneralPageView()
        case .history: HistoryPageView()
        case .apiKeys: APIKeysPageView()
        case .models: ModelsPageView()
        case .personalization: PersonalizationPageView()
        case .vocabulary: VocabularyPageView()
        case .about: AboutPageView()
        }
    }
}

struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.body).frame(width: 20)
                Text(title).font(.system(size: 14, weight: .medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(isSelected ? VW.Colors.Action.soft : isHovered ? VW.Colors.Surface.secondary : .clear)
            .foregroundStyle(isSelected ? VW.Colors.Action.primary : VW.Colors.Text.secondary)
            .clipShape(RoundedRectangle(cornerRadius: VW.Radius.control))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct HistoryPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HistoryView()
            .modelContainer(appState.modelContainer)
    }
}
