import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

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
    @State private var configSaved = false
    @State private var keysSaved = false

    private static let customPresetID = "__custom_preset__"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))

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
            selectedPresetID = APIPresetStore.matchingPreset(for: newValue)?.id ?? Self.customPresetID
            APIConfig.clearSelectedPresetIfNeeded(for: newValue)
        }
    }

    private var presetsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(title: "Preset", description: "Apply a built-in or saved split-provider configuration.") {
                Picker("", selection: $selectedPresetID) {
                    Text("Custom").tag(Self.customPresetID)
                    ForEach(APIPresetStore.allPresets) { preset in
                        Text("\(preset.name) · \(preset.summary)").tag(preset.id)
                    }
                }
                .frame(width: 320)
                .onChange(of: selectedPresetID) { _, newValue in
                    guard newValue != Self.customPresetID,
                          let preset = APIPresetStore.preset(for: newValue) else {
                        return
                    }
                    workingConfig = preset.configuration
                }
            }

            if let preset = APIPresetStore.preset(for: selectedPresetID) {
                Text(preset.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Manual configuration. Save it as a preset if you want to reuse it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                TextField("Preset name", text: $newPresetName)
                    .textFieldStyle(.roundedBorder)
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

    private var apiKeysContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keys are stored in macOS Keychain once per provider. The STT and Polish sections only reference them.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(KeyVault.managedProviders) { provider in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(provider.rawValue)
                            .font(.body.weight(.medium))
                        Spacer()
                        ProviderKeyStatusBadge(provider: provider)
                        if let maskedKey = KeyVault.maskedKey(for: provider) {
                            Text(maskedKey)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                        }
                        Button("Clear") {
                            _ = KeyVault.deleteKey(for: provider)
                            keyInputs[provider] = ""
                        }
                        .buttonStyle(.borderless)
                        .disabled(!KeyVault.hasKey(for: provider))
                    }

                    SecureField(provider.keyPlaceholder, text: keyBinding(for: provider))
                        .textFieldStyle(.roundedBorder)

                    if !provider.keyURL.isEmpty {
                        Link("Get \(provider.rawValue) key →", destination: URL(string: provider.keyURL)!)
                            .font(.caption)
                    }
                }
            }

            HStack {
                Spacer()
                if keysSaved {
                    Label("Keys saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                Button("Save Keys") {
                    saveKeys()
                }
                .buttonStyle(.borderedProminent)
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
        selectedPresetID = APIConfig.activePreset?.id ?? Self.customPresetID
        keyInputs = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, "") })
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                PipelineKeyStatusBadge(configuration: configuration, isSpeechToText: isSpeechToText)
            }

            Picker("Provider", selection: providerBinding) {
                ForEach(APIProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }

            if !modelSuggestions.isEmpty {
                Picker("Common Models", selection: quickModelBinding) {
                    ForEach(modelSuggestions, id: \.self) { model in
                        if let description = modelDescription(for: model) {
                            Text("\(model) · \(description)").tag(model)
                        } else {
                            Text(model).tag(model)
                        }
                    }
                    Text("Custom").tag(customModelTag)
                }
            }

            TextField("Model ID", text: modelBinding)
                .textFieldStyle(.roundedBorder)

            if configuration.provider == .custom || configuration.provider == .ollama {
                TextField("Base URL", text: baseURLBinding)
                    .textFieldStyle(.roundedBorder)
            } else {
                LabeledContent("Base URL") {
                    Text(configuration.resolvedBaseURL)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if isSpeechToText, let note = configuration.provider.sttSupportNote {
                Text(note)
                    .font(.caption)
                    .foregroundColor(configuration.provider.hasSTTSupport ? .secondary : .orange)
            }

            if configuration.provider.requiresAPIKey {
                Text("Uses the \(configuration.provider.rawValue) key from the API Keys section.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("This provider does not require an API key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private let customModelTag = "__custom_model__"

    private var modelSuggestions: [String] {
        isSpeechToText ? configuration.provider.presetSTTModels : configuration.provider.presetPolishModels
    }

    private var providerBinding: Binding<APIProvider> {
        Binding(
            get: { configuration.provider },
            set: { newProvider in
                configuration.provider = newProvider
                configuration.baseURL = newProvider.defaultBaseURL
                configuration.model = isSpeechToText ? newProvider.defaultSTTModel : newProvider.defaultPolishModel
            }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { configuration.model },
            set: { configuration.model = $0 }
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
                guard selection != customModelTag else { return }
                configuration.model = selection
            }
        )
    }

    private func modelDescription(for model: String) -> String? {
        isSpeechToText ? APIProvider.sttModelDescription(model) : APIProvider.polishModelDescription(model)
    }
}

struct ProviderKeyStatusBadge: View {
    let provider: APIProvider

    var body: some View {
        Group {
            if KeyVault.hasKey(for: provider) {
                badge("Saved", color: .green)
            } else {
                badge("Missing", color: .orange)
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.secondary)
                Text(title).font(.headline)
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
                Text(title).font(.body).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
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
