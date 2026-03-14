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
        case .openai: return "gpt-4o-mini-transcribe"
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
        case .groq: return "llama-3.3-70b-versatile"
        case .together: return "meta-llama/Llama-3.1-8B-Instruct-Turbo"
        case .deepseek: return "deepseek-chat"
        case .custom: return "gpt-4o-mini"
        }
    }

    /// Preset STT models for this provider. Empty means no STT support.
    var presetSTTModels: [String] {
        switch self {
        case .openai: return ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
        case .openrouter: return [] // uses dynamic fetch
        case .groq: return ["whisper-large-v3-turbo", "whisper-large-v3"]
        case .together: return ["whisper-large-v3"]
        case .deepseek: return [] // no STT support
        case .custom: return [] // manual input only
        }
    }

    /// Preset Polish models for this provider. Empty means manual input only.
    var presetPolishModels: [String] {
        switch self {
        case .openai: return ["gpt-4o-mini", "gpt-4o"]
        case .openrouter: return [] // uses dynamic fetch
        case .groq: return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "qwen-qwq-32b"]
        case .together: return ["meta-llama/Llama-3.1-8B-Instruct-Turbo"]
        case .deepseek: return ["deepseek-chat", "deepseek-reasoner"]
        case .custom: return [] // manual input only
        }
    }

    /// Brief description for known STT models
    static func sttModelDescription(_ modelId: String) -> String? {
        switch modelId {
        case "gpt-4o-mini-transcribe": return "Fast & cheap — $0.003/min"
        case "gpt-4o-transcribe": return "Best quality — $0.006/min"
        case "whisper-1": return "Classic — $0.006/min"
        case "whisper-large-v3-turbo": return "Fastest & cheapest — $0.0007/min"
        case "whisper-large-v3": return "High accuracy — $0.002/min"
        default: return nil
        }
    }

    /// Brief description for known Polish models
    static func polishModelDescription(_ modelId: String) -> String? {
        switch modelId {
        case "gpt-4o-mini": return "Best balance — fast & accurate"
        case "gpt-4o": return "Highest quality — slower"
        case "llama-3.3-70b-versatile": return "Fast & free-tier friendly"
        case "llama-3.1-8b-instant": return "Ultra fast — basic quality"
        case "qwen-qwq-32b": return "Strong reasoning — multilingual"
        case "deepseek-chat": return "Best value — $0.28/M input, excellent Chinese"
        case "deepseek-reasoner": return "Deep thinking — complex rewrites"
        default: return nil
        }
    }

    var hasSTTSupport: Bool {
        switch self {
        case .openai, .groq, .together: return true
        case .openrouter, .deepseek, .custom: return false
        }
    }

    var sttSupportNote: String? {
        switch self {
        case .openrouter: return "OpenRouter does not proxy the Whisper API. Enable Dual Provider and use OpenAI/Groq for STT."
        case .deepseek: return "DeepSeek does not offer speech-to-text. Enable Dual Provider and use OpenAI/Groq for STT."
        case .custom: return "Ensure your custom endpoint supports /audio/transcriptions (OpenAI Whisper API compatible)."
        default: return nil
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
                  let p = APIProvider(rawValue: raw) else { return .groq }
            return p
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerKey) }
    }

    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: baseURLKey) ?? APIProvider.groq.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: baseURLKey) }
    }

    static var sttModel: String {
        get { UserDefaults.standard.string(forKey: sttModelKey) ?? "whisper-large-v3-turbo" }
        set { UserDefaults.standard.set(newValue, forKey: sttModelKey) }
    }

    static var polishModel: String {
        get { UserDefaults.standard.string(forKey: polishModelKey) ?? "llama-3.3-70b-versatile" }
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

                // TODO: Re-enable Google sign-in when backend OAuth service is ready
                // Currently only API Key mode is available
                apiKeyModeView

                // Divider()
                // Account Mode picker hidden until Google OAuth backend is ready
                // VStack(alignment: .leading, spacing: 8) { ... }
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
    @State private var customSTTModel: String = ""
    @State private var customPolishModel: String = ""
    @State private var savedFeedback = false
    @State private var testingAPI = false
    @State private var apiTestResult: (success: Bool, message: String)?
    @State private var editLanguage: SupportedLanguage = LanguageConfig.globalLanguage
    @State private var advancedModelMode = false
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
                        HStack {
                            Spacer()
                            Toggle("Advanced", isOn: $advancedModelMode)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .font(.caption)
                        }

                        if editProvider == .openrouter && !editKey.isEmpty {
                            // OpenRouter: dynamic fetch
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
                                    if advancedModelMode {
                                        Divider()
                                        Text("Custom...").tag("__custom_stt__")
                                    }
                                }
                                .onChange(of: editSTTModel) { _, v in
                                    if v == "__custom_stt__" { editSTTModel = customSTTModel }
                                }
                                if advancedModelMode && (editSTTModel == customSTTModel && !customSTTModel.isEmpty || !modelManager.sttModels.contains(where: { $0.id == editSTTModel })) {
                                    TextField("Custom STT Model ID", text: $customSTTModel)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: customSTTModel) { _, v in editSTTModel = v }
                                }
                            } else if advancedModelMode {
                                TextField("STT Model", text: $editSTTModel).textFieldStyle(.roundedBorder)
                            }
                            if !modelManager.polishModels.isEmpty {
                                Picker("Polish Model", selection: $editPolishModel) {
                                    ForEach(modelManager.polishModels) { m in
                                        Text(modelManager.isRecommendedPolishModel(m) ? "⭐ \(m.name)" : m.name).tag(m.id)
                                    }
                                    if advancedModelMode {
                                        Divider()
                                        Text("Custom...").tag("__custom_polish__")
                                    }
                                }
                                .onChange(of: editPolishModel) { _, v in
                                    if v == "__custom_polish__" { editPolishModel = customPolishModel }
                                }
                                if advancedModelMode && (editPolishModel == customPolishModel && !customPolishModel.isEmpty || !modelManager.polishModels.contains(where: { $0.id == editPolishModel })) {
                                    TextField("Custom Polish Model ID", text: $customPolishModel)
                                        .textFieldStyle(.roundedBorder)
                                        .onChange(of: customPolishModel) { _, v in editPolishModel = v }
                                }
                            } else if advancedModelMode {
                                TextField("Polish Model", text: $editPolishModel).textFieldStyle(.roundedBorder)
                            }
                        } else if !editProvider.presetSTTModels.isEmpty || !editProvider.presetPolishModels.isEmpty {
                            // Providers with preset models: Picker only (Advanced enables custom input)
                            if editProvider.hasSTTSupport {
                                presetModelPicker(
                                    label: "STT Model",
                                    selection: $editSTTModel,
                                    presets: editProvider.presetSTTModels,
                                    customText: $customSTTModel,
                                    allowCustom: advancedModelMode
                                )
                            }
                            presetModelPicker(
                                label: "Polish Model",
                                selection: $editPolishModel,
                                presets: editProvider.presetPolishModels,
                                customText: $customPolishModel,
                                allowCustom: advancedModelMode
                            )
                        } else {
                            // Custom provider or DeepSeek (no presets): manual text fields only in Advanced mode
                            if editProvider.hasSTTSupport {
                                if advancedModelMode {
                                    TextField("STT Model", text: $editSTTModel).textFieldStyle(.roundedBorder)
                                } else {
                                    LabeledContent("STT Model") {
                                        Text(editSTTModel).foregroundColor(.secondary)
                                    }
                                    Text("Enable Advanced mode to change model manually.")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            } else {
                                LabeledContent("STT Model") {
                                    Text("Not supported by this provider").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            if advancedModelMode {
                                TextField("Polish Model", text: $editPolishModel).textFieldStyle(.roundedBorder)
                            } else {
                                LabeledContent("Polish Model") {
                                    Text(editPolishModel).foregroundColor(.secondary)
                                }
                                if editProvider.hasSTTSupport {
                                    // hint already shown above
                                } else {
                                    Text("Enable Advanced mode to change model manually.")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }.padding(8)
                }

                HStack {
                    if let result = apiTestResult {
                        Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.success ? .green : .red)
                            .font(.caption)
                    }
                    Spacer()
                    Button {
                        Task { await testAPIConnection() }
                    } label: {
                        HStack(spacing: 4) {
                            if testingAPI { ProgressView().controlSize(.small) }
                            Text("Test Connection")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(editKey.isEmpty || testingAPI)
                    if savedFeedback {
                        Label("Saved!", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                    }
                    Button("Save Configuration") { saveAPI() }.buttonStyle(.borderedProminent)
                }

                // Language
                GroupBox("Language") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Default Language", selection: $editLanguage) {
                            ForEach(SupportedLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .onChange(of: editLanguage) { _, v in LanguageConfig.globalLanguage = v }
                        Text("Language hint for speech recognition. Auto-detect works well for most cases.")
                            .font(.caption).foregroundColor(.secondary)
                    }.padding(8)
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

    @ViewBuilder
    private func presetModelPicker(label: String, selection: Binding<String>, presets: [String], customText: Binding<String>, allowCustom: Bool = false) -> some View {
        let isCustom = !presets.contains(selection.wrappedValue) && !selection.wrappedValue.isEmpty
        Picker(label, selection: selection) {
            ForEach(presets, id: \.self) { model in
                let desc = label.contains("STT")
                    ? APIProvider.sttModelDescription(model)
                    : APIProvider.polishModelDescription(model)
                if let desc = desc {
                    Text("\(model)  ·  \(desc)").tag(model)
                } else {
                    Text(model).tag(model)
                }
            }
            if allowCustom {
                Divider()
                Text("Custom...").tag("__custom__")
            }
        }
        .onChange(of: selection.wrappedValue) { _, v in
            if v == "__custom__" {
                selection.wrappedValue = customText.wrappedValue.isEmpty ? "" : customText.wrappedValue
            }
            // If not in advanced mode and value is not in presets, snap to first preset
            if !allowCustom && !presets.contains(v) && v != "__custom__" && !presets.isEmpty {
                selection.wrappedValue = presets[0]
            }
        }
        if allowCustom && isCustom {
            TextField("Custom Model ID", text: customText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: customText.wrappedValue) { _, v in selection.wrappedValue = v }
        }
    }

    private func testAPIConnection() async {
        testingAPI = true
        apiTestResult = nil
        defer { testingAPI = false }

        let key = editKey
        guard !key.isEmpty else {
            apiTestResult = (false, "No API key provided")
            return
        }

        let baseURL = editBaseURL
        let model = editPolishModel
        let endpoint = "\(baseURL)/chat/completions"

        guard let url = URL(string: endpoint) else {
            apiTestResult = (false, "Invalid base URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        if editProvider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

        let payload: [String: Any] = [
            "model": model,
            "messages": [["role": "user", "content": "Say hi"]],
            "max_tokens": 5
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                apiTestResult = (false, "Invalid response")
                return
            }
            if httpResponse.statusCode == 200 {
                apiTestResult = (true, "Connection successful!")
            } else {
                let body = String(data: data, encoding: .utf8) ?? "Unknown error"
                apiTestResult = (false, "Error \(httpResponse.statusCode): \(body.prefix(100))")
            }
        } catch {
            apiTestResult = (false, error.localizedDescription)
        }
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
    @State private var userPrompt = PromptConfig.userPrompt
    @ObservedObject private var modeManager = ModeManager.shared
    @ObservedObject private var styleManager = OutputStyleManager.shared
    @ObservedObject private var vocabManager = VocabularyManager.shared
    @State private var newWord = ""
    @State private var bulkInput = ""
    @State private var editingMode: Mode?
    @State private var showModeEditor = false
    @State private var editingStyle: OutputStyle?
    @State private var showStyleEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personalization").font(.largeTitle).fontWeight(.bold)

                // Modes
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Modes", systemImage: "square.stack.3d.up").font(.headline)
                            Spacer()
                            Button {
                                let newMode = Mode(
                                    id: UUID(), name: "New Mode", icon: "star",
                                    isBuiltin: false, sttModel: nil, language: nil,
                                    polishEnabled: true, polishModel: nil,
                                    systemPrompt: "", userPrompt: "",
                                    temperature: 0.3, autoPaste: true,
                                    outputStyleId: nil, shortcutIndex: nil
                                )
                                editingMode = newMode
                                showModeEditor = true
                            } label: {
                                Label("New Mode", systemImage: "plus")
                            }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        Text("Select a mode to change how your voice input is processed. Cmd+1-6 shortcuts available.")
                            .font(.caption).foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(modeManager.modes) { mode in
                                ModeCard(mode: mode, isSelected: modeManager.currentModeId == mode.id) {
                                    modeManager.select(mode)
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        editingMode = mode
                                        showModeEditor = true
                                    }
                                    if mode.isBuiltin {
                                        Button("Reset to Default") {
                                            modeManager.resetBuiltinMode(mode)
                                        }
                                    } else {
                                        Button("Delete", role: .destructive) {
                                            modeManager.deleteMode(mode)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding(8)
                }
                .sheet(isPresented: $showModeEditor) {
                    if let mode = editingMode {
                        ModeEditorView(mode: mode, modeManager: modeManager, styleManager: styleManager) {
                            showModeEditor = false
                            editingMode = nil
                        }
                    }
                }

                // Output Styles
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Output Styles", systemImage: "textformat.alt").font(.headline)
                            Spacer()
                            Button {
                                let newStyle = OutputStyle(
                                    id: UUID(), name: "New Style", icon: "star",
                                    description: "", templatePrompt: "",
                                    isBuiltin: false
                                )
                                editingStyle = newStyle
                                showStyleEditor = true
                            } label: {
                                Label("New Style", systemImage: "plus")
                            }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        }
                        Text("Reusable formatting templates that Modes can reference for output styling.")
                            .font(.caption).foregroundColor(.secondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(styleManager.styles) { style in
                                OutputStyleCard(style: style) {
                                    editingStyle = style
                                    showStyleEditor = true
                                }
                                .contextMenu {
                                    Button("Edit") {
                                        editingStyle = style
                                        showStyleEditor = true
                                    }
                                    if style.isBuiltin {
                                        Button("Reset to Default") {
                                            styleManager.resetBuiltinStyle(style)
                                        }
                                    } else {
                                        Button("Delete", role: .destructive) {
                                            styleManager.deleteStyle(style)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding(8)
                }
                .sheet(isPresented: $showStyleEditor) {
                    if let style = editingStyle {
                        OutputStyleEditorView(style: style, styleManager: styleManager) {
                            showStyleEditor = false
                            editingStyle = nil
                        }
                    }
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

                // Personal Dictionary
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Personal Dictionary", systemImage: "character.book.closed").font(.headline)
                        Text("Add custom words, names, or technical terms to improve speech recognition accuracy.")
                            .font(.caption).foregroundColor(.secondary)

                        HStack {
                            TextField("Add a word or phrase", text: $newWord)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    vocabManager.add(newWord)
                                    newWord = ""
                                }
                            Button("Add") {
                                vocabManager.add(newWord)
                                newWord = ""
                            }
                            .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        HStack {
                            TextField("Bulk add (comma-separated)", text: $bulkInput)
                                .textFieldStyle(.roundedBorder)
                            Button("Add All") {
                                vocabManager.addBulk(bulkInput)
                                bulkInput = ""
                            }
                            .disabled(bulkInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }

                        if !vocabManager.words.isEmpty {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
                                    ForEach(vocabManager.words, id: \.self) { word in
                                        HStack(spacing: 4) {
                                            Text(word).font(.caption).lineLimit(1)
                                            Spacer(minLength: 2)
                                            Button {
                                                vocabManager.remove(word)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .frame(maxHeight: 120)

                            HStack {
                                Text("\(vocabManager.words.count) word(s)")
                                    .font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Button("Clear All") {
                                    vocabManager.words.removeAll()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    }.padding(8)
                }
            }.padding(30)
        }
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: Mode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: mode.icon).font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                Text(mode.name).font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)
                if let idx = mode.shortcutIndex {
                    Text("Cmd+\(idx)").font(.system(size: 9))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
                if !mode.polishEnabled {
                    Text("No AI").font(.system(size: 9))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .orange)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode Editor

struct ModeEditorView: View {
    @State var mode: Mode
    let modeManager: ModeManager
    @ObservedObject var styleManager: OutputStyleManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            modeEditorHeader
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    modeEditorContent
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
    }

    @ViewBuilder
    private var modeEditorContent: some View {
        modeGeneralSection
        modePolishSection
        modeLanguageSection
        if mode.polishEnabled { modePromptSection }
        modeBehaviorSection
    }

    private var modeEditorHeader: some View {
        HStack {
            Text(modeManager.modes.contains(where: { $0.id == mode.id }) ? "Edit Mode" : "New Mode")
                .font(.headline)
            Spacer()
            Button("Cancel") { onDismiss() }.keyboardShortcut(.cancelAction)
            Button("Save") { saveMode() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var modeGeneralSection: some View {
        let icons = [
            "mic.fill", "sparkles", "envelope", "bubble.left", "note.text",
            "chevron.left.forwardslash.chevron.right", "star", "doc.text",
            "person.fill", "briefcase", "book", "pencil", "megaphone",
            "graduationcap", "heart", "lightbulb", "hammer", "globe"
        ]
        return GroupBox("General") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Mode Name", text: $mode.name)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Icon").foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button { mode.icon = icon } label: {
                                    Image(systemName: icon)
                                        .frame(width: 28, height: 28)
                                        .background(mode.icon == icon ? Color.accentColor : Color.secondary.opacity(0.1))
                                        .foregroundColor(mode.icon == icon ? .white : .primary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(8)
        }
    }

    private var modePolishSection: some View {
        GroupBox("AI Polish") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Enable AI Polish", isOn: $mode.polishEnabled)
                if mode.polishEnabled {
                    TextField("Polish Model (empty = global default)", text: Binding(
                        get: { mode.polishModel ?? "" },
                        set: { mode.polishModel = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    HStack {
                        Text("Temperature")
                        Slider(value: $mode.temperature, in: 0...1, step: 0.1)
                        Text(String(format: "%.1f", mode.temperature))
                            .font(.caption).foregroundColor(.secondary).frame(width: 30)
                    }
                    Picker("Output Style", selection: modeOutputStyleSelection) {
                        Text("None").tag(nil as UUID?)
                        ForEach(styleManager.styles.filter { $0.id != OutputStyle.noneId }) { style in
                            Label(style.name, systemImage: style.icon).tag(style.id as UUID?)
                        }
                    }
                    if let styleId = mode.outputStyleId,
                       let style = styleManager.styles.first(where: { $0.id == styleId }),
                       !style.description.isEmpty {
                        Text(style.description)
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
            }.padding(8)
        }
    }

    private var modeOutputStyleSelection: Binding<UUID?> {
        Binding(
            get: { mode.outputStyleId },
            set: { mode.outputStyleId = $0 }
        )
    }

    private var modeLanguageSection: some View {
        GroupBox("Language") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Language Override", selection: modeLanguageSelection) {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Text(lang == .auto ? "Use Global Default" : lang.displayName).tag(lang)
                    }
                }
                TextField("STT Model (empty = global default)", text: Binding(
                    get: { mode.sttModel ?? "" },
                    set: { mode.sttModel = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
            .padding(8)
        }
    }

    private var modeLanguageSelection: Binding<SupportedLanguage> {
        Binding(
            get: {
                if let raw = mode.language, let lang = SupportedLanguage(rawValue: raw) { return lang }
                return .auto
            },
            set: { newValue in
                mode.language = (newValue == .auto) ? nil : newValue.rawValue
            }
        )
    }

    private var modePromptSection: some View {
        GroupBox("Mode Prompt") {
            VStack(alignment: .leading, spacing: 8) {
                Text("System prompt appended when this mode is active:")
                    .font(.caption).foregroundColor(.secondary)
                TextEditor(text: $mode.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 100)
                    .border(Color.secondary.opacity(0.3))
                Text("User prompt for this mode:")
                    .font(.caption).foregroundColor(.secondary)
                TextEditor(text: $mode.userPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.3))
            }.padding(8)
        }
    }

    private var modeBehaviorSection: some View {
        GroupBox("Behavior") {
            Toggle("Auto-paste result", isOn: $mode.autoPaste)
                .padding(8)
        }
    }

    private func saveMode() {
        if modeManager.modes.contains(where: { $0.id == mode.id }) {
            modeManager.updateMode(mode)
        } else {
            modeManager.addMode(mode)
        }
        onDismiss()
    }
}

// MARK: - Output Style Card

struct OutputStyleCard: View {
    let style: OutputStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: style.icon).font(.title2)
                    .foregroundColor(.accentColor)
                Text(style.name).font(.caption)
                    .foregroundColor(.primary)
                if !style.isBuiltin {
                    Text("Custom").font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Output Style Editor

struct OutputStyleEditorView: View {
    @State var style: OutputStyle
    let styleManager: OutputStyleManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(styleManager.styles.contains(where: { $0.id == style.id }) ? "Edit Output Style" : "New Output Style")
                    .font(.headline)
                Spacer()
                Button("Cancel") { onDismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { saveStyle() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            .padding()
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    styleGeneralSection
                    stylePromptSection
                }
                .padding()
            }
        }
        .frame(width: 500, height: 450)
    }

    private var styleGeneralSection: some View {
        let icons = [
            "minus.circle", "list.bullet", "list.number", "envelope.open",
            "person.3", "bubble.left.and.bubble.right", "doc.text.magnifyingglass",
            "star", "doc.text", "pencil", "megaphone", "lightbulb",
            "text.alignleft", "text.justify", "rectangle.and.pencil.and.ellipsis",
            "checklist", "quote.opening", "terminal"
        ]
        return GroupBox("General") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Style Name", text: $style.name)
                    .textFieldStyle(.roundedBorder)
                TextField("Description", text: $style.description)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Icon").foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button { style.icon = icon } label: {
                                    Image(systemName: icon)
                                        .frame(width: 28, height: 28)
                                        .background(style.icon == icon ? Color.accentColor : Color.secondary.opacity(0.1))
                                        .foregroundColor(style.icon == icon ? .white : .primary)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }.padding(8)
        }
    }

    private var stylePromptSection: some View {
        GroupBox("Template Prompt") {
            VStack(alignment: .leading, spacing: 8) {
                Text("This prompt is appended to the system prompt when a Mode uses this style:")
                    .font(.caption).foregroundColor(.secondary)
                TextEditor(text: $style.templatePrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .border(Color.secondary.opacity(0.3))
            }.padding(8)
        }
    }

    private func saveStyle() {
        if styleManager.styles.contains(where: { $0.id == style.id }) {
            styleManager.updateStyle(style)
        } else {
            styleManager.addStyle(style)
        }
        onDismiss()
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
