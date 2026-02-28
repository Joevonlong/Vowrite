import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case settings = "Settings"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Main Window

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: SidebarItem = .home

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 780, minHeight: 520)
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
        case .home:
            HomePageView()
                .environmentObject(appState)
        case .history:
            HistoryPageView()
                .environmentObject(appState)
        case .settings:
            SettingsPageView()
                .environmentObject(appState)
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
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

// MARK: - Home Page

struct HomePageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speak naturally, write perfectly")
                        .font(.system(size: 24, weight: .bold))
                    HStack(spacing: 4) {
                        Text("Press")
                        Text(HotkeyDisplay.string(
                            keyCode: appState.hotkeyManager.keyCode,
                            modifiers: appState.hotkeyManager.modifiers
                        ))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(5)
                        .font(.system(.body, design: .monospaced))
                        Text("to start and stop dictation.")
                    }
                    .foregroundColor(.secondary)
                }

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(icon: "clock", value: formatMinutes(appState.totalDictationTime), label: "Total dictation time")
                    StatCard(icon: "mic", value: "\(appState.totalWords)", label: "Words dictated")
                    StatCard(icon: "text.badge.checkmark", value: "\(appState.totalDictations)", label: "Dictations")
                }

                // Quick actions
                HStack(spacing: 16) {
                    QuickActionCard(
                        title: "API Status",
                        description: appState.hasAPIKey ? "Connected and ready" : "Set up your API key to get started",
                        icon: appState.hasAPIKey ? "checkmark.circle.fill" : "key.fill",
                        iconColor: appState.hasAPIKey ? .green : .orange
                    )
                    QuickActionCard(
                        title: "Permissions",
                        description: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? "All permissions granted"
                            : "Some permissions needed",
                        icon: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? "lock.open.fill" : "lock.fill",
                        iconColor: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? .green : .orange
                    )
                }

                // Last result
                if let result = appState.lastResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last dictation")
                                .font(.headline)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(result, forType: .string)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Text(result)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(32)
        }
    }

    private func formatMinutes(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 1 { return "\(Int(seconds))s" }
        return "\(mins) min"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
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

// MARK: - Settings Page

struct SettingsPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))

                // Keyboard shortcuts section
                SettingsSection(icon: "keyboard", title: "Keyboard shortcuts") {
                    SettingsRow(
                        title: "Dictate",
                        description: "Press to start and stop dictation."
                    ) {
                        HotkeyRecorderButton(
                            currentKeyCode: appState.hotkeyManager.keyCode,
                            currentModifiers: appState.hotkeyManager.modifiers
                        ) { code, mods in
                            appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                        }
                    }
                }

                // API Configuration
                SettingsSection(icon: "key", title: "API Configuration") {
                    APISettingsContent()
                        .environmentObject(appState)
                }

                // Permissions
                SettingsSection(icon: "lock.shield", title: "Permissions") {
                    PermissionsContent()
                }

                // Appearance
                SettingsSection(icon: "paintbrush", title: "Appearance") {
                    AppearanceContent()
                }

                // Startup
                SettingsSection(icon: "power", title: "General") {
                    GeneralContent()
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
            }
            Divider()
            content
        }
    }
}

// MARK: - Settings Row

struct SettingsRow<Trailing: View>: View {
    let title: String
    let description: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
    }
}

// MARK: - API Settings Content

struct APISettingsContent: View {
    @EnvironmentObject var appState: AppState
    @State private var isEditing = false
    @State private var editProvider: APIProvider = .openai
    @State private var editKey: String = ""
    @State private var editBaseURL: String = ""
    @State private var editSTTModel: String = ""
    @State private var editPolishModel: String = ""
    @State private var saved = false

    var body: some View {
        if isEditing {
            editView
        } else {
            displayView
        }
    }

