import SwiftUI
import AVFoundation
import VowriteKit

struct OnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var currentStep = 0
    @State private var selectedLanguage: SupportedLanguage = .auto
    @State private var micGranted = false
    @State private var selectedPreset: APIPresetOption?
    @State private var apiKey = ""

    private let totalSteps = 4
    private let permissionManager = iOSPermissionManager()

    var body: some View {
        VStack(spacing: 0) {
            progressDots
                .padding(.top, 20)

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                languageStep.tag(1)
                permissionStep.tag(2)
                apiStep.tag(3)
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

            Image(systemName: "mic.badge.plus")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)

            Text("Welcome to Vowrite")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Transform your voice into polished text.\nRecord, transcribe, and refine — all in one tap.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            nextButton("Get Started")
        }
        .padding(.bottom, 40)
    }

    // MARK: - Step 2: Language

    private var languageStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Choose Your Language")
                .font(.title2)
                .fontWeight(.bold)

            Text("Select the language you'll speak most often.\nYou can change this later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            languageList

            Spacer()

            nextButton("Continue") {
                LanguageConfig.globalLanguage = selectedLanguage
            }
        }
        .padding(.bottom, 40)
    }

    private var languageList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(SupportedLanguage.allCases, id: \.rawValue) { lang in
                    LanguageRow(lang: lang, isSelected: selectedLanguage == lang) {
                        selectedLanguage = lang
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Step 3: Permission

    private var permissionStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: micGranted ? "mic.fill" : "mic.slash")
                .font(.system(size: 56))
                .foregroundColor(micGranted ? .green : .accentColor)
                .contentTransition(.symbolEffect(.replace))

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("Vowrite needs microphone access to record your voice for transcription.")
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

    // MARK: - Step 4: API Setup

    private var apiStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("API Configuration")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a preset or configure your own API provider.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            presetList

            apiKeyField

            Spacer()

            doneButton
        }
        .padding(.bottom, 40)
    }

    private var presetList: some View {
        VStack(spacing: 8) {
            ForEach(APIPresetStore.builtInPresets, id: \.id) { preset in
                PresetRow(preset: preset, isSelected: selectedPreset?.id == preset.id) {
                    selectedPreset = preset
                    APIConfig.apply(preset)
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

    private var doneButton: some View {
        Button {
            if let preset = selectedPreset,
               let provider = KeyVault.requiredProviders(for: preset.configuration).first,
               !apiKey.isEmpty {
                _ = KeyVault.saveKey(apiKey, for: provider)
            }
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

// MARK: - Extracted Row Views

private struct LanguageRow: View {
    let lang: SupportedLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(lang.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
    }
}

private struct PresetRow: View {
    let preset: APIPresetOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(14)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
    }
}
