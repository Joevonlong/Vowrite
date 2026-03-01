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
                        description: appState.hasAPIKey ? "Connected and ready" : "Set up your API key to get started",
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
    @State private var googleClientID: String = GoogleAuthService.clientID ?? ""
    @State private var showAdvanced = false
    @State private var showNoClientIDAlert = false
    @State private var showAPIKeySetup = false
    @State private var editProvider: APIProvider = APIConfig.provider
    @State private var editKey: String = ""
    @State private var editBaseURL: String = ""
    @State private var editSTTModel: String = ""
    @State private var editPolishModel: String = ""
    @State private var apiSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Account")
                    .font(.system(size: 24, weight: .bold))

                if authManager.isLoggedIn {
                    profileCard
                } else if authManager.authMode == .apiKey, let key = KeychainHelper.getAPIKey(), !key.isEmpty {
                    apiKeySummaryCard(key: key)
                } else {
                    Text("Choose how to connect Vowrite to AI models")
                        .foregroundColor(.secondary)
                }

                if !authManager.isLoggedIn {
                    googleSignInCard
                    apiKeyCard
                }

                advancedSection
            }
            .padding(32)
        }
        .alert("Google Sign-In Setup Required", isPresented: $showNoClientIDAlert) {
            Button("OK") { showAdvanced = true }
        } message: {
            Text("To use Google Sign-In, configure a Google Cloud OAuth Client ID in the Advanced section below.")
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

    private func apiKeySummaryCard(key: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "key.fill").font(.system(size: 36)).foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected via API Key").font(.title3).fontWeight(.semibold)
                    Text("\(APIConfig.provider.rawValue) \u{00B7} \(maskKey(key))")
                        .font(.body).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STT").font(.caption).foregroundColor(.secondary)
                    Text(APIConfig.sttModel).font(.caption2).lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Polish").font(.caption).foregroundColor(.secondary)
                    Text(APIConfig.polishModel).font(.caption2).lineLimit(1)
                }
                Spacer()
                Button("Edit") { loadAPIDefaults(); showAPIKeySetup = true }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(20).background(Color.secondary.opacity(0.06)).cornerRadius(12)
    }

    private var googleSignInCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "globe").font(.title2).foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in with Google").font(.title3).fontWeight(.semibold)
                    Text("Get started instantly with your Google account")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
            }
            Button {
                if GoogleAuthService.clientID == nil || GoogleAuthService.clientID!.isEmpty {
                    showNoClientIDAlert = true
                } else {
                    authManager.signInWithGoogle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Continue with Google").fontWeight(.medium)
                }.frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authManager.isAuthenticating)

            if authManager.isAuthenticating {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Signing in...").foregroundColor(.secondary) }
            }
            if let error = authManager.authError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding(20).background(Color.blue.opacity(0.08)).cornerRadius(12)
    }

    private var apiKeyCard: some View {
        VStack(spacing: 12) {
            Button { if !showAPIKeySetup { loadAPIDefaults() }; showAPIKeySetup.toggle() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "key.fill").font(.title2).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use your own API Key").font(.body).fontWeight(.medium)
                        Text("Connect to OpenAI, OpenRouter, or other providers")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: showAPIKeySetup ? "chevron.up" : "chevron.down").foregroundColor(.secondary)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)

            if showAPIKeySetup {
                VStack(spacing: 12) {
                    Divider()
                    HStack { Text("Provider").frame(width: 80, alignment: .leading)
                        Picker("", selection: $editProvider) {
                            ForEach(APIProvider.allCases) { p in Text(p.rawValue).tag(p) }
                        }.onChange(of: editProvider) { _, v in
                            editBaseURL = v.defaultBaseURL; editSTTModel = v.defaultSTTModel; editPolishModel = v.defaultPolishModel
                        }
                    }
                    HStack { Text("API Key").frame(width: 80, alignment: .leading)
                        SecureField(editProvider.keyPlaceholder, text: $editKey).textFieldStyle(.roundedBorder)
                    }
                    if editProvider == .custom {
                        HStack { Text("Base URL").frame(width: 80, alignment: .leading)
                            TextField("https://...", text: $editBaseURL).textFieldStyle(.roundedBorder)
                        }
                    }
                    HStack { Text("STT Model").frame(width: 80, alignment: .leading)
                        TextField("", text: $editSTTModel).textFieldStyle(.roundedBorder)
                    }
                    HStack { Text("Polish").frame(width: 80, alignment: .leading)
                        TextField("", text: $editPolishModel).textFieldStyle(.roundedBorder)
                    }
                    if !editProvider.keyURL.isEmpty {
                        Link("Get API Key \u{2192}", destination: URL(string: editProvider.keyURL)!).font(.caption)
                    }
                    HStack {
                        Spacer()
                        if apiSaved { Label("Saved!", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption) }
                        Button("Save & Connect") { saveAPIKey() }.buttonStyle(.borderedProminent).disabled(editKey.isEmpty)
                    }
                }
            }
        }
        .padding(20).background(Color.secondary.opacity(0.06)).cornerRadius(12)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showAdvanced.toggle() } label: {
                HStack {
                    Text("Advanced").font(.caption).foregroundColor(.secondary)
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down").font(.caption2).foregroundColor(.secondary)
                }
            }.buttonStyle(.plain)
            if showAdvanced {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Google OAuth Client ID").font(.caption).foregroundColor(.secondary)
                    TextField("Enter your Google Cloud OAuth Client ID", text: $googleClientID)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: googleClientID) { _, v in GoogleAuthService.clientID = v }
                    Text("Redirect URI: \(GoogleAuthService.redirectURI)")
                        .font(.caption2).foregroundColor(.secondary).textSelection(.enabled)
                    Text("Create at console.cloud.google.com \u{2192} APIs & Services \u{2192} Credentials")
                        .font(.caption2).foregroundColor(.secondary)
                }.padding(12).background(Color.secondary.opacity(0.04)).cornerRadius(8)
            }
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}" }
        return "\(key.prefix(4))\u{2022}\u{2022}\u{2022}\u{2022}\(key.suffix(4))"
    }
    private func loadAPIDefaults() {
        editProvider = APIConfig.provider; editKey = ""
        editBaseURL = APIConfig.baseURL; editSTTModel = APIConfig.sttModel; editPolishModel = APIConfig.polishModel
    }
    private func saveAPIKey() {
        APIConfig.provider = editProvider; APIConfig.baseURL = editBaseURL
        APIConfig.sttModel = editSTTModel; APIConfig.polishModel = editPolishModel
        if !editKey.isEmpty { _ = KeychainHelper.saveAPIKey(editKey) }
        authManager.setAuthMode(.apiKey); apiSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { apiSaved = false; showAPIKeySetup = false }
    }
}

