import VowriteKit
import SwiftUI

// MARK: - Personalization Page

struct PersonalizationPageView: View {
    @ObservedObject private var modeManager = ModeManager.shared

    // Global Preferences state
    //
    // `userPrompt` is the value bound to the editor. When `isEditing == false`
    // it mirrors the committed (saved) value and the editor is hard-disabled.
    // While editing, it is the in-progress draft; `stashedPrompt` is the value
    // we revert to on Cancel. Nothing is written to PromptConfig until Save.
    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isEditing = false
    @State private var stashedPrompt = ""
    @State private var showDiscardConfirm = false
    @State private var showClearConfirm = false

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
                    // Hard gate: nothing the user types reaches the editor unless
                    // they explicitly entered edit mode. Stray clicks / focus
                    // changes cannot mutate the committed prompt.
                    .disabled(!isEditing)
                    .opacity(isEditing ? 1.0 : 0.7)

                // Action buttons — explicit Edit/Save/Cancel only.
                HStack(spacing: 8) {
                    if isEditing {
                        Spacer()
                        Button("Cancel") { requestCancel() }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                            .keyboardShortcut(.cancelAction)
                        Button("Save") { commitSave() }
                            .font(.caption).buttonStyle(.borderedProminent).controlSize(.small)
                            .keyboardShortcut(.defaultAction)
                            .disabled(userPrompt == stashedPrompt)
                    } else if userPrompt.isEmpty {
                        Spacer()
                        Button("Add Preferences") { beginEdit() }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                    } else {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.8))
                        Spacer()
                        Button("Edit") { beginEdit() }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                        Button("Clear") { showClearConfirm = true }
                            .font(.caption).buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .confirmationDialog(
                    "Discard your changes?",
                    isPresented: $showDiscardConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Discard Changes", role: .destructive) { discardEdit() }
                    Button("Keep Editing", role: .cancel) {}
                } message: {
                    Text("Unsaved edits to your global preferences will be lost.")
                }
                .confirmationDialog(
                    "Clear your global preferences?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { clearPrompt() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes your saved global preferences. Built-in scenes are unaffected.")
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
        userPrompt = PromptConfig.userPrompt
        isEditing = false
        // Keep the persisted lock flag in sync with whether anything is saved.
        // The flag is a legacy signal used by some surfaces (e.g. preset apply)
        // to indicate "user has committed a value".
        PromptConfig.isUserPromptLocked = !userPrompt.isEmpty
    }

    // MARK: - Edit lifecycle

    private func beginEdit() {
        stashedPrompt = userPrompt
        isEditing = true
    }

    private func requestCancel() {
        if userPrompt != stashedPrompt {
            showDiscardConfirm = true
        } else {
            discardEdit()
        }
    }

    private func discardEdit() {
        userPrompt = stashedPrompt
        isEditing = false
    }

    private func commitSave() {
        let trimmed = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        userPrompt = trimmed
        PromptConfig.userPrompt = trimmed
        PromptConfig.isUserPromptLocked = !trimmed.isEmpty
        stashedPrompt = trimmed
        isEditing = false
    }

    private func clearPrompt() {
        userPrompt = ""
        stashedPrompt = ""
        PromptConfig.userPrompt = ""
        PromptConfig.isUserPromptLocked = false
        isEditing = false
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
