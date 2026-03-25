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
    private var canSave: Bool { !draft.name.trimmingCharacters(in: .whitespaces).isEmpty }

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
            .frame(minWidth: 500, idealWidth: 540, minHeight: 560, idealHeight: 620)
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
