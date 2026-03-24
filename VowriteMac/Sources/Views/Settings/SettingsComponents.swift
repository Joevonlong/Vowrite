import VowriteKit
import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "laptopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content
                    .padding(16)
            }
            .background(Color(.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row

/// Layout mode for settings rows.
/// - `.horizontal`: label left, control right (default for toggles, short pickers)
/// - `.vertical`: label top, control below full-width (for long content like model selectors, presets)
enum SettingsRowLayout {
    case horizontal
    case vertical
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    let description: String
    var layout: SettingsRowLayout = .horizontal
    @ViewBuilder let trailing: Trailing

    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                HStack(alignment: .top, spacing: 24) {
                    labelView
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailing
                        .frame(maxWidth: 360, alignment: .trailing)
                }
            case .vertical:
                VStack(alignment: .leading, spacing: 10) {
                    labelView
                    trailing
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var labelView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.body).fontWeight(.semibold)
            if !description.isEmpty {
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Appearance Picker

struct AppearancePicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = mode.rawValue
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.caption)
                        .frame(width: 28, height: 24)
                        .background(
                            selection == mode.rawValue
                                ? Color.accentColor.opacity(0.15)
                                : Color.clear
                        )
                        .foregroundColor(
                            selection == mode.rawValue
                                ? .accentColor
                                : .secondary
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help(mode.rawValue)
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(.secondary).font(.caption)
                Text(value).font(.system(size: 20, weight: .bold))
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(12)
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let title: String
    let description: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(iconColor).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.06)).cornerRadius(12)
    }
}

// MARK: - Provider Key Status Badge

struct ProviderKeyStatusBadge: View {
    let provider: APIProvider
    let isRequired: Bool

    var body: some View {
        Group {
            if KeyVault.hasKey(for: provider) {
                badge("Saved", color: .green)
            } else if isRequired {
                badge("Required", color: .orange)
            } else {
                badge("Missing", color: .secondary)
            }
        }
    }

    private func badge(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(999)
    }
}

// MARK: - Pipeline Key Status Badge

struct PipelineKeyStatusBadge: View {
    let configuration: APIEndpointConfiguration
    let isSpeechToText: Bool

    var body: some View {
        if isSpeechToText && !configuration.provider.hasSTTSupport {
            statusIcon("xmark.circle.fill", color: .orange, tooltip: "STT not supported")
        } else if !configuration.provider.requiresAPIKey {
            statusIcon("minus.circle", color: .secondary, tooltip: "No key needed")
        } else if configuration.hasKey {
            statusIcon("checkmark.circle.fill", color: .green, tooltip: "Key ready")
        } else {
            statusIcon("exclamationmark.circle.fill", color: .orange, tooltip: "Key missing")
        }
    }

    private func statusIcon(_ systemName: String, color: Color, tooltip: String) -> some View {
        Image(systemName: systemName)
            .font(.body)
            .foregroundColor(color)
            .frame(width: 20, height: 20)
            .fixedSize()
            .help(tooltip)
    }
}

// MARK: - Pipeline Configuration Editor

struct PipelineConfigurationEditor: View {
    let title: String
    let description: String
    let isSpeechToText: Bool
    @Binding var configuration: APIEndpointConfiguration

