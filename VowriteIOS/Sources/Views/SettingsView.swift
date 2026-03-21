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
        }
    }

    private func syncStateFromConfig() {
        sttProvider = APIConfig.sttProvider
        sttModel = APIConfig.sttModel
        polishProvider = APIConfig.polishProvider
        polishModel = APIConfig.polishModel
        sttAPIKey = ""
        polishAPIKey = ""
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
}
