import SwiftUI

/// F-017: First-launch onboarding wizard
struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var selectedLanguage: SupportedLanguage = .auto
    @State private var editProvider: APIProvider = .openai
    @State private var editKey = ""
    @State private var editBaseURL = APIProvider.openai.defaultBaseURL
    @State private var testResult: (success: Bool, message: String)?
    @State private var testing = false
    @State private var hasMicrophone = false
    @State private var hasAccessibility = false
    @State private var testRecordingState: TestRecordingState = .idle

    let onComplete: () -> Void

    private let steps = ["Welcome", "Language", "Permissions", "API Setup", "Test", "Done"]

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar
                .padding(.horizontal, 40)
                .padding(.top, 24)

            // Content
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)

            // Navigation buttons
            HStack {
                if currentStep > 0 && currentStep < 5 {
                    Button("Back") { withAnimation { currentStep -= 1 } }
                        .buttonStyle(.bordered)
                }
                Spacer()
                if currentStep < 5 {
                    Button(currentStep == 4 ? "Finish" : "Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canProceed)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
        .frame(width: 600, height: 500)
        .onAppear {
            hasMicrophone = PermissionManager.hasMicrophoneAccess()
            hasAccessibility = PermissionManager.hasAccessibilityAccess()
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 3: return !editKey.isEmpty
        default: return true
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<steps.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= currentStep ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
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
        }
    }

    // MARK: - Step 1: Language

    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your language")
                .font(.title2.bold())
            Text("This helps Vowrite recognize your speech more accurately.")
                .foregroundColor(.secondary)

            Picker("Default Language", selection: $selectedLanguage) {
                ForEach(SupportedLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.radioGroup)
            .onChange(of: selectedLanguage) { _, v in
                LanguageConfig.globalLanguage = v
            }

            Text("You can always change this later in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Step 2: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Grant permissions")
                .font(.title2.bold())
            Text("Vowrite needs these to work properly.")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "To record your voice",
                    granted: hasMicrophone
                ) {
                    PermissionManager.requestMicrophoneAccess { g in
                        Task { @MainActor in hasMicrophone = g }
                    }
                }

                permissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "To paste text into other apps",
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
            Text("Choose your AI provider and enter your API key.")
                .foregroundColor(.secondary)

            Picker("Provider", selection: $editProvider) {
                ForEach(APIProvider.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .onChange(of: editProvider) { _, v in
                editBaseURL = v.defaultBaseURL
            }

            SecureField(editProvider.keyPlaceholder, text: $editKey)
                .textFieldStyle(.roundedBorder)

            if !editProvider.keyURL.isEmpty {
                Link("Get your API key →", destination: URL(string: editProvider.keyURL)!)
                    .font(.caption)
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
                        Text("Save & Test")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(editKey.isEmpty || testing)
            }
        }
    }

    private func saveAndTest() {
        // Save config
        APIConfig.provider = editProvider
        APIConfig.baseURL = editBaseURL
        APIConfig.sttModel = editProvider.defaultSTTModel
        APIConfig.polishModel = editProvider.defaultPolishModel
        if !editKey.isEmpty { _ = KeychainHelper.saveAPIKey(editKey) }

        // Test connection
        testing = true
        testResult = nil
        Task {
            do {
                let model = editProvider.defaultPolishModel
                let endpoint = "\(editBaseURL)/chat/completions"
                guard let url = URL(string: endpoint) else {
                    testResult = (false, "Invalid URL")
                    testing = false
                    return
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(editKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 15
                let payload: [String: Any] = [
                    "model": model,
                    "messages": [["role": "user", "content": "Hi"]],
                    "max_tokens": 5
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    testResult = (true, "Connected!")
                } else {
                    testResult = (false, "Connection failed")
                }
            } catch {
                testResult = (false, error.localizedDescription)
            }
            testing = false
        }
    }

    // MARK: - Step 4: Test Recording

    enum TestRecordingState {
        case idle, recording, processing, done(String)
    }

    private var testStep: some View {
        VStack(spacing: 20) {
            Text("Try it out!")
                .font(.title2.bold())
            Text("Say something to test your setup.")
                .foregroundColor(.secondary)

            switch testRecordingState {
            case .idle:
                Button {
                    // Just show a prompt — actual recording happens via the global hotkey
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.accentColor)
                        Text("Press your hotkey (⌥ Space) to record")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

            case .recording:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Recording...")
                }

            case .processing:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Processing...")
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

            Text("You can skip this step if you prefer to test later.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Step 5: Done

    private var doneStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            Text("You're all set!")
                .font(.system(size: 28, weight: .bold))
            Text("Vowrite is ready to use. Press ⌥ Space anywhere to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Get Started") {
                OnboardingManager.markComplete()
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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
