import SwiftUI
import VowriteKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var sttProvider: APIProvider = APIConfig.sttProvider
    @State private var sttModel: String = APIConfig.sttModel
    @State private var polishProvider: APIProvider = APIConfig.polishProvider
    @State private var polishModel: String = APIConfig.polishModel
    @State private var sttAPIKey: String = ""
    @State private var polishAPIKey: String = ""
    @State private var soundFeedbackEnabled: Bool = SoundFeedback.isEnabled

    // Local state for translation pickers — decoupled from modeManager to prevent
    // scroll-position snapping caused by @ObservedObject re-renders during picker interaction.
    @State private var translationSourceLocal: SupportedLanguage = .auto
    @State private var translationTargetLocal: SupportedLanguage = .en

    @ObservedObject private var modeManager = ModeManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // API Preset
                Section("Quick Setup") {
                    ForEach(APIPresetStore.builtInPresets, id: \.id) { preset in
                        Button {
                            APIConfig.apply(preset)
                            syncStateFromConfig()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(preset.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if APIConfig.selectedPresetID == preset.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }

                // STT Configuration
                Section("Speech-to-Text") {
                    Picker("Provider", selection: $sttProvider) {
                        ForEach(APIProvider.availableSTTCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: sttProvider) { _, newValue in
                        sttModel = newValue.defaultSTTModel
                        applyConfig()
                    }

                    Picker("Model", selection: $sttModel) {
                        ForEach(sttProvider.presetSTTModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: sttModel) { _, _ in applyConfig() }

                    if sttProvider.requiresAPIKey {
                        SecureField(sttProvider.keyPlaceholder, text: $sttAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { saveKey(sttAPIKey, for: sttProvider) }
                            .onChange(of: sttAPIKey) { _, newValue in
                                saveKey(newValue, for: sttProvider)
                            }

                        if KeyVault.hasKey(for: sttProvider) {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Polish Configuration
                Section("AI Polish") {
                    Picker("Provider", selection: $polishProvider) {
                        ForEach(APIProvider.availableCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: polishProvider) { _, newValue in
                        polishModel = newValue.defaultPolishModel
                        applyConfig()
                    }

                    Picker("Model", selection: $polishModel) {
                        ForEach(polishProvider.presetPolishModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .onChange(of: polishModel) { _, _ in applyConfig() }

                    if polishProvider.requiresAPIKey && polishProvider != sttProvider {
                        SecureField(polishProvider.keyPlaceholder, text: $polishAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { saveKey(polishAPIKey, for: polishProvider) }
                            .onChange(of: polishAPIKey) { _, newValue in
                                saveKey(newValue, for: polishProvider)
                            }

                        if KeyVault.hasKey(for: polishProvider) {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Feedback
                Section("Feedback") {
                    Toggle("Sound Feedback", isOn: $soundFeedbackEnabled)
                        .onChange(of: soundFeedbackEnabled) { _, newValue in
                            SoundFeedback.isEnabled = newValue
                        }
                }

                // F-066: Translation language quick settings
                Section {
                    Picker("Source", selection: $translationSourceLocal) {
                        ForEach(SupportedLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .onChange(of: translationSourceLocal) { _, newValue in
                        setTranslationSource(newValue)
                    }
                    Picker("Target", selection: $translationTargetLocal) {
                        ForEach(SupportedLanguage.allCases.filter { $0 != .auto }) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .onChange(of: translationTargetLocal) { _, newValue in
                        setTranslationTarget(newValue)
                    }
                } header: {
                    Text("Translation")
                } footer: {
                    Text("Applies to the built-in Translate mode. Custom translation modes keep their own settings.")
                }

                // Local Models (Sherpa offline ASR)
                Section("Local Models") {
                    SherpaLocalModelsList()
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppVersion.current)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { syncStateFromConfig() }
            .onChange(of: modeManager.modes) { _, _ in
                let src = translationSource
                let tgt = translationTarget
                if src != translationSourceLocal { translationSourceLocal = src }
                if tgt != translationTargetLocal { translationTargetLocal = tgt }
            }
        }
    }

    private func syncStateFromConfig() {
        sttProvider = APIConfig.sttProvider
        sttModel = APIConfig.sttModel
        polishProvider = APIConfig.polishProvider
        polishModel = APIConfig.polishModel
        sttAPIKey = ""
        polishAPIKey = ""
        translationSourceLocal = translationSource
        translationTargetLocal = translationTarget
    }

    private func applyConfig() {
        APIConfig.sttProvider = sttProvider
        APIConfig.sttModel = sttModel
        APIConfig.polishProvider = polishProvider
        APIConfig.polishModel = polishModel
        APIConfig.clearSelectedPresetIfNeeded(for: APIConfig.current)
    }

    private func saveKey(_ key: String, for provider: APIProvider) {
        guard !key.isEmpty else { return }
        _ = KeyVault.saveKey(key, for: provider)
    }

    // MARK: - F-066 Translation language bindings

    private var translateModeIndex: Int? {
        modeManager.modes.firstIndex { $0.isBuiltin && $0.isTranslation }
    }

    private var translationSource: SupportedLanguage {
        guard let i = translateModeIndex,
              let raw = modeManager.modes[i].language,
              let lang = SupportedLanguage(rawValue: raw) else { return .auto }
        return lang
    }

    private var translationTarget: SupportedLanguage {
        guard let i = translateModeIndex,
              let raw = modeManager.modes[i].targetLanguage,
              let lang = SupportedLanguage(rawValue: raw),
              lang != .auto else { return .en }
        return lang
    }

    private func setTranslationSource(_ lang: SupportedLanguage) {
        guard let i = translateModeIndex else { return }
        var mode = modeManager.modes[i]
        mode.language = (lang == .auto) ? nil : lang.rawValue
        modeManager.updateMode(mode)
    }

    private func setTranslationTarget(_ lang: SupportedLanguage) {
        guard let i = translateModeIndex, lang != .auto else { return }
        var mode = modeManager.modes[i]
        mode.targetLanguage = lang.rawValue
        modeManager.updateMode(mode)
    }
}
