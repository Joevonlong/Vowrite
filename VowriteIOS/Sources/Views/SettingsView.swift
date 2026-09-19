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
    @State private var presetRecovery = APIConfig.pendingPresetRecovery

    // Local state for translation pickers — decoupled from modeManager to prevent
    // scroll-position snapping caused by @ObservedObject re-renders during picker interaction.
    @State private var translationSourceLocal: SupportedLanguage = .auto
    @State private var translationTargetLocal: SupportedLanguage = .en

    @ObservedObject private var modeManager = ModeManager.shared

    /// API key SecureFields save on submit/blur only, not on every keystroke —
    /// persisting a partial key mid-typing/paste to Keychain is wasted work and
    /// briefly stores garbage. Track focus so we can save when the user leaves
    /// the field without hitting return.
    private enum KeyField: Hashable { case stt, polish }
    @FocusState private var focusedKeyField: KeyField?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VWIOSPageHeader(title: "Make Vowrite yours.", subtitle: "Connect your models and fine-tune your input experience.")
                        .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                Section {
                    NavigationLink { modelsPage } label: {
                        settingsDestination("Models", detail: "Speech recognition and AI polish", icon: "cpu")
                    }
                    NavigationLink { connectionsPage } label: {
                        settingsDestination("API Keys", detail: "Connect your own providers", icon: "key")
                    }
                    NavigationLink { generalPage } label: {
                        settingsDestination("Language & Feedback", detail: "Translation and sound preferences", icon: "slider.horizontal.3")
                    }
                }
                Section("About") {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").font(.title2).foregroundStyle(VW.Colors.Action.primary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Vowrite").font(.headline)
                            Text("Say it once. Mean it perfectly.").font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                        }
                        Spacer()
                        Text(AppVersion.current).font(.caption).foregroundStyle(VW.Colors.Text.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .vwIOSForm()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { syncStateFromConfig() }
        .onChange(of: modeManager.modes) { _, _ in
            let src = translationSource
            let tgt = translationTarget
            if src != translationSourceLocal { translationSourceLocal = src }
            if tgt != translationTargetLocal { translationTargetLocal = tgt }
        }
        .onChange(of: focusedKeyField) { oldValue, _ in
            // Save when focus leaves a key field (tab away, dismiss keyboard),
            // not just on submit — covers the common "type then tap elsewhere" path.
            switch oldValue {
            case .stt: saveKey(sttAPIKey, for: sttProvider)
            case .polish: saveKey(polishAPIKey, for: polishProvider)
            case nil: break
            }
        }
        .onDisappear {
            // Backstop: if the view (and its field) disappears while still
            // focused — e.g. the user types a key then immediately
            // backgrounds/switches tabs — the focus-change handler above
            // may not fire in time. Save whatever is currently entered.
            saveKey(sttAPIKey, for: sttProvider)
            saveKey(polishAPIKey, for: polishProvider)
        }
    }

    private func settingsDestination(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(VW.Colors.Action.primary)
                .frame(width: 40, height: 40)
                .background(VW.Colors.Action.soft, in: RoundedRectangle(cornerRadius: VW.Radius.control))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(VW.Colors.Text.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var modelsPage: some View {
        Form {
            // API Preset
            Section("Quick Setup") {
                if let recovery = presetRecovery {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(recovery.name) preset unavailable", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(recovery.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Use Recommended") {
                                let preset = BuiltInAPIPreset.recommended
                                APIConfig.apply(preset.configuration, presetID: preset.id)
                                syncStateFromConfig()
                                presetRecovery = nil
                            }
                            Button("Keep Current") {
                                APIConfig.acknowledgePresetRecoveryKeepingCurrentConfiguration()
                                presetRecovery = nil
                            }
                        }
                        .font(.caption)
                    }
                }

                ForEach(APIPresetStore.builtInPresets, id: \.id) { preset in
                    Button {
                        APIConfig.apply(preset)
                        syncStateFromConfig()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.body)
                                    .foregroundStyle(VW.Colors.Text.primary)
                                Text(preset.summary)
                                    .font(.caption)
                                    .foregroundStyle(VW.Colors.Text.secondary)
                            }
                            Spacer()
                            if APIConfig.selectedPresetID == preset.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // STT Configuration
            Section("Speech-to-Text") {
                Picker("Provider", selection: $sttProvider) {
                    ForEach(sttProviderChoices, id: \.self) { provider in
                        Text(provider == sttProvider && !provider.hasSTTSupport ? "\(provider.rawValue) (Unavailable)" : provider.rawValue)
                            .tag(provider)
                            .disabled(!provider.hasSTTSupport)
                    }
                }
                .onChange(of: sttProvider) { _, newValue in
                    sttAPIKey = ""
                    guard APIConfig.current.stt.provider != newValue else { return }
                    sttModel = newValue.defaultSTTModel
                    applyConfig()
                }

                if !sttProvider.hasSTTSupport {
                    Text(sttProvider.sttSupportNote ?? "This saved provider is unavailable on iOS. Choose another provider to change it.")
                        .font(.caption)
                        .foregroundStyle(VW.Colors.Text.secondary)
                } else if sttProvider.presetSTTModels.isEmpty {
                    TextField("Custom model", text: $sttModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: sttModel) { _, _ in applyConfig() }
                } else {
                    Picker("Model", selection: $sttModel) {
                        ForEach(sttProvider.presetSTTModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        if !sttModel.isEmpty && !sttProvider.presetSTTModels.contains(sttModel) {
                            Text("\(sttModel) (Saved)").tag(sttModel)
                        }
                    }
                    .onChange(of: sttModel) { _, _ in applyConfig() }
                }

            }

            // Polish Configuration
            Section("AI Polish") {
                Picker("Provider", selection: $polishProvider) {
                    ForEach(polishProviderChoices, id: \.self) { provider in
                        Text(provider == polishProvider && !provider.hasPolishSupport ? "\(provider.rawValue) (Unavailable)" : provider.rawValue)
                            .tag(provider)
                            .disabled(!provider.hasPolishSupport)
                    }
                }
                .onChange(of: polishProvider) { _, newValue in
                    polishAPIKey = ""
                    guard APIConfig.current.polish.provider != newValue else { return }
                    polishModel = newValue.defaultPolishModel
                    applyConfig()
                }

                if !polishProvider.hasPolishSupport {
                    Text("This saved provider does not support AI polish. Choose another provider to change it.")
                        .font(.caption)
                        .foregroundStyle(VW.Colors.Text.secondary)
                } else if polishProvider.presetPolishModels.isEmpty {
                    TextField("Custom model", text: $polishModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: polishModel) { _, _ in applyConfig() }
                } else {
                    Picker("Model", selection: $polishModel) {
                        ForEach(polishProvider.presetPolishModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                        if !polishModel.isEmpty && !polishProvider.presetPolishModels.contains(polishModel) {
                            Text("\(polishModel) (Saved)").tag(polishModel)
                        }
                    }
                    .onChange(of: polishModel) { _, _ in applyConfig() }
                }

            }

        }
        .vwIOSForm()
        .navigationTitle("Models")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectionsPage: some View {
        Form {
            Section {
                Text("Keys are stored securely and used by your selected speech and polish providers.")
                    .font(.subheadline).foregroundStyle(VW.Colors.Text.secondary)
            }
            Section("Speech-to-Text · \(sttProvider.rawValue)") {
                    if sttProvider.requiresAPIKey {
                        SecureField(sttProvider.keyPlaceholder, text: $sttAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedKeyField, equals: .stt)
                            .onSubmit { saveKey(sttAPIKey, for: sttProvider) }

                        if KeyVault.hasKey(for: sttProvider) {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                if !sttProvider.requiresAPIKey {
                    Label("No API key required", systemImage: "checkmark.circle")
                        .foregroundStyle(VW.Colors.Text.secondary)
                }
            }
            Section("AI Polish · \(polishProvider.rawValue)") {
                    if polishProvider.requiresAPIKey && polishProvider != sttProvider {
                        SecureField(polishProvider.keyPlaceholder, text: $polishAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedKeyField, equals: .polish)
                            .onSubmit { saveKey(polishAPIKey, for: polishProvider) }

                        if KeyVault.hasKey(for: polishProvider) {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                if polishProvider == sttProvider {
                    Text("Uses the same provider key as Speech-to-Text.").foregroundStyle(VW.Colors.Text.secondary)
                } else if !polishProvider.requiresAPIKey {
                    Label("No API key required", systemImage: "checkmark.circle")
                        .foregroundStyle(VW.Colors.Text.secondary)
                }
            }
        }
        .vwIOSForm()
        .navigationTitle("API Keys")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveKey(sttAPIKey, for: sttProvider)
            saveKey(polishAPIKey, for: polishProvider)
        }
    }

    private var generalPage: some View {
        Form {
            // Feedback
            Section("Feedback") {
                Toggle("Sound Feedback", isOn: $soundFeedbackEnabled)
                    .onChange(of: soundFeedbackEnabled) { _, newValue in
                        SoundFeedback.isEnabled = newValue
                    }
            }

            // F-066: Translation language quick settings
            // F-079: two-level picker — region variant row appears only
            // for languages that have one (Chinese, English, Spanish,
            // Portuguese, French).
            Section {
                // Persistence folded into the binding setter (rather than
                // a separate .onChange) so the multi-row picker component
                // sits unmodified in the Section, same as the other
                // LanguageRegionPicker call sites.
                LanguageRegionPicker(label: "Source", selection: Binding(
                    get: { translationSourceLocal },
                    set: { translationSourceLocal = $0; setTranslationSource($0) }
                ))
                LanguageRegionPicker(label: "Target", selection: Binding(
                    get: { translationTargetLocal },
                    set: { translationTargetLocal = $0; setTranslationTarget($0) }
                ), excludeAuto: true)
            } header: {
                Text("Translation")
            } footer: {
                Text("Applies to the built-in Translate mode. Custom translation modes keep their own settings.")
            }

        }
        .vwIOSForm()
        .navigationTitle("Language & Feedback")
        .navigationBarTitleDisplayMode(.inline)
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
        let existing = APIConfig.current
        let configuration = SplitAPIConfiguration(
            stt: APIEndpointConfiguration.selecting(
                provider: sttProvider,
                model: sttModel,
                preservingBaseURLFrom: existing.stt
            ),
            polish: APIEndpointConfiguration.selecting(
                provider: polishProvider,
                model: polishModel,
                preservingBaseURLFrom: existing.polish
            )
        )
        APIConfig.apply(configuration)
    }

    private var sttProviderChoices: [APIProvider] {
        var providers = APIProvider.availableSTTCases
        if !providers.contains(sttProvider) {
            providers.append(sttProvider)
        }
        return providers
    }

    private var polishProviderChoices: [APIProvider] {
        var providers = APIProvider.availablePolishCases
        if !providers.contains(polishProvider) {
            providers.append(polishProvider)
        }
        return providers
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

// MARK: - F-079: Language Region Picker (shared)

/// Two-level language picker for iOS `Form`/`Section` contexts — a primary
/// "main language" `Picker` plus a secondary "region variant" `Picker` that
/// only appears for languages that have variants defined (e.g. Chinese,
/// English, Spanish, Portuguese, French). Selecting a new main language
/// always resets to that language's plain code (no variant); selecting a
/// variant row updates `selection` to the full BCP-47 tag.
///
/// Defined here (rather than its own file) because this Xcode project uses
/// an explicit file list — adding a new source file requires a project.pbxproj
/// edit. `SettingsView`, `PersonalizationView`, and `ModeEditorSheet` all
/// reuse this type from within the VowriteIOS module.
struct LanguageRegionPicker: View {
    let label: String
    @Binding var selection: SupportedLanguage
    /// Excludes "Auto-detect" from the main-language list (used for
    /// translation targets, which must be an explicit language).
    var excludeAuto: Bool = false

    private var family: SupportedLanguage { selection.languageFamily }

    private var familyOptions: [SupportedLanguage] {
        let roots = SupportedLanguage.familyRoots
        return excludeAuto ? roots.filter { $0 != .auto } : roots
    }

    var body: some View {
        Picker(label, selection: Binding(
            get: { family },
            set: { selection = $0 }
        )) {
            ForEach(familyOptions) { lang in
                Text(lang.displayName).tag(lang)
            }
        }

        if !family.regionVariants.isEmpty {
            Picker("Region", selection: $selection) {
                Text("Auto / Default").tag(family)
                ForEach(family.regionVariants) { variant in
                    Text(variant.regionLabel ?? variant.displayName).tag(variant)
                }
            }
        }
    }
}
