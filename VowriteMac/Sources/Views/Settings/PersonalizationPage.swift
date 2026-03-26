import VowriteKit
import SwiftUI

// MARK: - Personalization Page

struct PersonalizationPageView: View {
    @ObservedObject private var modeManager = ModeManager.shared

    @ObservedObject private var vocabManager = VocabularyManager.shared
    @State private var newWord = ""

    // Global Preferences state
    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isLocked = PromptConfig.isUserPromptLocked
    @State private var isEditing = false
    @State private var stashedPrompt = ""

    // Sheet state
    @State private var editingMode: Mode? = nil
    @State private var isCreatingNew = false

    // Delete state
    @State private var showDeleteConfirm = false
    @State private var modeToDelete: Mode? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Personalization")
                    .font(.system(size: 24, weight: .bold))

                scenesSection
                vocabularySection
                globalPreferencesSection
                howItWorksSection
            }
            .padding(32)
        }
        // Edit sheet
        .sheet(item: $editingMode) { mode in
            ModeEditorSheet(
                existingMode: mode,
                onSave: { updated in
                    modeManager.updateMode(updated)
                },
                onDelete: { mode in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        modeManager.addMode(newMode)
                    }
                }
            )
        }
        // Delete confirmation (from context menu)
        .confirmationDialog(
            "Delete \"\(modeToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let mode = modeToDelete {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        modeManager.deleteMode(mode)
                    }
                }
                modeToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                modeToDelete = nil
            }
        } message: {
            Text("This scene and all its settings will be permanently removed.")
        }
        .onAppear {
            loadGlobalPreferences()
        }
    }

    // MARK: - Scenes Section

    private var scenesSection: some View {
        SettingsSection(icon: "theatermasks", title: "Scenes") {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    Text("Tap to activate · Double-click or ⚙ to edit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        isCreatingNew = true
                    } label: {
                        Label("New Scene", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Cards grid
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ],
                    spacing: 14
                ) {
                    ForEach(modeManager.modes) { mode in
                        ModeCardView(
                            mode: mode,
                            isActive: mode.id == modeManager.currentModeId,
                            onSelect: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    modeManager.select(mode)
                                }
                            },
                            onEdit: {
                                editingMode = mode
                            },
                            onDuplicate: {
                                duplicateMode(mode)
                            },
                            onDelete: mode.isBuiltin ? nil : {
                                modeToDelete = mode
                                showDeleteConfirm = true
                            },
                            onReset: mode.isBuiltin ? {
                                modeManager.resetBuiltinMode(mode)
                            } : nil
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    // + New Scene placeholder card
                    NewSceneCardView {
                        isCreatingNew = true
                    }
                }

                // Tip
                Text("Tip: Use ⌘1–⌘9 to quickly switch scenes.")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }

    // MARK: - Vocabulary Section

    private var vocabularySection: some View {
        SettingsSection(icon: "text.book.closed", title: "Personal Vocabulary") {
            VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                Text("Words listed here are sent as hints to the speech-to-text engine, improving recognition of names, jargon, and abbreviations.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Tag cloud
                if !vocabManager.words.isEmpty {
                    WrappingHStack(items: vocabManager.words, spacing: VW.Spacing.sm) { word in
                        HStack(spacing: VW.Spacing.xs) {
                            Text(word).font(.callout)
                            Button {
                                withAnimation(VW.Anim.easeQuick) {
                                    vocabManager.remove(word)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, VW.Spacing.md)
                        .padding(.vertical, VW.Spacing.xs)
                        .background(VW.Colors.Background.elevated)
                        .cornerRadius(VW.Radius.lg)
                    }
                }

                // Add input
                HStack(spacing: VW.Spacing.md) {
                    TextField("Add word or paste comma-separated list…", text: $newWord)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addVocabulary() }
                    Button("Add") { addVocabulary() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func addVocabulary() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(VW.Anim.easeQuick) {
            if trimmed.contains(",") {
                vocabManager.addBulk(trimmed)
            } else {
                vocabManager.add(trimmed)
            }
        }
        newWord = ""
    }

    // MARK: - Global Preferences Section

    private var globalPreferencesSection: some View {
        SettingsSection(icon: "person.text.rectangle", title: "Global Preferences") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Applied to all scenes. Complements each scene's own prompt.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: $userPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.secondary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                Color.primary.opacity(isEditing ? 0.2 : 0.06),
                                lineWidth: 1
                            )
                    )
                    .disabled(isLocked)
                    .opacity(isLocked ? 0.7 : 1.0)
                    .onChange(of: userPrompt) { _, _ in
                        if !isLocked && !userPrompt.isEmpty && !isEditing {
                            isEditing = true
                        }
                    }

                // Action buttons
                HStack(spacing: 8) {
                    if isLocked {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.8))
                        Spacer()
                        Button("Edit") {
                            stashedPrompt = userPrompt
                            isLocked = false
                            PromptConfig.isUserPromptLocked = false
                            isEditing = true
                        }
                        .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        Button("Clear") {
                            userPrompt = ""
                            PromptConfig.userPrompt = ""
                            isLocked = false
                            PromptConfig.isUserPromptLocked = false
                            isEditing = false
                        }
                        .font(.caption).buttonStyle(.bordered).controlSize(.small)
                    } else if isEditing {
                        Spacer()
                        Button("Cancel") {
                            userPrompt = stashedPrompt
                            PromptConfig.userPrompt = stashedPrompt
                            if !stashedPrompt.isEmpty {
                                isLocked = true
                                PromptConfig.isUserPromptLocked = true
                            }
                            isEditing = false
                        }
                        .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        Button("Save") {
                            PromptConfig.userPrompt = userPrompt
                            isLocked = true
                            PromptConfig.isUserPromptLocked = true
                            isEditing = false
                        }
                        .font(.caption).buttonStyle(.borderedProminent).controlSize(.small)
                    } else {
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - How it works Section

    private var howItWorksSection: some View {
        SettingsSection(icon: "lightbulb", title: "How it works") {
            VStack(alignment: .leading, spacing: 6) {
                infoRow("Each scene has its own prompt, temperature, and output style.")
                infoRow("Global Preferences apply to every scene as a supplement.")
                infoRow("Example: \"Formal tone\" globally + Email scene → formal emails.", italic: true)
            }
        }
    }

    // MARK: - Helpers

    private func infoRow(_ text: String, italic: Bool = false) -> some View {
        Group {
            if italic {
                Text(text)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(text)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadGlobalPreferences() {
        let saved = PromptConfig.userPrompt
        if !saved.isEmpty {
            userPrompt = saved
            isLocked = true
            if !PromptConfig.isUserPromptLocked {
                PromptConfig.isUserPromptLocked = true
            }
        }
    }

    private func duplicateMode(_ mode: Mode) {
        let copy = Mode(
            id: UUID(),
            name: "\(mode.name) Copy",
            icon: mode.icon,
            isBuiltin: false,
            sttModel: mode.sttModel,
            language: mode.language,
            polishEnabled: mode.polishEnabled,
            polishModel: mode.polishModel,
            systemPrompt: mode.systemPrompt,
            userPrompt: mode.userPrompt,
            temperature: mode.temperature,
            autoPaste: mode.autoPaste,
            outputStyleId: mode.outputStyleId,
            shortcutIndex: nil
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modeManager.addMode(copy)
        }
        // Open editor for the copy so user can rename
        editingMode = copy
    }
}