// MARK: - Settings Page (Models + Hotkey + Permissions + General)

struct SettingsPageView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))

                SettingsSection(icon: "cpu", title: "Models") {
                    ModelsContent()
                }

                SettingsSection(icon: "keyboard", title: "Keyboard shortcuts") {
                    SettingsRow(title: "Dictate", description: "Press to start and stop dictation.") {
                        HotkeyRecorderButton(
                            currentKeyCode: appState.hotkeyManager.keyCode,
                            currentModifiers: appState.hotkeyManager.modifiers
                        ) { code, mods in
                            appState.hotkeyManager.update(keyCode: code, modifiers: mods)
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
    }
}

// MARK: - Models Content (OpenRouter + manual)

struct ModelsContent: View {
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var editSTT: String = APIConfig.sttModel
    @State private var editPolish: String = APIConfig.polishModel
    @State private var saved = false

    var body: some View {
        VStack(spacing: 12) {
            if APIConfig.provider == .openrouter {
                HStack {
                    Button {
                        Task { await modelManager.refreshModels() }
                    } label: {
                        HStack(spacing: 4) {
                            if modelManager.isLoading { ProgressView().controlSize(.small) }
                            Text(modelManager.isLoading ? "Loading..." : "Refresh Models from OpenRouter")
                        }
                    }
                    .disabled(modelManager.isLoading)
                    Spacer()
                    if let e = modelManager.error { Text(e).font(.caption).foregroundColor(.red) }
                }
            }

            if !modelManager.sttModels.isEmpty {
                SettingsRow(title: "STT Model", description: "Speech-to-text") {
                    Picker("", selection: $editSTT) {
                        ForEach(modelManager.sttModels) { m in
                            Text(modelManager.isRecommendedSTTModel(m) ? "⭐ \(m.name)" : m.name).tag(m.id)
                        }
                    }.frame(width: 280)
                }
            } else {
                SettingsRow(title: "STT Model", description: "Speech-to-text") {
                    TextField("", text: $editSTT).textFieldStyle(.roundedBorder).frame(width: 240)
                }
            }

            if !modelManager.polishModels.isEmpty {
                SettingsRow(title: "Polish Model", description: "Text cleanup") {
                    Picker("", selection: $editPolish) {
                        ForEach(modelManager.polishModels) { m in
                            Text(modelManager.isRecommendedPolishModel(m) ? "⭐ \(m.name)" : m.name).tag(m.id)
                        }
                    }.frame(width: 280)
                }
            } else {
                SettingsRow(title: "Polish Model", description: "Text cleanup") {
                    TextField("", text: $editPolish).textFieldStyle(.roundedBorder).frame(width: 240)
                }
            }

            HStack {
                Spacer()
                if saved { Label("Saved", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption) }
                Button("Save Models") {
                    APIConfig.sttModel = editSTT
                    APIConfig.polishModel = editPolish
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                }.buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Personalization Page

struct PersonalizationPageView: View {
    @State private var systemPrompt = PromptConfig.systemPrompt
    @State private var userPrompt = PromptConfig.userPrompt
    @ObservedObject private var sceneManager = SceneManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personalization")
                    .font(.system(size: 24, weight: .bold))

                // System Prompt
                SettingsSection(icon: "cpu", title: "System Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("⚠️ Modifying the system prompt may affect core behavior.")
                                .font(.caption).foregroundColor(.orange)
                            Spacer()
                            Button("Reset to Default") {
                                PromptConfig.resetSystemPrompt()
                                systemPrompt = PromptConfig.systemPrompt
                            }.font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        TextEditor(text: $systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 200)
                            .border(Color.secondary.opacity(0.3))
                            .onChange(of: systemPrompt) { _, v in PromptConfig.systemPrompt = v }
                    }
                }

                // User Prompt
                SettingsSection(icon: "person.text.rectangle", title: "User Prompt") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Add personal preferences: \"Technical terms keep English\", \"Formal business tone\"")
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

    var body: some View {
        SettingsRow(title: "Launch at login", description: "Start Vowrite when you log in") {
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, v in
                    do { if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch {}
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
