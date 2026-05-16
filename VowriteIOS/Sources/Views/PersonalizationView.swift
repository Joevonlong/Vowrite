import SwiftUI
import VowriteKit
import UniformTypeIdentifiers

struct PersonalizationView: View {
    @StateObject private var modeManager = ModeManager.shared
    @StateObject private var styleManager = OutputStyleManager.shared
    @StateObject private var vocabManager = VocabularyManager.shared
    @StateObject private var replacementManager = ReplacementManager.shared

    // Global Preferences state — same Edit/Save/Cancel discipline as the
    // macOS Personalization page. Nothing is written to PromptConfig until
    // the user taps Save; the editor is hard-disabled outside of edit mode
    // so taps and gestures cannot mutate the committed prompt.
    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isEditingPrompt = false
    @State private var stashedPrompt = ""
    @State private var showDiscardConfirm = false
    @State private var showClearConfirm = false

    // Mode editor state
    @State private var editingMode: Mode? = nil
    @State private var isCreatingNew = false

    // Vocabulary state
    @State private var newVocabWord = ""

    // CSV Import / Export state
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var importStatusMessage: String? = nil
    @State private var importStatusTask: Task<Void, Never>? = nil
    @State private var importError: String? = nil
    @State private var showImportError = false

    // Corrections state
    @State private var newTrigger = ""
    @State private var newReplacement = ""

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

                // Quick Presets — applying a preset fills the editor draft and
                // enters edit mode; the user must still tap Save to commit.
                Section {
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
                } header: {
                    Text("Quick Presets")
                } footer: {
                    Text("Tap a preset to load it into the User Prompt editor below. You'll still need to Save to apply it.")
                }

                // User Prompt — explicit Edit/Save/Cancel, never auto-saved.
                Section {
                    TextEditor(text: $userPrompt)
                        .frame(minHeight: 80)
                        .disabled(!isEditingPrompt)
                        .opacity(isEditingPrompt ? 1.0 : 0.7)

                    if isEditingPrompt {
                        HStack {
                            Button("Cancel", role: .cancel) { requestCancelPrompt() }
                            Spacer()
                            Button("Save") { commitSavePrompt() }
                                .fontWeight(.semibold)
                                .disabled(userPrompt == stashedPrompt)
                        }
                    } else if userPrompt.isEmpty {
                        Button("Add Preferences") { beginEditPrompt() }
                    } else {
                        HStack {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Edit") { beginEditPrompt() }
                            Button("Clear", role: .destructive) { showClearConfirm = true }
                        }
                    }
                } header: {
                    Text("User Prompt")
                } footer: {
                    Text(isEditingPrompt
                         ? "Tap Save to apply, or Cancel to discard your changes."
                         : "Applied to all scenes as a supplement to each scene's own prompt.")
                }
                .confirmationDialog(
                    "Discard your changes?",
                    isPresented: $showDiscardConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Discard Changes", role: .destructive) { discardEditPrompt() }
                    Button("Keep Editing", role: .cancel) {}
                } message: {
                    Text("Unsaved edits to your User Prompt will be lost.")
                }
                .confirmationDialog(
                    "Clear your User Prompt?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { clearPrompt() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes your saved User Prompt. Built-in scenes are unaffected.")
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
                Section {
                    ForEach(vocabManager.words, id: \.self) { word in
                        Text(word)
                    }
                    .onDelete { offsets in
                        vocabManager.remove(at: offsets)
                    }

                    HStack {
                        TextField("Add word...", text: $newVocabWord)
                            .onSubmit {
                                let trimmed = newVocabWord.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                if trimmed.contains(",") {
                                    vocabManager.addBulk(trimmed)
                                } else {
                                    vocabManager.add(trimmed)
                                }
                                newVocabWord = ""
                            }
                    }
                } header: {
                    HStack {
                        Text("Personal Vocabulary")
                        Spacer()
                        Button {
                            isImporting = true
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .font(.body)
                        }
                        Button {
                            isExporting = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                        }
                        .disabled(vocabManager.words.isEmpty)
                    }
                } footer: {
                    if let message = importStatusMessage {
                        Text(message)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Swipe to delete. Tap ↓ to import CSV, ↑ to export.")
                    }
                }