    private var displayView: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Provider", description: "AI service provider") {
                Text(APIConfig.provider.rawValue)
                    .foregroundColor(.secondary)
            }
            SettingsRow(title: "API Key", description: "Authentication key") {
                if let key = KeychainHelper.getAPIKey(), !key.isEmpty {
                    Text(maskKey(key))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text("Not configured")
                        .foregroundColor(.orange)
                }
            }
            SettingsRow(title: "STT Model", description: "Speech-to-text model") {
                Text(APIConfig.sttModel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            SettingsRow(title: "Polish Model", description: "Text cleanup model") {
                Text(APIConfig.polishModel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Spacer()
                Button("Edit Configuration") {
                    loadCurrent()
                    isEditing = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var editView: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Provider", description: "Choose your AI provider") {
                Picker("", selection: $editProvider) {
                    ForEach(APIProvider.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .frame(width: 160)
                .onChange(of: editProvider) { _, v in
                    editBaseURL = v.defaultBaseURL
                    editSTTModel = v.defaultSTTModel
                    editPolishModel = v.defaultPolishModel
                }
            }

            SettingsRow(title: "API Key", description: editProvider.keyPlaceholder) {
                SecureField("", text: $editKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }

            if !editProvider.keyURL.isEmpty {
                HStack {
                    Spacer()
                    Link("Get API Key →", destination: URL(string: editProvider.keyURL)!)
                        .font(.caption)
                }
            }

            SettingsRow(title: "STT Model", description: "Speech recognition") {
                TextField("", text: $editSTTModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }

            SettingsRow(title: "Polish Model", description: "Text cleanup") {
                TextField("", text: $editPolishModel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }

            if editProvider == .custom {
                SettingsRow(title: "Base URL", description: "API endpoint") {
                    TextField("", text: $editBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }
            }

            HStack {
                Button("Cancel") { isEditing = false }
                    .buttonStyle(.bordered)
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
    }

    private func loadCurrent() {
        editProvider = APIConfig.provider
        editKey = KeychainHelper.getAPIKey() ?? ""
        editBaseURL = APIConfig.baseURL
        editSTTModel = APIConfig.sttModel
        editPolishModel = APIConfig.polishModel
    }

    private func save() {
        APIConfig.provider = editProvider
        APIConfig.baseURL = editBaseURL
        APIConfig.sttModel = editSTTModel
        APIConfig.polishModel = editPolishModel
        if !editKey.isEmpty { _ = KeychainHelper.saveAPIKey(editKey) }
        appState.objectWillChange.send()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            saved = false
            isEditing = false
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "••••••••" }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }
}

// MARK: - Permissions Content

struct PermissionsContent: View {
    @State private var hasMic = PermissionManager.hasMicrophoneAccess()
    @State private var hasAcc = PermissionManager.hasAccessibilityAccess()
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Microphone", description: "Required for voice recording") {
                if hasMic {
                    Label("Granted", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                } else {
                    Button("Grant") {
                        PermissionManager.requestMicrophoneAccess { g in Task { @MainActor in hasMic = g } }
                    }.buttonStyle(.bordered)
                }
            }
            SettingsRow(title: "Accessibility", description: "Required to paste text into apps") {
                if hasAcc {
                    Label("Granted", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
                } else {
                    Button("Open Settings") {
                        DispatchQueue.global().async { PermissionManager.requestAccessibilityAccess() }
                    }.buttonStyle(.bordered)
                }
            }
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in
                    hasMic = PermissionManager.hasMicrophoneAccess()
                    hasAcc = PermissionManager.hasAccessibilityAccess()
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - Appearance Content

struct AppearanceContent: View {
    @AppStorage("appColorScheme") private var colorScheme: String = "system"

    var body: some View {
        SettingsRow(title: "Theme", description: "Choose light, dark, or follow system") {
            Picker("", selection: $colorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
    }
}

// MARK: - General Content

struct GeneralContent: View {
    @State private var launchAtLogin = false

    var body: some View {
        SettingsRow(title: "Launch at login", description: "Start Vowrite when you log in") {
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, v in
                    do {
                        if v { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch {}
                }
        }
    }
}

// MARK: - About Page

struct AboutPageView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("Vowrite")
                .font(.system(size: 32, weight: .bold))
            Text("AI Voice Keyboard")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("v\(AppVersion.current)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider().frame(width: 200)

            Text("Speak naturally, get polished text.\nPowered by Whisper + GPT.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
