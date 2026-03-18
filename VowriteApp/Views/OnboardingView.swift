import SwiftUI

/// F-017: First-launch onboarding wizard
struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var selectedLanguage: SupportedLanguage = .auto
    @State private var selectedPresetID = BuiltInAPIPreset.recommended.id
    @State private var onboardingConfig = BuiltInAPIPreset.recommended.configuration
    @State private var keyInputs: [APIProvider: String] = [:]
    @State private var testResult: (success: Bool, message: String)?
    @State private var testing = false
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false
    @State private var testRecordingState: TestRecordingState = .idle

    let onComplete: () -> Void

    private let totalSteps = 6 // 0..5

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .padding(.bottom, 8)

            // Scrollable content area
            ScrollView {
                Group {
                    switch currentStep {
                    case 0: welcomeStep
                    case 1: languageStep
                    case 2: permissionsStep
                    case 3: apiSetupStep
                    case 4: testStep
                    case 5: doneStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)
                .padding(.vertical, 24)
            }

            Divider()

            // Navigation buttons — always visible at bottom
            navigationBar
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
        }
        .frame(width: 600, height: 520)
        .onAppear {
            selectedLanguage = LanguageConfig.globalLanguage
            hasMicrophone = PermissionManager.hasMicrophoneAccess()
            hasAccessibility = PermissionManager.hasAccessibilityAccess()
            keyInputs = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, "") })
        }
    }

    // MARK: - Can Proceed

    private var canProceed: Bool {
        switch currentStep {
        case 3: return missingProviders.isEmpty
        default: return true
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if currentStep > 0 && currentStep < 5 {
                Button("Back") { withAnimation(.easeInOut(duration: 0.25)) { currentStep -= 1 } }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if currentStep == 3 {
                // Allow skipping API setup
                Button("Skip for now") {
                    withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
            }
            if currentStep < 5 {
                Button(nextButtonLabel) {
                    advanceStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            }
        }
    }

    private var nextButtonLabel: String {
        switch currentStep {
        case 0: return "Get Started"
        case 4: return "Finish"
        default: return "Next"
        }
    }

    private func advanceStep() {
        // Save settings on step transitions
        switch currentStep {
        case 1:
            LanguageConfig.globalLanguage = selectedLanguage
        case 3:
            saveAPIConfig()
        default:
            break
        }
        withAnimation(.easeInOut(duration: 0.25)) { currentStep += 1 }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("Welcome to Vowrite")
                .font(.system(size: 28, weight: .bold))
            Text("Say it once. Mean it perfectly.")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Let's get you set up in just a few steps.")
                .foregroundColor(.secondary)
            Spacer().frame(height: 40)
        }
    }

    // MARK: - Step 1: Language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your language")
                .font(.title2.bold())
            Text("This sets the default language for speech recognition. You can always change it later.")
                .foregroundColor(.secondary)

            // Grouped popular + all languages for compact display
            VStack(alignment: .leading, spacing: 12) {
                // Quick pick: popular languages
                let popular: [SupportedLanguage] = [.auto, .en, .zhHans, .de, .ja, .fr, .es]
                ForEach(popular) { lang in
                    languageRow(lang)
                }

                Divider()
                    .padding(.vertical, 4)

                DisclosureGroup("More languages") {
                    let others = SupportedLanguage.allCases.filter { !popular.contains($0) }
                    ForEach(others) { lang in
                        languageRow(lang)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
    }

    private func languageRow(_ lang: SupportedLanguage) -> some View {
        HStack {
            Text(lang.displayName)
                .foregroundColor(.primary)
            Spacer()
            if selectedLanguage == lang {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedLanguage == lang ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            selectedLanguage = lang
        }
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Grant permissions")
                .font(.title2.bold())
            Text("Vowrite needs these to work properly. You can grant them now or later in System Settings.")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required — to record your voice",
                    granted: hasMicrophone
                ) {
                    PermissionManager.requestMicrophoneAccess { g in
                        Task { @MainActor in hasMicrophone = g }
                    }
                }

                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Recommended — to paste text into other apps",
                    granted: hasAccessibility
                ) {
                    DispatchQueue.global().async { PermissionManager.requestAccessibilityAccess() }
                    // Poll for changes
                    Task {
                        for _ in 0..<30 {
                            try? await Task.sleep(for: .seconds(1))
                            let granted = PermissionManager.hasAccessibilityAccess()
                            await MainActor.run { hasAccessibility = granted }
                            if granted { break }
                        }
                    }
                }
            }

            if !hasMicrophone {
                Text("⚠️ Microphone access is required for voice input to work.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 36)
                .foregroundColor(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).fontWeight(.medium)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    // MARK: - Step 3: API Setup

    private var apiSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect to AI")
                .font(.title2.bold())
            Text("Choose a preset, then save the provider keys it needs in macOS Keychain.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(APIPresetStore.builtInPresets) { preset in
                    Button {
                        selectedPresetID = preset.id
                        onboardingConfig = preset.configuration
                        testResult = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedPresetID == preset.id ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedPresetID == preset.id ? .accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .foregroundColor(.primary)
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPresetID == preset.id ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("STT") {
                        Text("\(onboardingConfig.stt.provider.rawValue) · \(onboardingConfig.stt.model)")
                            .foregroundColor(.secondary)
                    }
                    LabeledContent("Polish") {
                        Text("\(onboardingConfig.polish.provider.rawValue) · \(onboardingConfig.polish.model)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            if requiredProviders.isEmpty {
                Text("This preset does not need API keys. Make sure the local service is running before you continue.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(requiredProviders) { provider in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(provider.rawValue)
                                .font(.body.weight(.medium))
                            Spacer()
                            if KeyVault.hasKey(for: provider) {
                                Label("Saved", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }

                        SecureField(provider.keyPlaceholder, text: keyBinding(for: provider))
                            .textFieldStyle(.roundedBorder)

                        if !provider.keyURL.isEmpty {
                            Link("Get your \(provider.rawValue) API key →", destination: URL(string: provider.keyURL)!)
                                .font(.caption)
                        }
                    }
                }

                Text("Keys are stored securely in macOS Keychain and reused anywhere this provider is selected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Test button
            HStack {
                if let result = testResult {
                    Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                        .font(.caption)
                }
                Spacer()
                Button {
                    saveAndTest()
                } label: {
                    HStack(spacing: 4) {
                        if testing { ProgressView().controlSize(.small) }
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!missingProviders.isEmpty || testing)
            }
        }
    }

    private func saveAPIConfig() {
        APIConfig.apply(onboardingConfig, presetID: selectedPresetID)
        for provider in requiredProviders {
            let key = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                _ = KeyVault.saveKey(key, for: provider)
                keyInputs[provider] = ""
            }
        }
        AuthManager.shared.setAuthMode(.apiKey)
    }

    private func saveAndTest() {
        saveAPIConfig()

        // Test connection
        testing = true
        testResult = nil
        Task {
            do {
                try await APIConnectionTester.testChatCompletion(configuration: onboardingConfig.polish)
                await MainActor.run {
                    let presetName = APIPresetStore.preset(for: selectedPresetID)?.name ?? "preset"
                    testResult = (true, "Connected using \(presetName)!")
                    testing = false
                }
            } catch {
                await MainActor.run {
                    testResult = (false, error.localizedDescription)
                    testing = false
                }
            }
        }
    }

    private var requiredProviders: [APIProvider] {
        KeyVault.requiredProviders(for: onboardingConfig)
    }

    private var missingProviders: [APIProvider] {
        requiredProviders.filter { provider in
            if KeyVault.hasKey(for: provider) { return false }
            let input = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return input.isEmpty
        }
    }

    private func keyBinding(for provider: APIProvider) -> Binding<String> {
        Binding(
            get: { keyInputs[provider] ?? "" },
            set: { keyInputs[provider] = $0 }
        )
    }

    // MARK: - Step 4: Test Recording

    enum TestRecordingState {
        case idle, recording, processing, done(String)
    }

    private var testStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 20)
            Text("Try it out!")
                .font(.title2.bold())
            Text("Test your setup by recording a short phrase.")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                switch testRecordingState {
                case .idle:
                    Text("Press ⌥ Space (Option + Space) to record")
                        .foregroundColor(.secondary)

                case .recording:
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Recording…")
                    }

                case .processing:
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Processing…")
                    }

                case .done(let text):
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.green)
                        Text(text)
                            .padding(12)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical, 16)

            Text("This step is optional — you can always test later.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer().frame(height: 20)
        }
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("You're all set!")
                .font(.system(size: 28, weight: .bold))
            Text("Press ⌥ Space anywhere to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Get Started") {
                OnboardingManager.markComplete()
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer().frame(height: 40)
        }
    }
}

// MARK: - Onboarding State Manager

enum OnboardingManager {
    private static let completedKey = "onboardingCompleted"

    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: completedKey)
    }

    static func markComplete() {
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    static func reset() {
        UserDefaults.standard.set(false, forKey: completedKey)
    }
}