                // Text Corrections (F-051)
                Section {
                    ForEach(replacementManager.rules) { rule in
                        HStack {
                            Text(rule.trigger)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(rule.replacement)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        replacementManager.remove(at: offsets)
                    }

                    HStack(spacing: 8) {
                        TextField("Trigger", text: $newTrigger)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Replace with", text: $newReplacement)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        Button {
                            let trigger = newTrigger.trimmingCharacters(in: .whitespaces)
                            let replacement = newReplacement.trimmingCharacters(in: .whitespaces)
                            guard !trigger.isEmpty, !replacement.isEmpty else { return }
                            replacementManager.add(trigger: trigger, replacement: replacement)
                            newTrigger = ""
                            newReplacement = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty ||
                                  newReplacement.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Text Corrections")
                } footer: {
                    Text("Auto-correct misrecognized words. Swipe to delete.")
                }
            }
            .navigationTitle("Personalization")
            // CSV file pickers (F-074)
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .fileExporter(
                isPresented: $isExporting,
                document: VocabularyCSVDocumentIOS(csv: vocabManager.exportCSV()),
                contentType: .commaSeparatedText,
                defaultFilename: exportFilename()
            ) { _ in }
            .alert("Import Error", isPresented: $showImportError, presenting: importError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error)
            }
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

    // MARK: - User Prompt edit lifecycle

    private func beginEditPrompt() {
        stashedPrompt = userPrompt
        isEditingPrompt = true
    }

    private func requestCancelPrompt() {
        if userPrompt != stashedPrompt {
            showDiscardConfirm = true
        } else {
            discardEditPrompt()
        }
    }

    private func discardEditPrompt() {
        userPrompt = stashedPrompt
        isEditingPrompt = false
    }

    private func commitSavePrompt() {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        userPrompt = trimmed
        PromptConfig.userPrompt = trimmed
        PromptConfig.isUserPromptLocked = !trimmed.isEmpty
        stashedPrompt = trimmed
        isEditingPrompt = false
    }

    private func clearPrompt() {
        userPrompt = ""
        stashedPrompt = ""
        PromptConfig.userPrompt = ""
        PromptConfig.isUserPromptLocked = false
        isEditingPrompt = false
    }

    private func applyPreset(_ preset: PreferencePreset) {
        // Tap a preset → load into draft and enter edit mode. The user must
        // explicitly Save to commit, matching the rest of the lock model.
        if !isEditingPrompt {
            stashedPrompt = userPrompt
            isEditingPrompt = true
        }
        userPrompt = preset.promptText
    }

    // MARK: - CSV Import / Export helpers (F-074)

    private func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "vowrite-vocabulary-\(formatter.string(from: Date())).csv"
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let raw = try String(contentsOf: url, encoding: .utf8)
                let importResult = vocabManager.importCSV(raw)
                let wordCount = importResult.imported
                let dupCount = importResult.duplicates
                let msg = "Imported \(wordCount) word\(wordCount == 1 ? "" : "s"), skipped \(dupCount) duplicate\(dupCount == 1 ? "" : "s")"
                showImportStatus(msg)
            } catch {
                importError = "Could not read file: \(error.localizedDescription)"
                showImportError = true
            }
        }
    }

    private func showImportStatus(_ message: String) {
        importStatusTask?.cancel()
        importStatusMessage = message
        importStatusTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                importStatusMessage = nil
            }
        }
    }
}

// MARK: - VocabularyCSVDocumentIOS (F-074)

/// FileDocument for vocabulary CSV on iOS (mirrors VocabularyCSVDocument in VowriteMac).
struct VocabularyCSVDocumentIOS: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var csv: String

    init(csv: String) {
        self.csv = csv
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.csv = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(csv.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
