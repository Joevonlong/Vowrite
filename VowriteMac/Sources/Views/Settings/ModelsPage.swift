import VowriteKit
import SwiftUI

// MARK: - Models Page (formerly core of Settings)

struct ModelsPageView: View {
    @EnvironmentObject var appState: AppState
    @State private var workingConfig = APIConfig.current
    @State private var selectedPresetID = customPresetID
    @State private var newPresetName = ""
    @State private var configSaved = false
    @State private var sttTestState: EndpointTestState = .idle
    @State private var polishTestState: EndpointTestState = .idle

    private static let customPresetID = "__custom_preset__"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Models")
                        .font(.system(size: 24, weight: .bold))
                    Text(configurationSummaryLine)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                }

                SettingsSection(icon: "square.stack.3d.up", title: "Presets") {
                    presetsContent
                }

                SettingsSection(icon: "waveform", title: "STT") {
                    PipelineConfigurationEditor(
                        title: "Speech-to-text",
                        description: "Choose the provider and model used for transcription.",
                        isSpeechToText: true,
                        configuration: $workingConfig.stt
                    )
                }

                SettingsSection(icon: "sparkles", title: "Polish") {
                    PipelineConfigurationEditor(
                        title: "Cleanup and rewrite",
                        description: "Choose the provider and model used for text polish.",
                        isSpeechToText: false,
                        configuration: $workingConfig.polish
                    )
                }

                SettingsSection(icon: "checkmark.circle", title: "Test & Save") {
                    testAndSaveContent
                }
            }
            .padding(32)
        }
        .onAppear(perform: loadState)
        .onChange(of: workingConfig) { _, newValue in
            if let matchingPreset = APIPresetStore.matchingPreset(for: newValue) {
                selectedPresetID = matchingPreset.id
            }
            configSaved = false
            sttTestState = .idle
            polishTestState = .idle
        }
    }

    // MARK: - Presets Content

    private var presetsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsRow(
                title: "Active Preset",
                description: currentPresetDescription,
                layout: .vertical
            ) {
                HStack(spacing: 10) {
                    Picker("Preset", selection: $selectedPresetID) {
                        Text("Custom").tag(Self.customPresetID)
                        ForEach(APIPresetStore.allPresets) { preset in
                            Text(presetPickerLabel(for: preset)).tag(preset.id)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedPresetID) { _, newValue in
                        guard newValue != Self.customPresetID,
                              let preset = APIPresetStore.preset(for: newValue) else {
                            return
                        }
                        workingConfig = preset.configuration
                    }

                    Button("Reset to Recommended") {
                        applyRecommendedPreset()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .disabled(
                        selectedPresetID == BuiltInAPIPreset.recommended.id &&
                        !isSelectedPresetModified
                    )
                }
            }

            Divider()

            SettingsRow(
                title: "Manage Presets",
                description: "",
                layout: .vertical
            ) {
                HStack(spacing: 8) {
                    TextField("Preset name", text: $newPresetName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 240)

                    Button("Save as Preset") {
                        let preset = APIPresetStore.saveUserPreset(name: newPresetName, configuration: workingConfig)
                        selectedPresetID = APIPresetStore.userPresetID(for: preset.id)
                        newPresetName = ""
                    }
                    .buttonStyle(.bordered)

                    Button("Delete Selected") {
                        deleteSelectedPreset()
                    }
                    .buttonStyle(.bordered)
                    .disabled(selectedUserPresetID == nil)
                }
            }
        }
    }

    // MARK: - Test & Save Content

    private var testAndSaveContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    testEndpoint(.stt)
                } label: {
                    HStack(spacing: 4) {
                        if sttTestState.isTesting {
                            ProgressView().controlSize(.small)
                        }
                        Text("Test STT")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canTest(.stt) || sttTestState.isTesting)

                EndpointTestBadge(state: sttTestState)

                Button {
                    testEndpoint(.polish)
                } label: {
                    HStack(spacing: 4) {
                        if polishTestState.isTesting {
                            ProgressView().controlSize(.small)
                        }
                        Text("Test Polish")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canTest(.polish) || polishTestState.isTesting)

                EndpointTestBadge(state: polishTestState)

                Spacer()

                if configSaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }

                Button("Save Configuration") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Private Helpers

    private func loadState() {
        workingConfig = APIConfig.current
        selectedPresetID = APIConfig.activePreset?.id ?? APIPresetStore.matchingPreset(for: workingConfig)?.id ?? Self.customPresetID
        sttTestState = .idle
        polishTestState = .idle
    }

    private func saveConfiguration() {
        let presetID = APIPresetStore.matchingPreset(for: workingConfig)?.id
        APIConfig.apply(workingConfig, presetID: presetID)
        AuthManager.shared.setAuthMode(.apiKey)
        configSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { configSaved = false }
    }

    private func deleteSelectedPreset() {
        guard let userPresetID = selectedUserPresetID else { return }
        APIPresetStore.deleteUserPreset(id: userPresetID)
        selectedPresetID = APIPresetStore.matchingPreset(for: workingConfig)?.id ?? Self.customPresetID
    }

    private var configurationSummaryLine: String {
        "\(workingConfig.stt.provider.rawValue) STT · \(workingConfig.polish.provider.rawValue) Polish · \(summaryKeyStatus)"
    }

    private var summaryKeyStatus: String {
        let requiredProviders = KeyVault.requiredProviders(for: workingConfig)
        guard !requiredProviders.isEmpty else { return "No keys needed" }

        let readyCount = requiredProviders.filter { KeyVault.hasKey(for: $0) }.count
        return readyCount == requiredProviders.count
            ? "\(readyCount) keys ready"
            : "\(readyCount)/\(requiredProviders.count) keys ready"
    }

    private var selectedUserPresetID: UUID? {
        APIPresetStore.preset(for: selectedPresetID)?.userPresetID
    }

    private var isSelectedPresetModified: Bool {
        guard let preset = APIPresetStore.preset(for: selectedPresetID) else { return false }
        return preset.configuration != workingConfig
    }

    private func presetPickerLabel(for preset: APIPresetOption) -> String {
        let baseName = presetDisplayName(for: preset)
        return "\(baseName) · \(preset.summary)"
    }

    private func presetDisplayName(for preset: APIPresetOption) -> String {
        let isRecommendedPreset = preset.id == BuiltInAPIPreset.recommended.id
        let prefix = isRecommendedPreset ? "⭐ " : ""
        let suffix = selectedPresetID == preset.id && preset.configuration != workingConfig ? " (modified)" : ""
        return "\(prefix)\(preset.name)\(suffix)"
    }

    private func presetSummaryText(for preset: APIPresetOption) -> String {
        if preset.configuration != workingConfig {
            return "\(preset.summary) · Current settings are modified from this preset."
        }
        return preset.summary
    }

    private func applyRecommendedPreset() {
        selectedPresetID = BuiltInAPIPreset.recommended.id
        workingConfig = BuiltInAPIPreset.recommended.configuration
    }

    private var currentPresetDescription: String {
        if let preset = APIPresetStore.preset(for: selectedPresetID) {
            return presetSummaryText(for: preset)
        }
        return "Manual configuration. Save it as a preset if you want to reuse it."
    }

    private func canTest(_ endpoint: SettingsEndpoint) -> Bool {
        switch endpoint {
        case .stt:
            return workingConfig.stt.provider.hasSTTSupport && endpointHasRequiredKey(workingConfig.stt)
        case .polish:
            return endpointHasRequiredKey(workingConfig.polish)
        }
    }

    private func endpointHasRequiredKey(_ configuration: APIEndpointConfiguration) -> Bool {
        !configuration.provider.requiresAPIKey || KeyVault.hasKey(for: configuration.provider)
    }

    private func testEndpoint(_ endpoint: SettingsEndpoint) {
        switch endpoint {
        case .stt:
            sttTestState = .testing
        case .polish:
            polishTestState = .testing
        }

        let configuration = endpoint.configuration(from: workingConfig)

        Task {
            do {
                switch endpoint {
                case .stt:
                    try await SettingsConnectionTester.testSpeechToText(configuration: configuration)
                case .polish:
                    try await SettingsConnectionTester.testChatCompletion(configuration: configuration)
                }

                await MainActor.run {
                    switch endpoint {
                    case .stt:
                        sttTestState = .result(success: true, message: "✅ Ready")
                    case .polish:
                        polishTestState = .result(success: true, message: "✅ Ready")
                    }
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    switch endpoint {
                    case .stt:
                        sttTestState = .result(success: false, message: "❌ \(message)")
                    case .polish:
                        polishTestState = .result(success: false, message: "❌ \(message)")
                    }
                }
            }
        }
    }
}
