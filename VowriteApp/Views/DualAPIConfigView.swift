import SwiftUI

/// F-019: UI for configuring separate STT and Polish API providers
struct DualAPIConfigView: View {
    @State private var enabled = DualAPIConfig.isDualModeEnabled
    @State private var sttProvider = DualAPIConfig.sttProvider
    @State private var sttKey = ""
    @State private var sttModel = DualAPIConfig.sttModel
    @State private var polishProvider = DualAPIConfig.polishProvider
    @State private var polishKey = ""
    @State private var polishModel = DualAPIConfig.polishModel
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use separate providers for STT and Polish", isOn: $enabled)
                .onChange(of: enabled) { _, v in DualAPIConfig.isDualModeEnabled = v }

            if enabled {
                Text("Example: Groq Whisper (fast, free STT) + OpenAI GPT (quality polish)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // STT Config
                GroupBox("Speech-to-Text (STT)") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Provider", selection: $sttProvider) {
                            ForEach(APIProvider.allCases.filter(\.hasSTTSupport)) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .onChange(of: sttProvider) { _, v in
                            sttModel = v.defaultSTTModel
                        }
                        SecureField(sttProvider.keyPlaceholder, text: $sttKey)
                            .textFieldStyle(.roundedBorder)
                        if !sttProvider.presetSTTModels.isEmpty {
                            Picker("Model", selection: $sttModel) {
                                ForEach(sttProvider.presetSTTModels, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                        } else {
                            LabeledContent("Model") {
                                Text(sttModel).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                // Polish Config
                GroupBox("AI Polish") {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Provider", selection: $polishProvider) {
                            ForEach(APIProvider.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .onChange(of: polishProvider) { _, v in
                            polishModel = v.defaultPolishModel
                        }
                        SecureField(polishProvider.keyPlaceholder, text: $polishKey)
                            .textFieldStyle(.roundedBorder)
                        if !polishProvider.presetPolishModels.isEmpty {
                            Picker("Model", selection: $polishModel) {
                                ForEach(polishProvider.presetPolishModels, id: \.self) { m in
                                    Text(m).tag(m)
                                }
                            }
                        } else {
                            LabeledContent("Model") {
                                Text(polishModel).foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                // Save button
                HStack {
                    Spacer()
                    if saved {
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    Button("Save Dual Config") { saveDualConfig() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                Text("When disabled, both STT and Polish use your main API configuration.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func saveDualConfig() {
        DualAPIConfig.sttProvider = sttProvider
        DualAPIConfig.sttBaseURL = sttProvider.defaultBaseURL
        DualAPIConfig.sttModel = sttModel
        if !sttKey.isEmpty { DualAPIConfig.sttAPIKey = sttKey }

        DualAPIConfig.polishProvider = polishProvider
        DualAPIConfig.polishBaseURL = polishProvider.defaultBaseURL
        DualAPIConfig.polishModel = polishModel
        if !polishKey.isEmpty { DualAPIConfig.polishAPIKey = polishKey }

        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
    }
}
