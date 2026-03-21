import SwiftUI
import VowriteKit

struct PersonalizationView: View {
    @StateObject private var modeManager = ModeManager.shared
    @StateObject private var styleManager = OutputStyleManager.shared
    @StateObject private var vocabManager = VocabularyManager.shared

    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isUserPromptLocked = PromptConfig.isUserPromptLocked

    var body: some View {
        NavigationStack {
            Form {
                // Modes
                Section("Dictation Modes") {
                    ForEach(modeManager.modes) { mode in
                        HStack {
                            Text(mode.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.name)
                                    .font(.body)
                                Text(mode.polishEnabled ? "STT + Polish" : "STT only")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if mode.id == modeManager.currentModeId {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            modeManager.select(mode)
                        }
                    }
                }

                // Output Styles
                Section("Output Styles") {
                    ForEach(styleManager.styles) { style in
                        HStack {
                            Text(style.icon)
                            Text(style.name)
                            Spacer()
                        }
                    }
                }

                // Quick Presets
                Section("Quick Presets") {
                    ForEach(PreferencePreset.allPresets, id: \.name) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // User Prompt
                Section("User Prompt") {
                    TextEditor(text: $userPrompt)
                        .frame(minHeight: 80)
                        .disabled(isUserPromptLocked)
                        .onChange(of: userPrompt) { _, newValue in
                            PromptConfig.userPrompt = newValue
                        }

                    Toggle("Lock Prompt", isOn: $isUserPromptLocked)
                        .onChange(of: isUserPromptLocked) { _, newValue in
                            PromptConfig.isUserPromptLocked = newValue
                        }

                    if !userPrompt.isEmpty {
                        Button("Clear Prompt", role: .destructive) {
                            userPrompt = ""
                            PromptConfig.userPrompt = ""
                        }
                    }
                }

                // Language
                Section("Language") {
                    Picker("Recognition Language", selection: Binding(
                        get: { LanguageConfig.globalLanguage },
                        set: { LanguageConfig.globalLanguage = $0 }
                    )) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                // Personal Vocabulary
                Section("Personal Vocabulary") {
                    ForEach(vocabManager.words, id: \.self) { word in
                        Text(word)
                    }
                    .onDelete { offsets in
                        vocabManager.remove(at: offsets)
                    }

                    HStack {
                        TextField("Add word...", text: .constant(""))
                            .onSubmit {
                                // Handled below
                            }
                    }
                }
            }
            .navigationTitle("Personalization")
        }
    }

    private func applyPreset(_ preset: PreferencePreset) {
        // Apply preset settings to current mode
        if let modeIndex = modeManager.modes.firstIndex(where: { $0.id == modeManager.currentModeId }) {
            var mode = modeManager.modes[modeIndex]
            mode.temperature = preset.temperature
            modeManager.updateMode(mode)
        }
    }
}
