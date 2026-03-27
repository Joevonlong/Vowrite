import SwiftUI
import VowriteKit

struct PersonalizationView: View {
    @StateObject private var modeManager = ModeManager.shared
    @StateObject private var styleManager = OutputStyleManager.shared
    @StateObject private var vocabManager = VocabularyManager.shared

    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isUserPromptLocked = PromptConfig.isUserPromptLocked

    // Mode editor state
    @State private var editingMode: Mode? = nil
    @State private var isCreatingNew = false

    var body: some View {
        NavigationStack {
            Form {
                // Modes
                Section {
                    ForEach(modeManager.modes) { mode in
                        HStack {
                            Image(systemName: mode.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)
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
                        .swipeActions(edge: .trailing) {
                            Button {
                                editingMode = mode
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)

                            if !mode.isBuiltin {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modeManager.deleteMode(mode)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Dictation Modes")
                        Spacer()
                        Button {
                            isCreatingNew = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.body)
                        }
                    }
                } footer: {
                    Text("Tap to select · Swipe for edit/delete")
                }

                // Output Styles
                Section("Output Styles") {
                    ForEach(styleManager.styles) { style in
                        HStack {
                            Image(systemName: style.icon)
                                .frame(width: 24)
                            Text(style.name)
                            Spacer()
                        }
                    }
                }

                // Quick Presets
                Section("Quick Presets") {
                    ForEach(PreferencePreset.presets) { preset in
                        Button {
                            applyPreset(preset)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: preset.icon)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text(preset.promptText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
            // Edit sheet
            .sheet(item: $editingMode) { mode in
                ModeEditorSheet(
                    existingMode: mode,
                    onSave: { updated in
                        modeManager.updateMode(updated)
                    },
                    onDelete: { mode in
                        withAnimation {
                            modeManager.deleteMode(mode)
                        }
                    }
                )
            }
            // Create sheet
            .sheet(isPresented: $isCreatingNew) {
                ModeEditorSheet(
                    existingMode: nil,
                    onSave: { newMode in
                        withAnimation {
                            modeManager.addMode(newMode)
                        }
                    }
                )
            }
        }
    }

    private func applyPreset(_ preset: PreferencePreset) {
        userPrompt = preset.promptText
        PromptConfig.userPrompt = preset.promptText
        isUserPromptLocked = true
        PromptConfig.isUserPromptLocked = true
    }
}
