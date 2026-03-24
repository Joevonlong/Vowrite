import VowriteKit
import SwiftUI

// MARK: - Personalization Page

struct PersonalizationPageView: View {
    @State private var userPrompt = PromptConfig.userPrompt
    @State private var isLocked = PromptConfig.isUserPromptLocked
    @State private var isEditing = false
    @State private var stashedPrompt = ""
    @State private var selectedPresetID: String? = nil
    @State private var showReplaceAlert = false
    @State private var pendingPreset: PreferencePreset? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personalization")
                    .font(.system(size: 24, weight: .bold))

                // Your Preferences
                SettingsSection(icon: "person.text.rectangle", title: "Your Preferences") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Customize how your voice input is polished. Examples: \"Technical terms keep English\", \"Use Arabic numerals\", \"Formal business tone\"")
                            .font(.caption).foregroundColor(.secondary)

                        TextEditor(text: $userPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 150)
                            .border(Color.secondary.opacity(0.3))
                            .disabled(isLocked)
                            .opacity(isLocked ? 0.6 : 1.0)
                            .onChange(of: userPrompt) { _, _ in
                                selectedPresetID = nil
                                if !isLocked && !userPrompt.isEmpty && !isEditing {
                                    isEditing = true
                                }
                            }

                        // Action buttons
                        HStack(spacing: 8) {
                            if isLocked {
                                Label("Saved", systemImage: "lock.fill")
                                    .font(.caption).foregroundColor(.secondary)
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
                                    selectedPresetID = nil
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

                // Quick Presets
                SettingsSection(icon: "sparkles.rectangle.stack", title: "Quick Presets") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Click a preset to fill your preferences. You can edit before saving.")
                            .font(.caption).foregroundColor(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(PreferencePreset.presets) { preset in
                                Button {
                                    applyPreset(preset)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: preset.icon).font(.title2)
                                            .foregroundColor(selectedPresetID == preset.id ? .white : .accentColor)
                                        Text(preset.name).font(.caption)
                                            .fontWeight(selectedPresetID == preset.id ? .semibold : .regular)
                                            .foregroundColor(selectedPresetID == preset.id ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 70)
                                    .background(selectedPresetID == preset.id ? Color.accentColor : Color.secondary.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // How it works
                SettingsSection(icon: "lightbulb", title: "How it works") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your preferences are added to every mode's AI prompt.")
                            .font(.callout)
                        Text("They complement mode-specific formatting (like Email or Code Comment), not override it.")
                            .font(.callout).foregroundColor(.secondary)
                        Text("Example: \"Formal tone\" here + Email mode → formal email.")
                            .font(.callout).foregroundColor(.secondary).italic()
                    }
                }
            }
            .padding(32)
        }
        .alert("Replace current preferences?", isPresented: $showReplaceAlert) {
            Button("Replace") {
                if let preset = pendingPreset {
                    fillPreset(preset)
                }
                pendingPreset = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPreset = nil
            }
        } message: {
            Text("This will replace your current preference text with the preset.")
        }
        .onAppear {
            let saved = PromptConfig.userPrompt
            if !saved.isEmpty && PromptConfig.isUserPromptLocked {
                userPrompt = saved
                isLocked = true
            } else if !saved.isEmpty {
                userPrompt = saved
                isLocked = true
                PromptConfig.isUserPromptLocked = true
            }
        }
    }

    private func applyPreset(_ preset: PreferencePreset) {
        let current = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty {
            pendingPreset = preset
            showReplaceAlert = true
        } else {
            fillPreset(preset)
        }
    }

    private func fillPreset(_ preset: PreferencePreset) {
        if isLocked {
            isLocked = false
            PromptConfig.isUserPromptLocked = false
        }
        userPrompt = preset.promptText
        PromptConfig.userPrompt = preset.promptText
        selectedPresetID = preset.id
        isEditing = true
    }
}
