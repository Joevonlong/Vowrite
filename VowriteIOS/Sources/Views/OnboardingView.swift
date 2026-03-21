import SwiftUI
import AVFoundation
import VowriteKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var selectedPreset: APIPresetOption?
    @State private var apiKey = ""

    private let totalSteps = 6
    private let permissionManager = iOSPermissionManager()

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 20)

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                addKeyboardStep.tag(1)
                fullAccessStep.tag(2)
                apiStep.tag(3)
                microphoneStep.tag(4)
                doneStep.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
        }
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)

            Text("Vowrite")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your intelligent voice keyboard.\nSpeak in any app, text appears instantly.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            nextButton("Get Started")
        }
        .padding(.bottom, 40)
    }

    // MARK: - Step 2: Add Keyboard

    private var addKeyboardStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "plus.rectangle.on.rectangle")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Add Vowrite Keyboard")
                .font(.title2)
                .fontWeight(.bold)

            KeyboardSetupGuide(step: .addKeyboard)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()

            nextButton("I've Added It")
        }
        .padding(.bottom, 40)
    }

    // MARK: - Step 3: Full Access

    private var fullAccessStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.open.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Enable Full Access")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 8) {
                Label("Microphone access for voice recording", systemImage: "mic.fill")
                Label("Network access for STT & AI processing", systemImage: "globe")
                Label("Vowrite never collects typing data", systemImage: "lock.shield.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 40)

            Button("Open Keyboard Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()

            nextButton("I've Enabled It")
        }
        .padding(.bottom, 40)
    }

    // MARK: - Step 4: API Configuration

    private var apiStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("API Configuration")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a preset and enter your API key.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            presetList

            apiKeyField

            Spacer()

            nextButton("Continue") {
                if let preset = selectedPreset,
                   let provider = KeyVault.requiredProviders(for: preset.configuration).first,
                   !apiKey.isEmpty {
                    _ = KeyVault.saveKey(apiKey, for: provider)
                }
            }
        }
        .padding(.bottom, 40)
    }

    private var presetList: some View {
        VStack(spacing: 8) {
            ForEach(APIPresetStore.builtInPresets, id: \.id) { preset in
                Button {
                    selectedPreset = preset
                    APIConfig.apply(preset)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            Text(preset.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedPreset?.id == preset.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(14)
                    .background(
                        selectedPreset?.id == preset.id ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var apiKeyField: some View {
        if let preset = selectedPreset {
            let providers = KeyVault.requiredProviders(for: preset.configuration)
            if let provider = providers.first, provider.requiresAPIKey {
                SecureField(provider.keyPlaceholder, text: $apiKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 24)
                    .onSubmit {
                        if !apiKey.isEmpty {
                            _ = KeyVault.saveKey(apiKey, for: provider)
                        }
                    }
            }
        }
    }

    // MARK: - Step 5: Microphone

    private var microphoneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: micGranted ? "mic.fill" : "mic.slash")
                .font(.system(size: 56))
                .foregroundColor(micGranted ? .green : .accentColor)
                .contentTransition(.symbolEffect(.replace))

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("The keyboard will also request microphone permission on first use.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if micGranted {
                Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Button("Allow Microphone Access") {
                    Task {
                        micGranted = await permissionManager.requestMicrophoneAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()

            nextButton("Continue")
        }
        .padding(.bottom, 40)
        .onAppear {
            micGranted = permissionManager.hasMicrophoneAccess()
        }
    }

    // MARK: - Step 6: Done

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)

            Text("All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Switch to Vowrite keyboard in any app and start speaking.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onComplete()
            } label: {
                Text("Start Using Vowrite")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private func nextButton(_ title: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
            withAnimation {
                currentStep += 1
            }
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 24)
    }
}
