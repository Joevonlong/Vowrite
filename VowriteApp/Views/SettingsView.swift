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

// MARK: - Settings Sidebar Navigation

enum SettingsPage: String, CaseIterable, Identifiable {
    case account = "Account"
    case settings = "Settings"
    case personalization = "Personalization"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .account: return "person.circle"
        case .settings: return "gearshape"
        case .personalization: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}

// MARK: - Settings View (Sidebar Navigation)

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPage: SettingsPage = .account

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedPage) {
                Section {
                    ForEach(SettingsPage.allCases) { page in
                        Label(page.rawValue, systemImage: page.icon)
                            .tag(page)
                    }
                }
                Section {
                    Link(destination: URL(string: "https://vowrite.com")!) {
                        Label("Website", systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://github.com/Joevonlong/Vowrite/releases")!) {
                        Label("Release Notes", systemImage: "doc.text")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            Group {
                switch selectedPage {
                case .account:
                    AccountPage()
                case .settings:
                    SettingsContentPage()
                        .environmentObject(appState)
                case .personalization:
                    PersonalizationPage()
                case .about:
                    AboutPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 750, height: 550)
    }
}

// MARK: - Account Page

struct AccountPage: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var googleClientID: String = GoogleAuthService.clientID ?? ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if authManager.authMode == .googleAccount && authManager.isLoggedIn {
                    loggedInView
                } else if authManager.authMode == .googleAccount {
                    googleSignInView
                } else {
                    apiKeyModeView
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Mode")
                        .font(.headline)
                    Picker("", selection: Binding(
                        get: { authManager.authMode },
                        set: { authManager.setAuthMode($0) }
                    )) {
                        Text("API Key").tag(AuthMode.apiKey)
                        Text("Google Account").tag(AuthMode.googleAccount)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    Text(authManager.authMode == .apiKey
                         ? "Use your own API key to access AI models directly."
                         : "Sign in with Google for a managed experience.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
        }
    }

    private var loggedInView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(authManager.userName ?? "Vowrite User")
                        .font(.title2).fontWeight(.semibold)
                    Text(authManager.userEmail ?? "")
                        .font(.body).foregroundColor(.secondary)
                }
            }
            Divider()
            LabeledContent("Subscription") {
                HStack {
                    Text("Free").foregroundColor(.secondary)
                    Button("Upgrade") {}.buttonStyle(.borderedProminent).controlSize(.small).disabled(true)
                }
            }
            Spacer(minLength: 20)
            HStack { Spacer(); Button("Sign Out") { authManager.signOut() } }
        }
    }

    private var googleSignInView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in to Vowrite").font(.title2).fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 4) {
                Text("Google OAuth Client ID").font(.caption).foregroundColor(.secondary)
                TextField("Enter your Google OAuth Client ID", text: $googleClientID)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: googleClientID) { _, v in GoogleAuthService.clientID = v }
                Text("Redirect URI: \(GoogleAuthService.redirectURI)")
                    .font(.caption2).foregroundColor(.secondary).textSelection(.enabled)
            }
            Button {
                authManager.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Sign in with Google").fontWeight(.medium)
                }
                .frame(width: 240, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(googleClientID.isEmpty || authManager.isAuthenticating)

            if authManager.isAuthenticating {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Signing in...").foregroundColor(.secondary) }
            }
            if let error = authManager.authError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
    }

    private var apiKeyModeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "key.fill").font(.system(size: 36)).foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key Mode").font(.title2).fontWeight(.semibold)
                    Text("You are using your own API key. Configure it in Settings.")
                        .font(.body).foregroundColor(.secondary)
                }
            }
            if let key = KeychainHelper.getAPIKey(), !key.isEmpty {
                LabeledContent("Current Key") {
                    Text(maskKey(key)).font(.system(.body, design: .monospaced)).foregroundColor(.secondary)
                }
                LabeledContent("Provider") { Text(APIConfig.provider.rawValue).foregroundColor(.secondary) }
            } else {
                Text("No API key configured. Go to Settings to set one up.").foregroundColor(.orange)
            }
        }
    }

    private func maskKey(_ key: String) -> String {
        guard key.count > 8 else { return "••••••••" }
        return "\(key.prefix(4))••••\(key.suffix(4))"
    }
}

// MARK: - Settings Content Page (API + Models + Hotkey + Permissions)

