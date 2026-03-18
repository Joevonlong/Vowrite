import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "laptopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Sidebar Navigation

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case history = "History"
    case account = "Account"
    case settings = "Settings"
    case personalization = "Personalization"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .account: return "person.circle"
        case .settings: return "gearshape"
        case .personalization: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Main Window

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedItem: SidebarItem = .home
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
        case .home:
            HomePageView()
                .environmentObject(appState)
        case .history:
            HistoryPageView()
                .environmentObject(appState)
        case .account:
            AccountPageView()
        case .settings:
            SettingsPageView()
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

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(icon: "clock", value: formatMinutes(appState.totalDictationTime), label: "Total dictation time")
                    StatCard(icon: "mic", value: "\(appState.totalWords)", label: "Words dictated")
                    StatCard(icon: "text.badge.checkmark", value: "\(appState.totalDictations)", label: "Dictations")
                }

                HStack(spacing: 16) {
                    QuickActionCard(
                        title: "API Status",
                        description: appState.hasAPIKey ? "Connected and ready" : "Set up your provider keys to get started",
                        icon: appState.hasAPIKey ? "checkmark.circle.fill" : "key.fill",
                        iconColor: appState.hasAPIKey ? .green : .orange
                    )
                    QuickActionCard(
                        title: "Permissions",
                        description: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? "All permissions granted" : "Some permissions needed",
                        icon: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? "lock.open.fill" : "lock.fill",
                        iconColor: PermissionManager.hasMicrophoneAccess() && PermissionManager.hasAccessibilityAccess()
                            ? .green : .orange
                    )
                }

                if let result = appState.lastResult {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Last dictation").font(.headline)
                            Spacer()
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(result, forType: .string)
                            }
                            .buttonStyle(.bordered).controlSize(.small)
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
                Image(systemName: icon).foregroundColor(.secondary).font(.caption)
                Text(value).font(.system(size: 20, weight: .bold))
            }
            Text(label).font(.caption).foregroundColor(.secondary)
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
            Image(systemName: icon).font(.title2).foregroundColor(iconColor).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06)).cornerRadius(12)
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

// MARK: - Account Page

struct AccountPageView: View {
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Account")
                    .font(.system(size: 24, weight: .bold))

