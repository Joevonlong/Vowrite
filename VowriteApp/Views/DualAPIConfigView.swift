import SwiftUI

/// F-019: UI for configuring separate STT and Polish API providers
struct DualAPIConfigView: View {
    @State private var enabled = DualAPIConfig.isDualModeEnabled
    @State private var sttProvider = DualAPIConfig.sttProvider
    @State private var sttKey = ""
    @State private var sttModel = DualAPIConfig.sttModel
    @State private var customSTTModel = ""
    @State private var polishProvider = DualAPIConfig.polishProvider
    @State private var polishKey = ""
    @State private var polishModel = DualAPIConfig.polishModel
    @State private var customPolishModel = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Use separate providers for STT and Polish", isOn: $enabled)
                .onChange(of: enabled) { _, v in DualAPIConfig.isDualModeEnabled = v }

            if enabled {
                Text("Recommended: Groq Whisper (fastest & cheapest STT) + DeepSeek V3 (best value polish)")
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
                            customSTTModel = ""
                        }
                        if sttProvider.requiresAPIKey {
                            SecureField(sttProvider.keyPlaceholder, text: $sttKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text("No API key required — \(sttProvider.rawValue) runs locally.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        dualModelPicker(
                            label: "Model",
                            selection: $sttModel,
                            customText: $customSTTModel,
                            presets: sttProvider.presetSTTModels,
                            descriptionFn: APIProvider.sttModelDescription
                        )
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
                            customPolishModel = ""
                        }
                        if polishProvider.requiresAPIKey {
                            SecureField(polishProvider.keyPlaceholder, text: $polishKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text("No API key required — \(polishProvider.rawValue) runs locally.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        dualModelPicker(
                            label: "Model",
                            selection: $polishModel,
                            customText: $customPolishModel,
                            presets: polishProvider.presetPolishModels,
                            descriptionFn: APIProvider.polishModelDescription
                        )
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

    /// A model picker that shows presets (if any) plus a "Custom..." option for manual input.
    /// If no presets exist, shows a text field directly.
    @ViewBuilder
    private func dualModelPicker(
        label: String,
        selection: Binding<String>,
        customText: Binding<String>,
        presets: [String],
        descriptionFn: @escaping (String) -> String?
    ) -> some View {
        let isCustomValue = !presets.contains(selection.wrappedValue) && selection.wrappedValue != "__custom__"

        if !presets.isEmpty {
            Picker(label, selection: selection) {
                ForEach(presets, id: \.self) { model in
                    if let desc = descriptionFn(model) {
                        Text("\(model)  ·  \(desc)").tag(model)
                    } else {
                        Text(model).tag(model)
                    }
                }
                Divider()
                Text("Custom...").tag("__custom__")
            }
            .onChange(of: selection.wrappedValue) { _, v in
                if v == "__custom__" {
                    // Switch to custom mode: use customText or empty
                    selection.wrappedValue = customText.wrappedValue.isEmpty
                        ? "" : customText.wrappedValue
                }
            }

            // Show text field when custom value is active
            if isCustomValue || selection.wrappedValue.isEmpty {
                TextField("Enter model name (e.g. gpt-4o-mini-transcribe)", text: customText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: customText.wrappedValue) { _, v in
                        selection.wrappedValue = v
                    }
                    .onAppear {
                        // Sync initial custom value
                        if isCustomValue && customText.wrappedValue.isEmpty {
                            customText.wrappedValue = selection.wrappedValue
                        }
                    }
            }
        } else {
            // No presets — always show text field
            TextField("\(label) (e.g. whisper-large-v3-turbo)", text: selection)
                .textFieldStyle(.roundedBorder)
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
