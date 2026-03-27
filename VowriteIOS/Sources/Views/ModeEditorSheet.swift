import SwiftUI
import VowriteKit

struct ModeEditorSheet: View {
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
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