struct SettingsContentPage: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var modelManager = ModelManager.shared
    @State private var editProvider: APIProvider = APIConfig.provider
    @State private var editKey: String = ""
    @State private var editBaseURL: String = APIConfig.baseURL
    @State private var editSTTModel: String = APIConfig.sttModel
    @State private var editPolishModel: String = APIConfig.polishModel
    @State private var savedFeedback = false
    @State private var hotkeyCode: UInt32 = UInt32(kVK_Space)
    @State private var hotkeyMods: UInt32 = UInt32(optionKey)
    @State private var launchAtLogin = false
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false
    @State private var permTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings").font(.largeTitle).fontWeight(.bold)

                // API Configuration
                GroupBox("API Configuration") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Provider", selection: $editProvider) {
                            ForEach(APIProvider.allCases) { p in Text(p.rawValue).tag(p) }
                        }
                        .onChange(of: editProvider) { _, v in
                            editBaseURL = v.defaultBaseURL
                            editSTTModel = v.defaultSTTModel
                            editPolishModel = v.defaultPolishModel
                        }
                        if editProvider == .custom {
                            TextField("Base URL", text: $editBaseURL).textFieldStyle(.roundedBorder)
                        } else {
                            LabeledContent("Base URL") {
                                Text(editBaseURL).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                        }
                        SecureField(editProvider.keyPlaceholder, text: $editKey).textFieldStyle(.roundedBorder)
                        if !editProvider.keyURL.isEmpty {
                            Link("Get API Key →", destination: URL(string: editProvider.keyURL)!).font(.caption)
                        }
                    }.padding(8)
                }

                // Models
                GroupBox("Models") {
                    VStack(alignment: .leading, spacing: 12) {
                        if editProvider == .openrouter && !editKey.isEmpty {
                            HStack {
                                Button {
                                    Task { await modelManager.refreshModels() }
                                } label: {
                                    HStack(spacing: 4) {
                                        if modelManager.isLoading { ProgressView().controlSize(.small) }
                                        Text(modelManager.isLoading ? "Loading..." : "Refresh Models")
                                    }
                                }.disabled(modelManager.isLoading)
                                if let e = modelManager.error { Text(e).font(.caption).foregroundColor(.red) }
                            }
                            if !modelManager.sttModels.isEmpty {
                                Picker("STT Model", selection: $editSTTModel) {
                                    ForEach(modelManager.sttModels) { m in
                                        Text(modelManager.isRecommendedSTTModel(m) ? "⭐ \(m.name)" : m.name).tag(m.id)
                                    }
                                }
                            } else {
                                TextField("STT Model", text: $editSTTModel).textFieldStyle(.roundedBorder)
                            }
                            if !modelManager.polishModels.isEmpty {
                                Picker("Polish Model", selection: $editPolishModel) {
                                    ForEach(modelManager.polishModels) { m in
                                        Text(modelManager.isRecommendedPolishModel(m) ? "⭐ \(m.name)" : m.name).tag(m.id)
                                    }
                                }
                            } else {
                                TextField("Polish Model", text: $editPolishModel).textFieldStyle(.roundedBorder)
                            }
                        } else {
                            TextField("STT Model", text: $editSTTModel).textFieldStyle(.roundedBorder)
                            TextField("Polish Model", text: $editPolishModel).textFieldStyle(.roundedBorder)
                        }
                    }.padding(8)
                }

                HStack {
                    Spacer()
                    if savedFeedback {
                        Label("Saved!", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    }
                    Button("Save Configuration") { saveAPI() }.buttonStyle(.borderedProminent)
                }

                Divider()

                // Hotkey
                GroupBox("Recording Hotkey") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Toggle recording")
                            Spacer()
                            HotkeyRecorderButton(currentKeyCode: hotkeyCode, currentModifiers: hotkeyMods) { code, mods in
                                hotkeyCode = code; hotkeyMods = mods
                                appState.hotkeyManager.update(keyCode: code, modifiers: mods)
                            }
                        }
                        Text("Click the box, then press your desired modifier + key combination.")
                            .font(.caption).foregroundColor(.secondary)
                        Button("Reset to Default (⌥Space)") {
                            hotkeyCode = UInt32(kVK_Space); hotkeyMods = UInt32(optionKey)
                            appState.hotkeyManager.update(keyCode: hotkeyCode, modifiers: hotkeyMods)
                        }.font(.caption)
                    }.padding(8)
                }

                GroupBox("Startup") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, v in
                            do {
                                if v { try SMAppService.mainApp.register() }
                                else { try SMAppService.mainApp.unregister() }
                            } catch { }
                        }.padding(8)
                }

                GroupBox("Permissions") {
                    VStack(spacing: 8) {
                        PermissionRow(icon: "mic.fill", title: "Microphone", description: "Required for voice recording", granted: hasMicrophone) {
                            PermissionManager.requestMicrophoneAccess { g in Task { @MainActor in hasMicrophone = g } }
                        }
                        PermissionRow(icon: "hand.raised.fill", title: "Accessibility", description: "Required to paste text into other apps", granted: hasAccessibility) {
                            DispatchQueue.global().async { PermissionManager.requestAccessibilityAccess() }
                        }
                    }.padding(8)
                }
            }.padding(30)
        }
        .onAppear {
            editProvider = APIConfig.provider; editKey = KeychainHelper.getAPIKey() ?? ""
            editBaseURL = APIConfig.baseURL; editSTTModel = APIConfig.sttModel; editPolishModel = APIConfig.polishModel
            hotkeyCode = appState.hotkeyManager.keyCode; hotkeyMods = appState.hotkeyManager.modifiers
            hasMicrophone = PermissionManager.hasMicrophoneAccess(); hasAccessibility = PermissionManager.hasAccessibilityAccess()
            permTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
                Task { @MainActor in
                    hasMicrophone = PermissionManager.hasMicrophoneAccess()
                    hasAccessibility = PermissionManager.hasAccessibilityAccess()
                }
            }
        }
        .onDisappear { permTimer?.invalidate() }
    }

    private func saveAPI() {
        APIConfig.provider = editProvider; APIConfig.baseURL = editBaseURL
        APIConfig.sttModel = editSTTModel; APIConfig.polishModel = editPolishModel
        if !editKey.isEmpty { _ = KeychainHelper.saveAPIKey(editKey) }
        savedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedFeedback = false }
    }
}

