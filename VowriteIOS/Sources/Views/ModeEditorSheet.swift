import SwiftUI
import VowriteKit

struct ModeEditorSheet: View {
    let existingMode: Mode?
    let onSave: (Mode) -> Void
    let onDelete: ((Mode) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var styleManager = OutputStyleManager.shared

    @State private var draft: Mode
    /// Snapshot of the mode at sheet open. `draft != baseline` means the user
    /// has unsaved edits; we use this to block swipe-to-dismiss and to
    /// confirm before discarding via Cancel.
    @State private var baseline: Mode
    @State private var showIconPicker = false
    @State private var showDeleteConfirm = false
    @State private var showCancelConfirm = false

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
        _baseline = State(initialValue: initial)
    }

    private var isDirty: Bool { draft != baseline }

    private var isNew: Bool { existingMode == nil }
    private var canSave: Bool {
        guard !draft.name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        // F-064: translation mode requires a non-empty, recognised target language
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
                // Basic
                Section("Basic") {
                    HStack(spacing: 12) {
                        Button { showIconPicker = true } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: draft.icon)
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)

                        TextField("Scene Name", text: $draft.name)
                    }
                }

                // F-064: Mode Type — mirrors macOS ModeEditorSheet
                Section("Mode Type") {
                    Toggle("Translation Mode", isOn: Binding(
                        get: { draft.isTranslation },
                        set: { newVal in
                            draft.isTranslation = newVal
                            if newVal {
                                if draft.targetLanguage == nil || draft.targetLanguage?.isEmpty == true {
                                    draft.targetLanguage = SupportedLanguage.en.rawValue
                                }
                                // Translation always needs the LLM step.
                                draft.polishEnabled = true
                            }
                        }
                    ))
                    .animation(.easeInOut(duration: 0.2), value: draft.isTranslation)
                    .disabled(draft.isBuiltin && draft.isTranslation)

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

                // Danger zone
                if !isNew {
                    Section {
                        if draft.isBuiltin {
                            Button("Reset to Default") {
                                resetToDefault()
                            }
                            .foregroundColor(.orange)
                        } else {
                            Button("Delete This Scene", role: .destructive) {
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Scene" : "Edit Scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { requestCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            // Block swipe-to-dismiss while there are unsaved edits. Cancel is
            // the only path out, and Cancel will prompt to confirm if dirty.
            .interactiveDismissDisabled(isDirty)
            .sheet(isPresented: $showIconPicker) {
                iOSIconPickerView(selected: $draft.icon)
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
            .confirmationDialog(
                "Discard your changes?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Unsaved edits to this scene will be lost.")
            }
        }
    }

    private func requestCancel() {
        if isDirty {
            showCancelConfirm = true
        } else {
            dismiss()
        }
    }

    // MARK: - F-064 Translation Sections

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
                        .frame(minHeight: 80)
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
        // AI Polish
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

        // Prompts
        if draft.polishEnabled {
            Section("System Prompt") {
                TextEditor(text: $draft.systemPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
            }

            Section("User Prompt (optional)") {
                TextEditor(text: $draft.userPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 60)
            }
        }

        // Advanced
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

// MARK: - Icon Picker (iOS)

private struct iOSIconPickerView: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    private static let icons = [
        "mic.fill", "sparkles", "envelope", "bubble.left", "note.text",
        "chevron.left.forwardslash.chevron.right", "doc.text", "list.bullet",
        "person.fill", "briefcase.fill", "graduationcap.fill", "paintbrush.fill",
        "wrench.and.screwdriver.fill", "heart.fill", "star.fill", "bolt.fill",
        "globe", "music.note", "camera.fill", "book.fill",
        "pencil", "megaphone.fill", "flag.fill", "tag.fill",
        "bookmark.fill", "newspaper.fill", "phone.fill", "chart.bar.fill",
        "brain.head.profile", "text.bubble.fill",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(56)), count: 5), spacing: 12) {
                    ForEach(Self.icons, id: \.self) { icon in
                        let isSelected = selected == icon
                        Button {
                            selected = icon
                            dismiss()
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(isSelected
                                    ? VW.Colors.Accent.strong
                                    : VW.Colors.Background.elevated)
                                .cornerRadius(VW.Radius.xxl)
                                .overlay(
                                    RoundedRectangle(cornerRadius: VW.Radius.xxl)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(isSelected ? .accentColor : .primary)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