                if authManager.isLoggedIn {
                    profileCard
                } else {
                    configurationCard
                }
            }
            .padding(32)
        }
    }

    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 56)).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.userName ?? "Vowrite User")
                        .font(.title2).fontWeight(.semibold)
                    Text(authManager.userEmail ?? "")
                        .font(.body).foregroundColor(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.caption)
                        Text("Connected via Google").font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan").font(.caption).foregroundColor(.secondary)
                    Text("Free").fontWeight(.medium)
                }
                Spacer()
                Button("Sign Out") { authManager.signOut() }.buttonStyle(.bordered)
            }
        }
        .padding(20).background(Color.secondary.opacity(0.06)).cornerRadius(12)
    }

    private var configurationCard: some View {
        let configuration = APIConfig.current
        let presetName = APIConfig.activePreset?.name ?? "Custom"
        let missingProviders = KeyVault.missingProviders(for: configuration)

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 36)).foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unified Split Configuration").font(.title3).fontWeight(.semibold)
                    Text("Preset: \(presetName)")
                        .font(.body).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STT").font(.caption).foregroundColor(.secondary)
                    Text("\(configuration.stt.provider.rawValue) · \(configuration.stt.model)")
                        .font(.caption2)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Polish").font(.caption).foregroundColor(.secondary)
                    Text("\(configuration.polish.provider.rawValue) · \(configuration.polish.model)")
                        .font(.caption2)
                        .lineLimit(1)
                }
                Spacer()
            }
            Divider()
            if missingProviders.isEmpty {
                Label("Required provider keys are ready in Keychain.", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Label(
                    "Missing keys: \(missingProviders.map(\.rawValue).joined(separator: ", "))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundColor(.orange)
                .font(.caption)
            }
            Text("Manage providers, presets, and API keys from the Settings sidebar.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20).background(Color.secondary.opacity(0.06)).cornerRadius(12)
    }
}

// MARK: - Settings Page (Models + Hotkey + Permissions + General)

struct SettingsPageView: View {
    @EnvironmentObject var appState: AppState
    @State private var workingConfig = APIConfig.current
    @State private var selectedPresetID = customPresetID
    @State private var newPresetName = ""
    @State private var keyInputs: [APIProvider: String] = [:]
    @State private var keyEditorExpanded: [APIProvider: Bool] = [:]
    @State private var configSaved = false
    @State private var keysSaved = false
    @State private var sttTestState: EndpointTestState = .idle
    @State private var polishTestState: EndpointTestState = .idle
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue

    private static let customPresetID = "__custom_preset__"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header with appearance toggle
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.system(size: 24, weight: .bold))
                        Text(configurationSummaryLine)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    AppearancePicker(selection: $appearanceMode)
                }

                SettingsSection(icon: "square.stack.3d.up", title: "Presets") {
                    presetsContent
                }

                SettingsSection(icon: "waveform", title: "STT") {
                    PipelineConfigurationEditor(
                        title: "Speech-to-text",
                        description: "Choose the provider and model used for transcription.",
                        isSpeechToText: true,
                        configuration: $workingConfig.stt
                    )
                }

                SettingsSection(icon: "sparkles", title: "Polish") {
                    PipelineConfigurationEditor(
                        title: "Cleanup and rewrite",
                        description: "Choose the provider and model used for text polish.",
                        isSpeechToText: false,
                        configuration: $workingConfig.polish
                    )
                }

                SettingsSection(icon: "key", title: "API Keys") {
                    apiKeysContent
                }

                SettingsSection(icon: "globe", title: "Language") {
                    LanguageContent()
                }

                SettingsSection(icon: "keyboard", title: "Keyboard shortcuts") {
                    VStack(spacing: 12) {
                        SettingsRow(title: "Dictate", description: "Press to start and stop dictation.") {
                            HotkeyRecorderButton(
                                currentKeyCode: appState.hotkeyManager.keyCode,
                                currentModifiers: appState.hotkeyManager.modifiers
                            ) { code, mods in
                                appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                            }
                        }
                        // F-018: Push to Talk toggle
                        SettingsRow(title: "Push to Talk", description: "Hold hotkey to record, release to stop.") {
                            Toggle("", isOn: Binding(
                                get: { appState.hotkeyManager.pushToTalkEnabled },
                                set: { appState.hotkeyManager.pushToTalkEnabled = $0 }
                            ))
                            .toggleStyle(.switch)
                        }
                        // F-018: Mode shortcuts info
                        SettingsRow(title: "Mode Shortcuts", description: "⌃1 through ⌃9 to switch modes.") {
                            Text("Built-in")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                SettingsSection(icon: "lock.shield", title: "Permissions") {
                    PermissionsContent()
                }

                SettingsSection(icon: "power", title: "General") {
                    GeneralContent()
                }
            }
            .padding(32)
        }
        .onAppear(perform: loadState)
        .onChange(of: workingConfig) { _, newValue in
            // Keep the chosen preset selected while the user edits away from it,
            // but snap back if the working config exactly matches a known preset.
            if let matchingPreset = APIPresetStore.matchingPreset(for: newValue) {
                selectedPresetID = matchingPreset.id
            }
            configSaved = false
            sttTestState = .idle
            polishTestState = .idle
        }
    }

    private var presetsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsRow(
                title: "Active Preset",
                description: currentPresetDescription,
                layout: .vertical
            ) {
                HStack(spacing: 10) {
                    Picker("Preset", selection: $selectedPresetID) {
                        Text("Custom").tag(Self.customPresetID)
                        ForEach(APIPresetStore.allPresets) { preset in
                            Text(presetPickerLabel(for: preset)).tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedPresetID) { _, newValue in
                        guard newValue != Self.customPresetID,
                              let preset = APIPresetStore.preset(for: newValue) else {
                            return
                        }
                        workingConfig = preset.configuration
                    }

                    Button("Reset to Recommended") {
                        applyRecommendedPreset()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .disabled(
                        selectedPresetID == BuiltInAPIPreset.recommended.id &&
                        !isSelectedPresetModified
                    )
                }
            }

            Divider()

            SettingsRow(
                title: "Save & Test",
                description: "",
                layout: .vertical
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    // Save as preset row
                    HStack(spacing: 8) {
                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 240)

                        Button("Save as Preset") {
                            let preset = APIPresetStore.saveUserPreset(name: newPresetName, configuration: workingConfig)
                            selectedPresetID = APIPresetStore.userPresetID(for: preset.id)
                            newPresetName = ""
                        }
                        .buttonStyle(.bordered)

                        Button("Delete Selected") {
                            deleteSelectedPreset()
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedUserPresetID == nil)
                    }

                    // Test & apply row
                    HStack(spacing: 8) {
                        Button {
                            testEndpoint(.stt)
                        } label: {
                            HStack(spacing: 4) {
                                if sttTestState.isTesting {
                                    ProgressView().controlSize(.small)
                                }
                                Text("Test STT")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canTest(.stt) || sttTestState.isTesting)

                        EndpointTestBadge(state: sttTestState)

                        Button {
                            testEndpoint(.polish)
                        } label: {
                            HStack(spacing: 4) {
                                if polishTestState.isTesting {
                                    ProgressView().controlSize(.small)
                                }
                                Text("Test Polish")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canTest(.polish) || polishTestState.isTesting)

                        EndpointTestBadge(state: polishTestState)

                        Spacer()

                        if configSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }

                        Button("Save Configuration") {
                            saveConfiguration()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var apiKeysContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage").font(.body).fontWeight(.semibold)
                    Text("Keys are stored in macOS Keychain once per provider.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if keysSaved {
                    Label("Keys saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(KeyVault.managedProviders.enumerated()), id: \.element.id) { index, provider in
                    providerKeyRow(for: provider)
                        .padding(.vertical, 8)

                    if index < KeyVault.managedProviders.count - 1 {
                        Divider()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Save Keys") {
                    saveKeys()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasPendingKeyChanges)
            }
        }
    }

    private var selectedUserPresetID: UUID? {
        APIPresetStore.preset(for: selectedPresetID)?.userPresetID
    }

    private func keyBinding(for provider: APIProvider) -> Binding<String> {
        Binding(
            get: { keyInputs[provider] ?? "" },
            set: { keyInputs[provider] = $0 }
        )
    }

    private func loadState() {
        workingConfig = APIConfig.current
        selectedPresetID = APIConfig.activePreset?.id ?? APIPresetStore.matchingPreset(for: workingConfig)?.id ?? Self.customPresetID
        keyInputs = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, "") })
        keyEditorExpanded = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, false) })
        sttTestState = .idle
        polishTestState = .idle
    }

    private func saveConfiguration() {
        let presetID = APIPresetStore.matchingPreset(for: workingConfig)?.id
        APIConfig.apply(workingConfig, presetID: presetID)
        AuthManager.shared.setAuthMode(.apiKey)
        configSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { configSaved = false }
    }

    private func saveKeys() {
        for provider in KeyVault.managedProviders {
            let value = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                _ = KeyVault.saveKey(value, for: provider)
                keyInputs[provider] = ""
                keyEditorExpanded[provider] = false
            }
        }
        AuthManager.shared.setAuthMode(.apiKey)
        keysSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { keysSaved = false }
    }

    private func deleteSelectedPreset() {
        guard let userPresetID = selectedUserPresetID else { return }
        APIPresetStore.deleteUserPreset(id: userPresetID)
        selectedPresetID = APIPresetStore.matchingPreset(for: workingConfig)?.id ?? Self.customPresetID
    }

    private var configurationSummaryLine: String {
        "\(workingConfig.stt.provider.rawValue) STT · \(workingConfig.polish.provider.rawValue) Polish · \(summaryKeyStatus)"
    }

    private var summaryKeyStatus: String {
        let requiredProviders = KeyVault.requiredProviders(for: workingConfig)
        guard !requiredProviders.isEmpty else { return "No keys needed" }

        let readyCount = requiredProviders.filter(providerHasReadyKey).count
        return readyCount == requiredProviders.count
            ? "\(readyCount) keys ready"
            : "\(readyCount)/\(requiredProviders.count) keys ready"
    }

    private var hasPendingKeyChanges: Bool {
        KeyVault.managedProviders.contains { provider in
            !(keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var isSelectedPresetModified: Bool {
        guard let preset = APIPresetStore.preset(for: selectedPresetID) else { return false }
        return preset.configuration != workingConfig
    }

    private func presetPickerLabel(for preset: APIPresetOption) -> String {
        let baseName = presetDisplayName(for: preset)
        return "\(baseName) · \(preset.summary)"
    }

    private func presetDisplayName(for preset: APIPresetOption) -> String {
        let isRecommendedPreset = preset.id == BuiltInAPIPreset.recommended.id
        let prefix = isRecommendedPreset ? "⭐ " : ""
        let suffix = selectedPresetID == preset.id && preset.configuration != workingConfig ? " (modified)" : ""
        return "\(prefix)\(preset.name)\(suffix)"
    }

    private func presetSummaryText(for preset: APIPresetOption) -> String {
        if preset.configuration != workingConfig {
            return "\(preset.summary) · Current settings are modified from this preset."
        }
        return preset.summary
    }

    private func applyRecommendedPreset() {
        selectedPresetID = BuiltInAPIPreset.recommended.id
        workingConfig = BuiltInAPIPreset.recommended.configuration
    }

    private var currentPresetDescription: String {
        if let preset = APIPresetStore.preset(for: selectedPresetID) {
            return presetSummaryText(for: preset)
        }
        return "Manual configuration. Save it as a preset if you want to reuse it."
    }

    private func providerKeyRow(for provider: APIProvider) -> some View {
        let isConfigured = KeyVault.hasKey(for: provider)
        let isExpanded = isKeyEditorExpanded(for: provider)

        return HStack(alignment: .top, spacing: 12) {
            // Left: provider name + status
            HStack(spacing: 8) {
                Text(provider.rawValue)
                    .font(.body).fontWeight(.medium)

                ProviderKeyStatusBadge(
                    provider: provider,
                    isRequired: providerIsInUse(provider)
                )
            }
            .frame(minWidth: 140, alignment: .leading)

            // Middle: masked key or input
            VStack(alignment: .leading, spacing: 6) {
                if isConfigured, let maskedKey = KeyVault.maskedKey(for: provider), !isExpanded {
                    Text(maskedKey)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    SecureField(provider.keyPlaceholder, text: keyBinding(for: provider))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }

                if !provider.keyURL.isEmpty && !isConfigured {
                    Link("Get \(provider.rawValue) key →", destination: URL(string: provider.keyURL)!)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: actions
            HStack(spacing: 6) {
                if isConfigured {
                    Button("Edit") {
                        keyEditorExpanded[provider] = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Button("Clear") {
                        _ = KeyVault.deleteKey(for: provider)
                        keyInputs[provider] = ""
                        keyEditorExpanded[provider] = false
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                } else if !isExpanded {
                    Button("Add") {
                        keyEditorExpanded[provider] = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
    }

    private func providerIsInUse(_ provider: APIProvider) -> Bool {
        workingConfig.stt.provider == provider || workingConfig.polish.provider == provider
    }

    private func providerUsageText(for provider: APIProvider) -> String {
        switch (workingConfig.stt.provider == provider, workingConfig.polish.provider == provider) {
        case (true, true):
            return "Used for STT and Polish"
        case (true, false):
            return "Used for STT"
        case (false, true):
            return "Used for Polish"
        case (false, false):
            return ""
        }
    }

    private func providerKeyDescription(for provider: APIProvider) -> String {
        let usage = providerUsageText(for: provider)
        if usage.isEmpty {
            return "Stored once in Keychain for this provider."
        }
        return "\(usage). Stored once in Keychain for this provider."
    }

    private func isKeyEditorExpanded(for provider: APIProvider) -> Bool {
        let hasSavedKey = KeyVault.hasKey(for: provider)
        if !hasSavedKey && providerIsInUse(provider) {
            return true
        }
        return keyEditorExpanded[provider] ?? false
    }

    private func providerHasReadyKey(_ provider: APIProvider) -> Bool {
        if KeyVault.hasKey(for: provider) {
            return true
        }
        return !(keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func canTest(_ endpoint: SettingsEndpoint) -> Bool {
        switch endpoint {
        case .stt:
            return workingConfig.stt.provider.hasSTTSupport && endpointHasRequiredKey(workingConfig.stt)
        case .polish:
            return endpointHasRequiredKey(workingConfig.polish)
        }
    }

    private func endpointHasRequiredKey(_ configuration: APIEndpointConfiguration) -> Bool {
        !configuration.provider.requiresAPIKey || providerHasReadyKey(configuration.provider)
    }

    private func testEndpoint(_ endpoint: SettingsEndpoint) {
        switch endpoint {
        case .stt:
            sttTestState = .testing
        case .polish:
            polishTestState = .testing
        }

        let configuration = endpoint.configuration(from: workingConfig)
        let apiKeyOverride = keyInputOverride(for: configuration.provider)

        Task {
            do {
                switch endpoint {
                case .stt:
                    try await SettingsConnectionTester.testSpeechToText(
                        configuration: configuration,
                        apiKeyOverride: apiKeyOverride
                    )
                case .polish:
                    try await SettingsConnectionTester.testChatCompletion(
                        configuration: configuration,
                        apiKeyOverride: apiKeyOverride
                    )
                }

                await MainActor.run {
                    switch endpoint {
                    case .stt:
                        sttTestState = .result(success: true, message: "✅ Ready")
                    case .polish:
                        polishTestState = .result(success: true, message: "✅ Ready")
                    }
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    switch endpoint {
                    case .stt:
                        sttTestState = .result(success: false, message: "❌ \(message)")
                    case .polish:
                        polishTestState = .result(success: false, message: "❌ \(message)")
                    }
                }
            }
        }
    }

    private func keyInputOverride(for provider: APIProvider) -> String? {
        let trimmed = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum SettingsEndpoint {
    case stt
    case polish

    func configuration(from splitConfiguration: SplitAPIConfiguration) -> APIEndpointConfiguration {
        switch self {
        case .stt:
            return splitConfiguration.stt
        case .polish:
            return splitConfiguration.polish
        }
    }
}

enum EndpointTestState: Equatable {
    case idle
    case testing
    case result(success: Bool, message: String)

    var isTesting: Bool {
        if case .testing = self {
            return true
        }
        return false
    }
}

struct EndpointTestBadge: View {
    let state: EndpointTestState

    var body: some View {
        switch state {
        case .idle, .testing:
            EmptyView()
        case .result(let success, let message):
            Text(message)
                .font(.caption)
                .foregroundColor(success ? .green : .red)
        }
    }
}

enum SettingsConnectionTester {
    static func testChatCompletion(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        try await APIConnectionTester.testChatCompletion(
            configuration: configuration,
            apiKeyOverride: apiKeyOverride
        )
    }

    static func testSpeechToText(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        let endpoint = "\(configuration.resolvedBaseURL)/audio/transcriptions"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid base URL")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let apiKey = resolvedAPIKey(for: configuration, override: apiKeyOverride) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if configuration.provider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

        request.httpBody = transcriptionProbeBody(boundary: boundary, model: configuration.model)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("Error \(httpResponse.statusCode): \(body)")
        }
    }

    private static func resolvedAPIKey(
        for configuration: APIEndpointConfiguration,
        override: String?
    ) -> String? {
        let trimmedOverride = override?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedOverride, !trimmedOverride.isEmpty {
            return trimmedOverride
        }
        return configuration.key
    }

    private static func transcriptionProbeBody(boundary: String, model: String) -> Data {
        var body = Data()
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"probe.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(silentWAVData())
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    // A tiny valid WAV keeps the STT probe cheap while still exercising the real endpoint.
    private static func silentWAVData(
        sampleRate: UInt32 = 16_000,
        durationSeconds: Double = 0.1
    ) -> Data {
        let samples = max(1, Int(Double(sampleRate) * durationSeconds))
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples) * UInt32(blockAlign)

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLE(UInt32(36) + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(byteRate)
        data.appendLE(blockAlign)
        data.appendLE(bitsPerSample)
        data.append("data".data(using: .ascii)!)
        data.appendLE(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer)
        }
    }
}

// MARK: - Language Content

struct LanguageContent: View {
    @State private var selectedLanguage: SupportedLanguage = LanguageConfig.globalLanguage

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Default Language", description: "Language hint for speech recognition. \"Auto-detect\" works best for most users.") {
                Picker("", selection: $selectedLanguage) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .frame(width: 180)
                .onChange(of: selectedLanguage) { _, v in
                    LanguageConfig.globalLanguage = v
                }
            }

            if selectedLanguage != .auto {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Setting a specific language forces the speech engine to that language. If you speak multiple languages or mix languages, use \"Auto-detect\".")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                }
            }
        }
    }
}

struct PipelineConfigurationEditor: View {
    let title: String
    let description: String
    let isSpeechToText: Bool
    @Binding var configuration: APIEndpointConfiguration

    /// Controls whether the custom model text field is in editing mode
    @State private var isEditingCustomModel = false
    /// Draft text while editing custom model
    @State private var customModelDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(
                title: "Provider",
                description: providerRowDescription
            ) {
                HStack(spacing: 8) {
                    PipelineKeyStatusBadge(configuration: configuration, isSpeechToText: isSpeechToText)

                    Picker("Provider", selection: providerBinding) {
                        ForEach(APIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .frame(width: 220)
                    .labelsHidden()
                }
            }

            Divider()

            if !modelSuggestions.isEmpty {
                SettingsRow(
                    title: "Model",
                    description: modelRowDescription,
                    layout: .vertical
                ) {
                    Picker("Model", selection: quickModelBinding) {
                        ForEach(modelSuggestions, id: \.self) { model in
                            if let desc = modelDescription(for: model) {
                                Text("\(model) · \(desc)").tag(model)
                            } else {
                                Text(model).tag(model)
                            }
                        }
                        Divider()
                        Text("Custom…").tag(customModelTag)
                    }
                    .labelsHidden()
                }

                if isCustomModel {
                    SettingsRow(
                        title: "Custom Model",
                        description: "Use any provider-specific model identifier when the preset list is not enough.",
                        layout: .vertical
                    ) {
                        customModelEditor(width: .infinity)
                    }
                }
            } else {
                SettingsRow(
                    title: "Custom Model",
                    description: "This provider uses a free-form model identifier.",
                    layout: .vertical
                ) {
                    customModelEditor(width: .infinity)
                }
            }

            Divider()

            SettingsRow(
                title: "Base URL",
                description: baseURLDescription,
                layout: .vertical
            ) {
                if configuration.provider == .custom || configuration.provider == .ollama {
                    TextField("Base URL", text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(configuration.resolvedBaseURL)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Private

    private let customModelTag = "__custom_model__"

    private var modelSuggestions: [String] {
        isSpeechToText ? configuration.provider.presetSTTModels : configuration.provider.presetPolishModels
    }

    /// True when the current model is not in the preset list
    private var isCustomModel: Bool {
        !modelSuggestions.isEmpty && !modelSuggestions.contains(configuration.model)
    }

    /// Confirm the custom model draft and lock the field
    private func confirmCustomModel() {
        let trimmed = customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configuration.model = trimmed
        isEditingCustomModel = false
    }

    private var providerBinding: Binding<APIProvider> {
        Binding(
            get: { configuration.provider },
            set: { newProvider in
                configuration.provider = newProvider
                configuration.baseURL = newProvider.defaultBaseURL
                configuration.model = isSpeechToText ? newProvider.defaultSTTModel : newProvider.defaultPolishModel
                // Reset custom editing state when provider changes
                isEditingCustomModel = false
                customModelDraft = ""
            }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { configuration.baseURL },
            set: { configuration.baseURL = $0 }
        )
    }

    private var quickModelBinding: Binding<String> {
        Binding(
            get: {
                modelSuggestions.contains(configuration.model) ? configuration.model : customModelTag
            },
            set: { selection in
                if selection == customModelTag {
                    // Enter custom editing mode
                    customModelDraft = ""
                    isEditingCustomModel = true
                    configuration.model = ""
                } else {
                    configuration.model = selection
                    isEditingCustomModel = false
                }
            }
        )
    }

    private func modelDescription(for model: String) -> String? {
        isSpeechToText ? APIProvider.sttModelDescription(model) : APIProvider.polishModelDescription(model)
    }

    private var providerRowDescription: String {
        var parts = [description]

        if isSpeechToText, let note = configuration.provider.sttSupportNote {
            parts.append(note)
        }

        if configuration.provider.requiresAPIKey {
            parts.append("Uses the \(configuration.provider.rawValue) key from the API Keys section.")
        } else {
            parts.append("This provider does not require an API key.")
        }

        return parts.joined(separator: " ")
    }

    private var modelRowDescription: String {
        if modelSuggestions.isEmpty {
            return "Enter a model ID manually for this provider."
        }
        return "Choose a preset model or switch to a custom model ID."
    }

    private var baseURLDescription: String {
        if configuration.provider == .custom || configuration.provider == .ollama {
            return "Override the endpoint URL used for this \(title.lowercased()) pipeline."
        }
        return "Uses the provider default endpoint."
    }

    @ViewBuilder
    private func customModelEditor(width: CGFloat) -> some View {
        if isEditingCustomModel || modelSuggestions.isEmpty || configuration.model.isEmpty {
            HStack(spacing: 8) {
                TextField(modelFieldPlaceholder, text: $customModelDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { confirmCustomModel() }

                Button("Confirm") { confirmCustomModel() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .onAppear {
                if configuration.model.isEmpty {
                    isEditingCustomModel = true
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(configuration.model)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                Button("Edit") {
                    customModelDraft = configuration.model
                    isEditingCustomModel = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var modelFieldPlaceholder: String {
        modelSuggestions.isEmpty ? "Model ID" : "Enter model ID (e.g. gpt-4o-mini)"
    }
}

struct ProviderKeyStatusBadge: View {
    let provider: APIProvider
    let isRequired: Bool

    var body: some View {
        Group {
            if KeyVault.hasKey(for: provider) {
                badge("Saved", color: .green)
            } else if isRequired {
                badge("Required", color: .orange)
            } else {
                badge("Missing", color: .secondary)
            }
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(999)
    }
}

struct PipelineKeyStatusBadge: View {
    let configuration: APIEndpointConfiguration
    let isSpeechToText: Bool

    var body: some View {
        if isSpeechToText && !configuration.provider.hasSTTSupport {
            badge("Unsupported", color: .orange)
        } else if !configuration.provider.requiresAPIKey {
            badge("No key", color: .secondary)
        } else if configuration.hasKey {
            badge("Key ready", color: .green)
        } else {
            badge("Key missing", color: .orange)
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(999)
    }
}

// MARK: - Personalization Page

struct PersonalizationPageView: View {
    @State private var userPrompt = PromptConfig.userPrompt
    @ObservedObject private var sceneManager = SceneManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personalization")
                    .font(.system(size: 24, weight: .bold))

                // User Prompt
                SettingsSection(icon: "person.text.rectangle", title: "Your Preferences") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Customize how your voice input is polished. Examples: \"Technical terms keep English\", \"Use Arabic numerals\", \"Formal business tone\"")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Button("Clear") { userPrompt = ""; PromptConfig.userPrompt = "" }
                                .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        TextEditor(text: $userPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .border(Color.secondary.opacity(0.3))
                            .onChange(of: userPrompt) { _, v in PromptConfig.userPrompt = v }
                    }
                }

                // Output Scene
                SettingsSection(icon: "theatermasks", title: "Output Scene") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a scene to automatically adjust output formatting.")
                            .font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(sceneManager.allScenes) { scene in
                                SceneCardView(scene: scene, isSelected: sceneManager.currentSceneId == scene.id) {
                                    sceneManager.select(scene)
                                }
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
    }
}

// MARK: - Scene Card

struct SceneCardView: View {
    let scene: SceneProfile
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scene.icon).font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(scene.name).font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
                    .padding(16)
            }
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row

// MARK: - Appearance Picker

struct AppearancePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = mode.rawValue
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.caption)
                        .frame(width: 28, height: 24)
                        .background(
                            selection == mode.rawValue
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .foregroundColor(
                            selection == mode.rawValue
                                ? .accentColor
                                : .secondary
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(mode.rawValue)
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}

/// Layout mode for settings rows.
/// - `.horizontal`: label left, control right (default for toggles, short pickers)
/// - `.vertical`: label top, control below full-width (for long content like model selectors, presets)
enum SettingsRowLayout {
    case horizontal
    case vertical
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    let description: String
    var layout: SettingsRowLayout = .horizontal
    @ViewBuilder let trailing: Trailing

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                HStack(alignment: .top, spacing: 24) {
                    labelView
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailing
                        .frame(maxWidth: 360, alignment: .trailing)
                }
            case .vertical:
                VStack(alignment: .leading, spacing: 10) {
                    labelView
                    trailing
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var labelView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body).fontWeight(.semibold)
            if !description.isEmpty {
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
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
                Task { @MainActor in hasMic = PermissionManager.hasMicrophoneAccess(); hasAcc = PermissionManager.hasAccessibilityAccess() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - General Content

struct GeneralContent: View {
    @State private var launchAtLogin = false
    @State private var overlayStyle = OverlayStyle.current

    var body: some View {
        VStack(spacing: 12) {
            SettingsRow(title: "Launch at login", description: "Start Vowrite when you log in") {
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { _, v in
                        do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
                    }
            }
            // F-022: Overlay style
            SettingsRow(title: "Recording overlay", description: "Size of the floating recording bar") {
                Picker("", selection: $overlayStyle) {
                    ForEach(OverlayStyle.allCases, id: \.rawValue) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .frame(width: 120)
                .onChange(of: overlayStyle) { _, v in
                    OverlayStyle.current = v
                }
            }
        }
    }
}

// MARK: - About Page

struct AboutPageView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.circle.fill").font(.system(size: 64)).foregroundColor(.accentColor)
            Text("Vowrite").font(.system(size: 32, weight: .bold))
            Text("AI Voice Keyboard").font(.title3).foregroundColor(.secondary)
            Text("v\(AppVersion.current)").font(.caption).foregroundColor(.secondary)
            Text("Say it once. Mean it perfectly.").font(.body).italic().foregroundColor(.secondary)
            Divider().frame(width: 200)
            // F-026: Update controls
            VStack(spacing: 8) {
                Button("Check for Updates...") {
                    (NSApp.delegate as? AppDelegate)?.checkForUpdates()
                }
                Toggle("Automatically check for updates", isOn: Binding(
                    get: {
                        (NSApp.delegate as? AppDelegate)?.updaterController.updater.automaticallyChecksForUpdates ?? false
                    },
                    set: { newValue in
                        (NSApp.delegate as? AppDelegate)?.updaterController.updater.automaticallyChecksForUpdates = newValue
                    }
                ))
                .toggleStyle(.checkbox)
                .fixedSize()
            }
            Divider().frame(width: 200)
            HStack(spacing: 24) {
                Link("Website", destination: URL(string: "https://vowrite.com")!)
                Link("GitHub", destination: URL(string: "https://github.com/Joevonlong/Vowrite")!)
                Link("License (MIT)", destination: URL(string: "https://github.com/Joevonlong/Vowrite/blob/main/LICENSE")!)
            }.font(.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