// MARK: - Personalization Page

struct PersonalizationPage: View {
    @State private var systemPrompt = PromptConfig.systemPrompt
    @State private var userPrompt = PromptConfig.userPrompt
    @ObservedObject private var sceneManager = SceneManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personalization").font(.largeTitle).fontWeight(.bold)

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("System Prompt", systemImage: "cpu").font(.headline)
                            Spacer()
                            Button("Reset to Default") {
                                PromptConfig.resetSystemPrompt(); systemPrompt = PromptConfig.systemPrompt
                            }.font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        Text("⚠️ Modifying the system prompt may affect core behavior.")
                            .font(.caption).foregroundColor(.orange)
                        TextEditor(text: $systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 200)
                            .border(Color.secondary.opacity(0.3))
                            .onChange(of: systemPrompt) { _, v in PromptConfig.systemPrompt = v }
                    }.padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("User Prompt", systemImage: "person.text.rectangle").font(.headline)
                            Spacer()
                            Button("Clear") { userPrompt = ""; PromptConfig.userPrompt = "" }
                                .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        Text("Add personal preferences: \"Technical terms keep English\", \"Use Arabic numerals\", \"Formal business tone\"")
                            .font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $userPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .border(Color.secondary.opacity(0.3))
                            .onChange(of: userPrompt) { _, v in PromptConfig.userPrompt = v }
                    }.padding(8)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Output Scene", systemImage: "theatermasks").font(.headline)
                        Text("Choose a scene to automatically adjust output formatting.")
                            .font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(sceneManager.allScenes) { scene in
                                SceneCard(scene: scene, isSelected: sceneManager.currentSceneId == scene.id) {
                                    sceneManager.select(scene)
                                }
                            }
                        }
                    }.padding(8)
                }
            }.padding(30)
        }
    }
}

// MARK: - Scene Card

struct SceneCard: View {
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
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - About Page

struct AboutPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.circle.fill").font(.system(size: 64)).foregroundColor(.accentColor)
            Text("Vowrite").font(.largeTitle).fontWeight(.bold)
            Text("AI Voice Keyboard").font(.title3).foregroundColor(.secondary)
            Text("v\(AppVersion.current)").font(.body).foregroundColor(.secondary)
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

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.blue).frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundColor(.green).font(.caption)
            } else {
                Button("Grant", action: action).buttonStyle(.bordered)
            }
        }
    }
}
