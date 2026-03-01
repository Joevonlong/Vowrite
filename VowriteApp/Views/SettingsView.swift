import SwiftUI
import ServiceManagement
import Carbon.HIToolbox

// MARK: - API Provider

enum APIProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case openrouter = "OpenRouter"
    case groq = "Groq"
    case together = "Together AI"
    case deepseek = "DeepSeek"
    case custom = "Custom"

    var id: String { rawValue }

    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .groq: return "https://api.groq.com/openai/v1"
        case .together: return "https://api.together.xyz/v1"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .custom: return ""
        }
    }

    var defaultSTTModel: String {
        switch self {
        case .openai: return "whisper-1"
        case .openrouter: return "openai/whisper-large-v3"
        case .groq: return "whisper-large-v3-turbo"
        case .together: return "whisper-large-v3"
        case .deepseek: return "whisper-1"
        case .custom: return "whisper-1"
        }
    }

    var defaultPolishModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .openrouter: return "openai/gpt-4o-mini"
        case .groq: return "llama-3.1-8b-instant"
        case .together: return "meta-llama/Llama-3.1-8B-Instruct-Turbo"
        case .deepseek: return "deepseek-chat"
        case .custom: return "gpt-4o-mini"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .openrouter: return "sk-or-..."
        case .groq: return "gsk_..."
        case .together: return "..."
        case .deepseek: return "sk-..."
        case .custom: return "API Key"
        }
    }

    var keyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .openrouter: return "https://openrouter.ai/keys"
        case .groq: return "https://console.groq.com/keys"
        case .together: return "https://api.together.xyz/settings/api-keys"
        case .deepseek: return "https://platform.deepseek.com/api_keys"
        case .custom: return ""
        }
    }
}

// MARK: - API Config Storage

enum APIConfig {
    private static let providerKey = "apiProvider"
    private static let baseURLKey = "apiBaseURL"
    private static let sttModelKey = "apiSTTModel"
    private static let polishModelKey = "apiPolishModel"

    static var provider: APIProvider {
        get {
            guard let raw = UserDefaults.standard.string(forKey: providerKey),
                  let p = APIProvider(rawValue: raw) else { return .openai }
            return p
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? APIProvider.openai.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    static var sttModel: String {
        get { UserDefaults.standard.string(forKey: sttModelKey) ?? "whisper-1" }
        set { UserDefaults.standard.set(newValue, forKey: sttModelKey) }
    }

    static var polishModel: String {
        get { UserDefaults.standard.string(forKey: polishModelKey) ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: polishModelKey) }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            APISettingsTab()
                .environmentObject(appState)
                .tabItem { Label("API", systemImage: "key") }
            PromptsSettingsTab()
                .tabItem { Label("Prompts", systemImage: "text.bubble") }
            ScenesSettingsTab()
                .tabItem { Label("Scenes", systemImage: "theatermasks") }
            HotkeySettingsTab()
                .environmentObject(appState)
                .tabItem { Label("Hotkey", systemImage: "keyboard") }
            PermissionsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 520)
    }
}

// MARK: - API Settings Tab

