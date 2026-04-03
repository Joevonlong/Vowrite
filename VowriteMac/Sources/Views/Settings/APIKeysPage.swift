import VowriteKit
import SwiftUI

// MARK: - API Keys Page

struct APIKeysPageView: View {
    @State private var keyInputs: [APIProvider: String] = [:]
    @State private var keyEditorExpanded: [APIProvider: Bool] = [:]
    @State private var keysSaved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("API Keys")
                    .font(.system(size: 24, weight: .bold))

                // Configuration summary
                SettingsSection(icon: "slider.horizontal.3", title: "Current Configuration") {
                    configurationSummary
                }

                // Provider keys management
                SettingsSection(icon: "key", title: "Provider Keys") {
                    providerKeysContent
                }
            }
            .padding(32)
        }
        .onAppear(perform: loadState)
    }

    // MARK: - Configuration Summary

    private var configurationSummary: some View {
        let configuration = APIConfig.current
        let presetName = APIConfig.activePreset?.name ?? "Custom"
        let missingProviders = KeyVault.missingProviders(for: configuration)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STT").font(.caption).foregroundColor(.secondary)
                    Text("\(configuration.stt.provider.rawValue) · \(configuration.stt.model)")
                        .font(.caption2)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Polish").font(.caption).foregroundColor(.secondary)
                    Text("\(configuration.polish.provider.rawValue) · \(configuration.polish.model)")
                        .font(.caption2)
                        .lineLimit(1)
                }
                Spacer()
                Text("Preset: \(presetName)")
                    .font(.caption).foregroundColor(.secondary)
            }

            Divider()

            if missingProviders.isEmpty {
                Label("All required provider keys are ready in Keychain.", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Label(
                    "Missing keys: \(missingProviders.map(\.rawValue).joined(separator: ", "))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundColor(.orange)
                .font(.caption)
            }
        }
    }

    // MARK: - Provider Keys Content

    private var providerKeysContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Storage").font(.body).fontWeight(.semibold)
                    Text("Keys are stored in macOS Keychain once per provider.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                if keysSaved {
                    Label("Keys saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(KeyVault.managedProviders.enumerated()), id: \.element.id) { index, provider in
                    if provider == .minimax {
                        MiniMaxOAuthCard()
                            .padding(.vertical, 4)
                    } else {
                        providerKeyRow(for: provider)
                            .padding(.vertical, 8)
                    }

                    if index < KeyVault.managedProviders.count - 1 {
                        Divider()
                    }
                }
            }

            HStack {
                Spacer()
                Button("Save Keys") {
                    saveKeys()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasPendingKeyChanges)
            }
        }
    }

    // MARK: - Provider Key Row

    private func providerKeyRow(for provider: APIProvider) -> some View {
        let isConfigured = KeyVault.hasKey(for: provider)
        let isExpanded = isKeyEditorExpanded(for: provider)

        return HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                Text(provider.rawValue)
                    .font(.body).fontWeight(.medium)

                ProviderKeyStatusBadge(
                    provider: provider,
                    isRequired: providerIsInUse(provider)
                )
            }
            .frame(minWidth: 140, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                if isConfigured, let maskedKey = KeyVault.maskedKey(for: provider), !isExpanded {
                    Text(maskedKey)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }

                if isExpanded {
                    SecureField(provider.keyPlaceholder, text: keyBinding(for: provider))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                }

                if !provider.keyURL.isEmpty && !isConfigured {
                    Link("Get \(provider.rawValue) key →", destination: URL(string: provider.keyURL)!)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if isConfigured {
                    Button("Edit") {
                        keyEditorExpanded[provider] = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)

                    Button("Clear") {
                        _ = KeyVault.deleteKey(for: provider)
                        keyInputs[provider] = ""
                        keyEditorExpanded[provider] = false
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                } else if !isExpanded {
                    Button("Add") {
                        keyEditorExpanded[provider] = true
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func loadState() {
        keyInputs = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, "") })
        keyEditorExpanded = Dictionary(uniqueKeysWithValues: KeyVault.managedProviders.map { ($0, false) })
    }

    private func keyBinding(for provider: APIProvider) -> Binding<String> {
        Binding(
            get: { keyInputs[provider] ?? "" },
            set: { keyInputs[provider] = $0 }
        )
    }

    private func saveKeys() {
        for provider in KeyVault.managedProviders {
            let value = (keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                _ = KeyVault.saveKey(value, for: provider)
                keyInputs[provider] = ""
                keyEditorExpanded[provider] = false
            }
        }
        AuthManager.shared.setAuthMode(.apiKey)
        keysSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { keysSaved = false }
    }

    private var hasPendingKeyChanges: Bool {
        KeyVault.managedProviders.contains { provider in
            !(keyInputs[provider] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func providerIsInUse(_ provider: APIProvider) -> Bool {
        let config = APIConfig.current
        return config.stt.provider == provider || config.polish.provider == provider
    }

    private func isKeyEditorExpanded(for provider: APIProvider) -> Bool {
        let hasSavedKey = KeyVault.hasKey(for: provider)
        if !hasSavedKey && providerIsInUse(provider) {
            return true
        }
        return keyEditorExpanded[provider] ?? false
    }
}
