import VowriteKit
import SwiftUI

// MARK: - Mode Editor Sheet

struct ModeEditorSheet: View {
    /// Pass an existing mode to edit, or nil to create new.
    let existingMode: Mode?
    let onSave: (Mode) -> Void
    let onDelete: ((Mode) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var styleManager = OutputStyleManager.shared

    @State private var draft: Mode
    @State private var showIconPicker = false
    @State private var showDeleteConfirm = false

    init(existingMode: Mode?, onSave: @escaping (Mode) -> Void, onDelete: ((Mode) -> Void)? = nil) {
        self.existingMode = existingMode
        self.onSave = onSave
        self.onDelete = onDelete

        let initial = existingMode ?? Mode(
            id: UUID(),
            name: "",
            icon: "sparkles",
            isBuiltin: false,
            sttModel: nil,
            language: nil,
            polishEnabled: true,
            polishModel: nil,
            systemPrompt: "",
            userPrompt: "",
            temperature: 0.3,
            autoPaste: true,
            outputStyleId: nil,
            shortcutIndex: nil
        )
        _draft = State(initialValue: initial)
    }

    private var isNew: Bool { existingMode == nil }
    private var canSave: Bool {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // F-063: translation mode requires a non-empty target language
        if draft.isTranslation {
            guard let target = draft.targetLanguage,
                  !target.isEmpty,
                  SupportedLanguage(rawValue: target) != nil else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Basic ──
                Section("Basic") {
                    HStack(spacing: 16) {
                        // Icon preview + picker
                        Button { showIconPicker = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 48, height: 48)
                                Image(systemName: draft.icon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showIconPicker) {
                            IconPickerView(selected: $draft.icon)
                        }

                        TextField("Scene Name", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // ── F-063: Mode Type ──
                Section("Mode Type") {
                    Toggle("Translation Mode", isOn: Binding(
                        get: { draft.isTranslation },
                        set: { newVal in
                            draft.isTranslation = newVal
                            // Sensible defaults when flipping the switch on
                            if newVal {
                                if draft.targetLanguage == nil || draft.targetLanguage?.isEmpty == true {
                                    draft.targetLanguage = SupportedLanguage.en.rawValue
                                }
                                // Translation always requires the LLM step
                                draft.polishEnabled = true
                            }
                        }
                    ))
                    .animation(.easeInOut(duration: 0.2), value: draft.isTranslation)
                    .disabled(draft.isBuiltin && draft.isTranslation)   // can't disable on builtin Translate

                    if draft.isTranslation {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.accentColor)
                            Text("Speech is translated into your target language. Output Style and User Prompt are not used in this mode.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if draft.isTranslation {
                    translationSections
                } else {
                    polishSections
                }

                // ── Danger zone ──
                if !isNew {
                    Section {
                        if draft.isBuiltin {
                            Button("Reset to Default") {
                                resetToDefault()
                            }
                            .foregroundColor(.orange)
                        } else {
                            Button("Delete This Scene") {
                                showDeleteConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "New Scene" : "Edit Scene")
            .frame(minWidth: 500, idealWidth: 540, minHeight: 560, idealHeight: 660)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "Delete \"\(draft.name)\"?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    onDelete?(draft)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This scene and all its settings will be permanently removed.")
            }
        }
    }

    // MARK: - F-063 Translation Sections

    @ViewBuilder
    private var translationSections: some View {
        Section("Languages") {
            Picker("Source Language", selection: Binding(
                get: { draft.language ?? SupportedLanguage.auto.rawValue },
                set: { draft.language = ($0 == SupportedLanguage.auto.rawValue) ? nil : $0 }
            )) {
                ForEach(SupportedLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }

            Picker("Target Language", selection: Binding(
                get: { draft.targetLanguage ?? SupportedLanguage.en.rawValue },
                set: { draft.targetLanguage = $0 }
            )) {
                // Translation target excludes "Auto-detect" — must be explicit
                ForEach(SupportedLanguage.allCases.filter { $0 != .auto }) { lang in
                    Text(lang.displayName).tag(lang.rawValue)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(SupportedLanguage(rawValue: draft.language ?? "auto")?.displayName ?? "Auto-detect") → \(SupportedLanguage(rawValue: draft.targetLanguage ?? "")?.displayName ?? "—")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        Section("AI Polish") {
            HStack {
                Text("Temperature")
                Slider(value: $draft.temperature, in: 0...1, step: 0.1)
                Text(String(format: "%.1f", draft.temperature))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .frame(width: 28)
            }
            Text("Lower values produce more literal translations. The translation step always runs through the AI provider configured for Polish.")
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Section("Advanced") {
            DisclosureGroup("Additional translate instructions (optional)") {
                VStack(alignment: .leading, spacing: 4) {
                    TextEditor(text: $draft.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                    Text("Appended to the built-in translation prompt. Example: \"Translate into British English\" or \"Use formal register only\".")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Toggle("Auto-paste after processing", isOn: $draft.autoPaste)
        }
    }

    // MARK: - Existing Polish Sections (extracted unchanged)

    @ViewBuilder
    private var polishSections: some View {
        // ── AI Polish ──
        Section("AI Polish") {
            Toggle("Enable Polish", isOn: $draft.polishEnabled)
                .animation(.easeInOut(duration: 0.2), value: draft.polishEnabled)

            if draft.polishEnabled {
                HStack {
                    Text("Temperature")
                    Slider(value: $draft.temperature, in: 0...1, step: 0.1)
                    Text(String(format: "%.1f", draft.temperature))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                        .frame(width: 28)
                }

                Picker("Output Style", selection: $draft.outputStyleId) {
                    Text("None").tag(UUID?.none)
                    ForEach(styleManager.styles.filter { $0.id != OutputStyle.noneId }) { style in
                        Label(style.name, systemImage: style.icon)
                            .tag(Optional(style.id))
                    }
                }
            }
        }

        // ── Prompts ──
        if draft.polishEnabled {
            Section("Prompts") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $draft.systemPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("User Prompt (optional)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $draft.userPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }

        // ── Advanced ──
        Section("Advanced") {
            Toggle("Auto-paste after processing", isOn: $draft.autoPaste)
        }
    }

    private func save() {
        onSave(draft)
        dismiss()
    }

    private func resetToDefault() {
        guard draft.isBuiltin,
              let original = Mode.builtinModes.first(where: { $0.id == draft.id }) else { return }
        draft = original
    }
}