struct APISettingsTab: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var modelManager = ModelManager.shared

    @State private var isEditing = false
    @State private var editProvider: APIProvider = .openai
    @State private var editKey: String = ""
    @State private var editBaseURL: String = ""
    @State private var editSTTModel: String = ""
    @State private var editPolishModel: String = ""
    @State private var savedFeedback = false
    @State private var editGoogleClientID: String = ""

    var body: some View {
        Form {
            if isEditing {
                editingView
            } else {
                displayView
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { loadCurrent() }
    }

    // MARK: Display mode — read-only

    private var displayView: some View {
        Group {
            Section("Account Mode") {
                LabeledContent("Mode") {
                    Text(authManager.authMode == .apiKey ? "API Key" : "Google Account")
                }
                if authManager.authMode == .apiKey {
                    LabeledContent("Provider", value: APIConfig.provider.rawValue)
                    LabeledContent("Base URL", value: APIConfig.baseURL)
                    LabeledContent("Key") {
                        if let key = KeychainHelper.getAPIKey(), !key.isEmpty {
                            Text(maskKey(key))
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        } else {
                            Text("Not set")
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    if authManager.isLoggedIn, let email = authManager.userEmail {
                        LabeledContent("Account", value: email)
                    } else {
                        LabeledContent("Status", value: "Not signed in")
                    }
                }
            }

            Section("Models") {
                LabeledContent("STT Model", value: APIConfig.sttModel)
                LabeledContent("Polish Model", value: APIConfig.polishModel)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Edit Configuration") {
                        loadCurrent()
                        isEditing = true
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
    }

    // MARK: Edit mode

    private var editingView: some View {
        Group {
            accountModeSection
            modelsSection
            actionSection
        }
    }

    // MARK: Account Mode Section

    private var accountModeSection: some View {
        Section("Account Mode") {
            Picker("Mode", selection: Binding(
                get: { authManager.authMode },
                set: { authManager.setAuthMode($0) }
            )) {
                Text("Use API Key").tag(AuthMode.apiKey)
                Text("Google Account").tag(AuthMode.googleAccount)
            }
            .pickerStyle(.segmented)

            if authManager.authMode == .apiKey {
                apiKeyEditView
            } else {
                googleAccountEditView
            }
        }
    }

    private var apiKeyEditView: some View {
        Group {
            Picker("Provider", selection: $editProvider) {
                ForEach(APIProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            .onChange(of: editProvider) { _, newValue in
                editBaseURL = newValue.defaultBaseURL
                editSTTModel = newValue.defaultSTTModel
                editPolishModel = newValue.defaultPolishModel
            }

            if editProvider == .custom {
                TextField("Base URL", text: $editBaseURL)
                    .textFieldStyle(.roundedBorder)
            } else {
                LabeledContent("Base URL", value: editBaseURL)
            }

            SecureField(editProvider.keyPlaceholder, text: $editKey)
                .textFieldStyle(.roundedBorder)

            if !editProvider.keyURL.isEmpty {
                Link("Get API Key \u{2192}", destination: URL(string: editProvider.keyURL)!)
                    .font(.caption)
            }
        }
    }

    private var googleAccountEditView: some View {
        Group {
            TextField("Google OAuth Client ID", text: $editGoogleClientID)
                .textFieldStyle(.roundedBorder)
                .onChange(of: editGoogleClientID) { _, newValue in
                    GoogleAuthService.clientID = newValue
                }

            LabeledContent("Redirect URI") {
                Text(GoogleAuthService.redirectURI)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
            }

            if authManager.isLoggedIn {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authManager.userName ?? "User")
                            .fontWeight(.medium)
                        Text(authManager.userEmail ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                }
            } else {
                if authManager.isAuthenticating {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Signing in...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button {
                        authManager.signInWithGoogle()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                            Text("Sign in with Google")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editGoogleClientID.isEmpty)
                }
            }

            if let error = authManager.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: Models Section

    private var modelsSection: some View {
        Section("Models") {
            if editProvider == .openrouter && !editKey.isEmpty {
                openRouterModelsView
            } else {
                TextField("STT Model", text: $editSTTModel)
                    .textFieldStyle(.roundedBorder)
                TextField("Polish Model", text: $editPolishModel)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var openRouterModelsView: some View {
        Group {
            HStack {
                Button {
                    Task { await modelManager.refreshModels() }
                } label: {
                    HStack(spacing: 4) {
                        if modelManager.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(modelManager.isLoading ? "Loading..." : "Refresh Models")
                    }
                }
                .disabled(modelManager.isLoading)

                Spacer()

                if let error = modelManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }

            if !modelManager.sttModels.isEmpty {
                Picker("STT Model", selection: $editSTTModel) {
                    ForEach(modelManager.sttModels) { model in
                        Text(modelManager.isRecommendedSTTModel(model)
                             ? "\u{2B50} \(model.name)" : model.name)
                            .tag(model.id)
                    }
                }
            } else {
                TextField("STT Model", text: $editSTTModel)
                    .textFieldStyle(.roundedBorder)
            }

            if !modelManager.polishModels.isEmpty {
                Picker("Polish Model", selection: $editPolishModel) {
                    ForEach(modelManager.polishModels) { model in
                        Text(modelManager.isRecommendedPolishModel(model)
                             ? "\u{2B50} \(model.name)" : model.name)
                            .tag(model.id)
                    }
                }
            } else {
                TextField("Polish Model", text: $editPolishModel)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: Action Section

    private var actionSection: some View {
        Section {
            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                Spacer()
                if savedFeedback {
                    Label("Saved!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                Button("Save") {
                    save()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Helpers

    private func loadCurrent() {
        editProvider = APIConfig.provider
        editKey = KeychainHelper.getAPIKey() ?? ""
        editBaseURL = APIConfig.baseURL
        editSTTModel = APIConfig.sttModel
        editPolishModel = APIConfig.polishModel
        editGoogleClientID = GoogleAuthService.clientID ?? ""
    }

    private func save() {
        APIConfig.provider = editProvider
        APIConfig.baseURL = editBaseURL
        APIConfig.sttModel = editSTTModel
        APIConfig.polishModel = editPolishModel
        if !editKey.isEmpty {
            _ = KeychainHelper.saveAPIKey(editKey)
        }
        GoogleAuthService.clientID = editGoogleClientID
        appState.objectWillChange.send()
        savedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            savedFeedback = false
            isEditing = false
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}" }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)\u{2022}\u{2022}\u{2022}\u{2022}\(suffix)"
    }
}

// MARK: - Prompts Settings Tab

struct PromptsSettingsTab: View {
    @State private var systemPrompt = PromptConfig.systemPrompt
    @State private var userPrompt = PromptConfig.userPrompt

    var body: some View {
        Form {
            Section("System Prompt") {
                Text("Modifying the system prompt may affect core behavior. Reset to default if issues occur.")
                    .font(.caption)
                    .foregroundColor(.orange)

                TextEditor(text: $systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 160)
                    .onChange(of: systemPrompt) { _, newValue in
                        PromptConfig.systemPrompt = newValue
                    }

                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        PromptConfig.resetSystemPrompt()
                        systemPrompt = PromptConfig.systemPrompt
                    }
                    .font(.caption)
                }
            }

            Section("User Prompt") {
                Text("Add your personal preferences. Examples: \"Technical terms keep English\" \"Use Arabic numerals\" \"Formal business tone\"")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $userPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .onChange(of: userPrompt) { _, newValue in
                        PromptConfig.userPrompt = newValue
                    }

                HStack {
                    Spacer()
                    Button("Clear") {
                        userPrompt = ""
                        PromptConfig.userPrompt = ""
                    }
                    .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Scenes Settings Tab

struct ScenesSettingsTab: View {
    @ObservedObject private var sceneManager = SceneManager.shared

    var body: some View {
        Form {
            Section("Scene Formatting") {
                Text("Choose a scene to automatically adjust the AI output style. The scene prompt is appended to your system and user prompts.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(sceneManager.allScenes) { scene in
                    Button {
                        sceneManager.select(scene)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: scene.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scene.name)
                                    .fontWeight(sceneManager.currentSceneId == scene.id ? .semibold : .regular)
                                if !scene.promptTemplate.isEmpty {
                                    Text(scene.promptTemplate.prefix(80) + (scene.promptTemplate.count > 80 ? "..." : ""))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if sceneManager.currentSceneId == scene.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Hotkey Settings Tab

struct HotkeySettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var hotkeyCode: UInt32 = UInt32(kVK_Space)
    @State private var hotkeyMods: UInt32 = UInt32(optionKey)
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Recording Hotkey") {
                HStack {
                    Text("Toggle recording")
                    Spacer()
                    HotkeyRecorderButton(
                        currentKeyCode: hotkeyCode,
                        currentModifiers: hotkeyMods
                    ) { code, mods in
                        hotkeyCode = code
                        hotkeyMods = mods
                        appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                    }
                }
                Text("Click the box, then press your desired modifier + key combination. Press Esc to cancel.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Reset to Default (⌥Space)") {
                    hotkeyCode = UInt32(kVK_Space)
                    hotkeyMods = UInt32(optionKey)
                    appState.hotkeyManager.update(keyCode: hotkeyCode, modifiers: hotkeyMods)
                }
                .font(.caption)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            #if DEBUG
                            print("Launch at login error: \(error)")
                            #endif
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            hotkeyCode = appState.hotkeyManager.keyCode
            hotkeyMods = appState.hotkeyManager.modifiers
        }
    }
}

// MARK: - Permissions Tab

struct PermissionsTab: View {
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false
    @State private var timer: Timer?

    var body: some View {
        Form {
            Section("Required Permissions") {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required for voice recording",
                    granted: hasMicrophone
                ) {
                    PermissionManager.requestMicrophoneAccess { granted in
                        Task { @MainActor in hasMicrophone = granted }
                    }
                }

                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required to paste text into other apps",
                    granted: hasAccessibility
                ) {
                    DispatchQueue.global().async { PermissionManager.requestAccessibilityAccess() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }

            Section {
                Text("Permissions refresh automatically every 2 seconds after granting in System Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            refresh()
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in refresh() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private func refresh() {
        hasMicrophone = PermissionManager.hasMicrophoneAccess()
        hasAccessibility = PermissionManager.hasAccessibilityAccess()
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Vowrite")
                .font(.title)
                .bold()
            Text("AI Voice Keyboard")
                .foregroundColor(.secondary)
            Text("v\(AppVersion.current)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Speak naturally, get polished text.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