    /// Controls whether the custom model text field is in editing mode
    @State private var isEditingCustomModel = false
    /// Draft text while editing custom model
    @State private var customModelDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(
                title: "Provider",
                description: providerRowDescription
            ) {
                HStack(spacing: 8) {
                    PipelineKeyStatusBadge(configuration: configuration, isSpeechToText: isSpeechToText)

                    Picker("Provider", selection: providerBinding) {
                        ForEach(APIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .frame(width: 220)
                    .labelsHidden()
                }
            }

            Divider()

            if !modelSuggestions.isEmpty {
                SettingsRow(
                    title: "Model",
                    description: modelRowDescription,
                    layout: .vertical
                ) {
                    Picker("Model", selection: quickModelBinding) {
                        ForEach(modelSuggestions, id: \.self) { model in
                            if let desc = modelDescription(for: model) {
                                Text("\(model) · \(desc)").tag(model)
                            } else {
                                Text(model).tag(model)
                            }
                        }
                        Divider()
                        Text("Custom…").tag(customModelTag)
                    }
                    .labelsHidden()
                }

                if isCustomModel {
                    SettingsRow(
                        title: "Custom Model",
                        description: "Use any provider-specific model identifier when the preset list is not enough.",
                        layout: .vertical
                    ) {
                        customModelEditor(width: .infinity)
                    }
                }
            } else {
                SettingsRow(
                    title: "Custom Model",
                    description: "This provider uses a free-form model identifier.",
                    layout: .vertical
                ) {
                    customModelEditor(width: .infinity)
                }
            }

            Divider()

            SettingsRow(
                title: "Base URL",
                description: baseURLDescription,
                layout: .vertical
            ) {
                if configuration.provider == .custom || configuration.provider == .ollama {
                    TextField("Base URL", text: baseURLBinding)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(configuration.resolvedBaseURL)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Private

    private let customModelTag = "__custom_model__"

    private var modelSuggestions: [String] {
        isSpeechToText ? configuration.provider.presetSTTModels : configuration.provider.presetPolishModels
    }

    private var isCustomModel: Bool {
        !modelSuggestions.isEmpty && !modelSuggestions.contains(configuration.model)
    }

    private func confirmCustomModel() {
        let trimmed = customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        configuration.model = trimmed
        isEditingCustomModel = false
    }

    private var providerBinding: Binding<APIProvider> {
        Binding(
            get: { configuration.provider },
            set: { newProvider in
                configuration.provider = newProvider
                configuration.baseURL = newProvider.defaultBaseURL
                configuration.model = isSpeechToText ? newProvider.defaultSTTModel : newProvider.defaultPolishModel
                isEditingCustomModel = false
                customModelDraft = ""
            }
        )
    }

    private var baseURLBinding: Binding<String> {
        Binding(
            get: { configuration.baseURL },
            set: { configuration.baseURL = $0 }
        )
    }

    private var quickModelBinding: Binding<String> {
        Binding(
            get: {
                modelSuggestions.contains(configuration.model) ? configuration.model : customModelTag
            },
            set: { selection in
                if selection == customModelTag {
                    customModelDraft = ""
                    isEditingCustomModel = true
                    configuration.model = ""
                } else {
                    configuration.model = selection
                    isEditingCustomModel = false
                }
            }
        )
    }

    private func modelDescription(for model: String) -> String? {
        isSpeechToText ? APIProvider.sttModelDescription(model) : APIProvider.polishModelDescription(model)
    }

    private var providerRowDescription: String {
        var parts = [description]

        if isSpeechToText, let note = configuration.provider.sttSupportNote {
            parts.append(note)
        }

        if configuration.provider.requiresAPIKey {
            parts.append("Uses the \(configuration.provider.rawValue) key from the API Keys section.")
        } else {
            parts.append("This provider does not require an API key.")
        }

        return parts.joined(separator: " ")
    }

    private var modelRowDescription: String {
        if modelSuggestions.isEmpty {
            return "Enter a model ID manually for this provider."
        }
        return "Choose a preset model or switch to a custom model ID."
    }

    private var baseURLDescription: String {
        if configuration.provider == .custom || configuration.provider == .ollama {
            return "Override the endpoint URL used for this \(title.lowercased()) pipeline."
        }
        return "Uses the provider default endpoint."
    }

    @ViewBuilder
    private func customModelEditor(width: CGFloat) -> some View {
        if isEditingCustomModel || modelSuggestions.isEmpty || configuration.model.isEmpty {
            HStack(spacing: 8) {
                TextField(modelFieldPlaceholder, text: $customModelDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { confirmCustomModel() }

                Button("Confirm") { confirmCustomModel() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(customModelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .onAppear {
                if configuration.model.isEmpty {
                    isEditingCustomModel = true
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(configuration.model)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)

                Button("Edit") {
                    customModelDraft = configuration.model
                    isEditingCustomModel = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var modelFieldPlaceholder: String {
        modelSuggestions.isEmpty ? "Model ID" : "Enter model ID (e.g. gpt-4o-mini)"
    }
}

// MARK: - Settings Connection Tester

enum SettingsEndpoint {
    case stt
    case polish

    func configuration(from splitConfiguration: SplitAPIConfiguration) -> APIEndpointConfiguration {
        switch self {
        case .stt:
            return splitConfiguration.stt
        case .polish:
            return splitConfiguration.polish
        }
    }
}

enum EndpointTestState: Equatable {
    case idle
    case testing
    case result(success: Bool, message: String)

    var isTesting: Bool {
        if case .testing = self {
            return true
        }
        return false
    }
}

struct EndpointTestBadge: View {
    let state: EndpointTestState

    var body: some View {
        switch state {
        case .idle, .testing:
            EmptyView()
        case .result(let success, let message):
            Text(message)
                .font(.caption)
                .foregroundColor(success ? .green : .red)
        }
    }
}

enum SettingsConnectionTester {
    static func testChatCompletion(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        try await APIConnectionTester.testChatCompletion(
            configuration: configuration,
            apiKeyOverride: apiKeyOverride
        )
    }

    static func testSpeechToText(
        configuration: APIEndpointConfiguration,
        apiKeyOverride: String? = nil
    ) async throws {
        let endpoint = "\(configuration.resolvedBaseURL)/audio/transcriptions"
        guard let url = URL(string: endpoint) else {
            throw VowriteError.apiError("Invalid base URL")
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let apiKey = resolvedAPIKey(for: configuration, override: apiKeyOverride) {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if configuration.provider == .openrouter {
            request.setValue("https://vowrite.com", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Vowrite", forHTTPHeaderField: "X-Title")
        }

        request.httpBody = transcriptionProbeBody(boundary: boundary, model: configuration.model)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VowriteError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw VowriteError.apiError("Error \(httpResponse.statusCode): \(body)")
        }
    }

    private static func resolvedAPIKey(
        for configuration: APIEndpointConfiguration,
        override: String?
    ) -> String? {
        let trimmedOverride = override?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedOverride, !trimmedOverride.isEmpty {
            return trimmedOverride
        }
        return configuration.key
    }

    private static func transcriptionProbeBody(boundary: String, model: String) -> Data {
        var body = Data()
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        body.appendMultipart(boundary: boundary, name: "response_format", value: "text")
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"probe.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(silentWAVData())
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func silentWAVData(
        sampleRate: UInt32 = 16_000,
        durationSeconds: Double = 0.1
    ) -> Data {
        let samples = max(1, Int(Double(sampleRate) * durationSeconds))
        let bitsPerSample: UInt16 = 16
        let channels: UInt16 = 1
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples) * UInt32(blockAlign)

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.appendLE(UInt32(36) + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(byteRate)
        data.appendLE(blockAlign)
        data.appendLE(bitsPerSample)
        data.append("data".data(using: .ascii)!)
        data.appendLE(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer)
        }
    }
}
