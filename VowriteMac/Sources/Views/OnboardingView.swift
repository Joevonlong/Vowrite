import VowriteKit
import SwiftUI

/// F-017: First-launch onboarding wizard
struct OnboardingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var currentStep = 0
    @State private var selectedLanguage: SupportedLanguage = .auto
    @State private var selectedPresetID = BuiltInAPIPreset.recommended.id
    @State private var onboardingConfig = BuiltInAPIPreset.recommended.configuration
    @State private var keyInputs: [APIProvider: String] = [:]
    @State private var keyEditorExpanded: [APIProvider: Bool] = [:]
    @State private var testResult: (success: Bool, message: String)?
    @State private var testing = false
    @State private var keychainSaveFailed = false
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false
    @State private var testRecordingState: TestRecordingState = .idle

    let onComplete: () -> Void

    private let totalSteps = 6 // 0..5

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "waveform").foregroundStyle(VW.Colors.Action.primary)
                Text("Vowrite").font(.title3.weight(.semibold))
                Spacer()
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.callout).foregroundStyle(VW.Colors.Text.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.top, 24)

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
                .controlSize(.large)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
        }
        .frame(width: 640, height: 600)
        .background(VW.Colors.Surface.canvas)
        .foregroundStyle(VW.Colors.Text.primary)
        .tint(VW.Colors.Action.primary)
        .preferredColorScheme((AppearanceMode(rawValue: appearanceMode) ?? .system).colorScheme)
        .onAppear {
            selectedLanguage = LanguageConfig.globalLanguage
            hasMicrophone = MacPermissionManager.hasMicrophoneAccess()
            hasAccessibility = MacPermissionManager.hasAccessibilityAccess()
            keyInputs = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, "") })
            keyEditorExpanded = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, false) })
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
                Button("Back") { withAnimation(reduceMotion ? nil : VW.Anim.easeNavigation) { currentStep -= 1 } }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if currentStep == 3 {
                // Allow skipping API setup
                Button("Skip for now") {
                    withAnimation(reduceMotion ? nil : VW.Anim.easeNavigation) { currentStep += 1 }
                }
                .buttonStyle(.bordered)
                .foregroundStyle(VW.Colors.Text.secondary)
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
        withAnimation(reduceMotion ? nil : VW.Anim.easeNavigation) { currentStep += 1 }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= currentStep ? VW.Colors.Action.primary : VW.Colors.Border.standard)
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundStyle(VW.Colors.Action.primary)
            Text("Your voice. Your words.")
                .font(.system(size: 32, weight: .semibold))
            Text("Speak naturally. Write beautifully.")
                .font(.title3)
                .foregroundStyle(VW.Colors.Text.secondary)
            Text("Let's get you set up in just a few steps.")
                .foregroundStyle(VW.Colors.Text.secondary)
            Spacer().frame(height: 40)
        }
    }

    // MARK: - Step 1: Language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your language")
                .font(.title2.bold())
            Text("This sets the default language for speech recognition. You can always change it later.")
                .foregroundStyle(VW.Colors.Text.secondary)

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
                    // F-079: family roots only — region variants (zh-TW, en-GB, ...)
                    // are chosen later in Settings, not during onboarding.
                    let others = SupportedLanguage.familyRoots.filter { !popular.contains($0) }
                    ForEach(others) { lang in
                        languageRow(lang)
                    }
                }
                .foregroundStyle(VW.Colors.Text.secondary)
            }
        }
    }

    private func languageRow(_ lang: SupportedLanguage) -> some View {
        Button {
            selectedLanguage = lang
        } label: {
            HStack {
                Text(lang.displayName)
                    .foregroundColor(.primary)
                Spacer()
                if selectedLanguage == lang {
                    Image(systemName: "checkmark")
                        .foregroundStyle(VW.Colors.Action.primary)
                        .fontWeight(.semibold)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedLanguage == lang ? VW.Colors.Action.soft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedLanguage == lang ? .isSelected : [])
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Grant permissions")
                .font(.title2.bold())
            Text("Vowrite needs these to work properly. You can grant them now or later in System Settings.")
                .foregroundStyle(VW.Colors.Text.secondary)

            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required — to record your voice",
                    granted: hasMicrophone
                ) {
                    MacPermissionManager.requestMicrophoneAccess { g in
                        Task { @MainActor in hasMicrophone = g }
                    }
                }

                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Recommended — to paste text into other apps",
                    granted: hasAccessibility
                ) {
                    DispatchQueue.global().async { MacPermissionManager.requestAccessibilityAccess() }
                    // Poll for changes
                    Task {
                        for _ in 0..<30 {
                            try? await Task.sleep(for: .seconds(1))
                            let granted = MacPermissionManager.hasAccessibilityAccess()
                            await MainActor.run { hasAccessibility = granted }
                            if granted { break }
                        }
                    }
                }
            }

            if !hasMicrophone {
                Label("Microphone access is required for voice input.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(VW.Colors.Status.warning)
            }
        }
    }

    private func permissionRow(icon: String, title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 36)
                .foregroundStyle(granted ? VW.Colors.Status.success : VW.Colors.Status.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).fontWeight(.medium)
                Text(description).font(.caption).foregroundStyle(VW.Colors.Text.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(VW.Colors.Status.success)
                    .font(.caption)
            } else {
                Button("Grant") { action() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(VW.Colors.Surface.panel)
        .cornerRadius(VW.Radius.panel)
    }

    // MARK: - Step 3: API Setup

    private var apiSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect to AI")
                .font(.title2.bold())
            Text("Choose a preset, then save the provider keys it needs in macOS Keychain.")
                .foregroundStyle(VW.Colors.Text.secondary)

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
                                Text(presetDisplayName(for: preset))
                                    .foregroundColor(.primary)
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundStyle(VW.Colors.Text.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedPresetID == preset.id ? VW.Colors.Action.soft : VW.Colors.Surface.panel)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("STT") {
                        Text("\(onboardingConfig.stt.provider.rawValue) · \(onboardingConfig.stt.model)")
                            .foregroundStyle(VW.Colors.Text.secondary)
                    }
                    LabeledContent("Polish") {
                        Text("\(onboardingConfig.polish.provider.rawValue) · \(onboardingConfig.polish.model)")
                            .foregroundStyle(VW.Colors.Text.secondary)
                    }
                }
                .padding(8)
            }

            if requiredProviders.isEmpty {
                Text("This preset does not need API keys. Make sure the local service is running before you continue.")
                    .font(.caption)
                    .foregroundStyle(VW.Colors.Text.secondary)
            } else {
                ForEach(requiredProviders) { provider in
                    VStack(alignment: .leading, spacing: 8) {
                        let hasSavedKey = KeyVault.hasKey(for: provider)

                        HStack {
                            Text(provider.rawValue)
                                .font(.body.weight(.medium))
                            Spacer()

                            if hasSavedKey {
                                Label("Configured", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(VW.Colors.Status.success)

                                if let maskedKey = KeyVault.maskedKey(for: provider) {
                                    Text(maskedKey)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(VW.Colors.Text.secondary)
                                }

                                Button("Edit") {
                                    keyEditorExpanded[provider] = true
                                }
                                .buttonStyle(.borderless)

                                Button("Clear") {
                                    if KeyVault.deleteKey(for: provider) {
                                        keyInputs[provider] = ""
                                        keyEditorExpanded[provider] = false
                                    } else {
                                        Log.settings.error("Failed to delete Keychain key for provider \(provider.rawValue, privacy: .public) during onboarding")
                                        keychainSaveFailed = true
                                    }
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Label("Required", systemImage: "key")
                                    .font(.caption)
                                    .foregroundStyle(VW.Colors.Status.warning)
                            }
                        }

                        if isKeyEditorExpanded(for: provider) {
                            SecureField(provider.keyPlaceholder, text: keyBinding(for: provider))
                                .textFieldStyle(.roundedBorder)
                        }

                        if !provider.keyURL.isEmpty {
                            Link("Get your \(provider.rawValue) API key →", destination: URL(string: provider.keyURL)!)
                                .font(.caption)
                        }
                    }
                }

                Text("Keys are stored securely in macOS Keychain and reused anywhere this provider is selected.")
                    .font(.caption)
                    .foregroundStyle(VW.Colors.Text.secondary)
            }

            // Test button
            HStack {
                if keychainSaveFailed {
                    Label("Couldn't save to Keychain", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(VW.Colors.Status.error)
                        .font(.caption)
                } else if let result = testResult {
                    Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(result.success ? VW.Colors.Status.success : VW.Colors.Status.error)
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
                .foregroundStyle(VW.Colors.Text.secondary)

            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundStyle(VW.Colors.Action.primary)

                switch testRecordingState {
                case .idle:
                    Text("Press ⌥ Space (Option + Space) to record")
                        .foregroundStyle(VW.Colors.Text.secondary)

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
                            .foregroundStyle(VW.Colors.Status.success)
                        Text(text)
                            .padding(12)
                            .background(VW.Colors.Surface.panel)
                            .cornerRadius(VW.Radius.panel)
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.vertical, 16)

            Text("This step is optional — you can always test later.")
                .font(.caption)
                .foregroundStyle(VW.Colors.Text.secondary)
            Spacer().frame(height: 20)
        }
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(VW.Colors.Status.success)
            Text("You're all set!")
                .font(.system(size: 28, weight: .bold))
            Text("Press ⌥ Space anywhere to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundStyle(VW.Colors.Text.secondary)

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

private extension OnboardingView {
    func saveAPIConfig() {
        APIConfig.apply(onboardingConfig, presetID: selectedPresetID)
        var allSucceeded = true
        for provider in requiredProviders {
            let key = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                if KeyVault.saveKey(key, for: provider) {
                    keyInputs[provider] = ""
                    keyEditorExpanded[provider] = false
                } else {
                    allSucceeded = false
                    Log.settings.error("Failed to save Keychain key for provider \(provider.rawValue, privacy: .public) during onboarding")
                }
            }
        }
        keychainSaveFailed = !allSucceeded
        Task { @MainActor in AuthManager.shared.setAuthMode(.apiKey) }
    }

    func saveAndTest() {
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

    var requiredProviders: [APIProvider] {
        KeyVault.requiredProviders(for: onboardingConfig)
    }

    var missingProviders: [APIProvider] {
        requiredProviders.filter { provider in
            if KeyVault.hasKey(for: provider) { return false }
            let input = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return input.isEmpty
        }
    }

    func keyBinding(for provider: APIProvider) -> Binding<String> {
        Binding(
            get: { keyInputs[provider] ?? "" },
            set: { keyInputs[provider] = $0 }
        )
    }

    func presetDisplayName(for preset: APIPresetOption) -> String {
        preset.id == BuiltInAPIPreset.recommended.id ? "⭐ \(preset.name)" : preset.name
    }

    func isKeyEditorExpanded(for provider: APIProvider) -> Bool {
        !KeyVault.hasKey(for: provider) || (keyEditorExpanded[provider] ?? false)
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
