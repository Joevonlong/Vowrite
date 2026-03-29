import VowriteKit
import SwiftUI

// MARK: - Vocabulary Page

struct VocabularyPageView: View {
    @ObservedObject private var vocabManager = VocabularyManager.shared
    @ObservedObject private var replacementManager = ReplacementManager.shared
    @State private var newWord = ""

    // Corrections state
    @State private var newTrigger = ""
    @State private var newReplacement = ""
    @State private var editingRuleId: UUID? = nil
    @State private var editTrigger = ""
    @State private var editReplacement = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Vocabulary")
                    .font(.system(size: 24, weight: .bold))

                vocabularySection
                correctionsSection
            }
            .padding(32)
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

    // MARK: - Corrections Section (F-051)

    private var correctionsSection: some View {
        SettingsSection(icon: "arrow.2.squarepath", title: "Text Corrections") {
            VStack(alignment: .leading, spacing: VW.Spacing.xl) {
                Text("Auto-correct misrecognized words or expand voice shortcuts into full text. Applied after transcription and after AI polish.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Header row
                if !replacementManager.rules.isEmpty {
                    HStack(spacing: 0) {
                        Text("When recognized as")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 180, alignment: .leading)
                        Text("Replace with")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.bottom, 2)
                }

                // Existing rules
                ForEach(replacementManager.rules) { rule in
                    correctionRow(rule: rule)
                    if rule.id != replacementManager.rules.last?.id {
                        Divider().opacity(0.3)
                    }
                }

                // Add new rule
                HStack(spacing: VW.Spacing.sm) {
                    TextField("Trigger word...", text: $newTrigger)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(width: 172)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    TextField("Replacement...", text: $newReplacement)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                        .onSubmit { addCorrection() }

                    Button {
                        addCorrection()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty ||
                              newReplacement.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Text("Examples: \"伏莱特\" → \"Vowrite\"  ·  \"我的邮箱\" → \"hello@example.com\"")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }

    private func correctionRow(rule: ReplacementRule) -> some View {
        HStack(spacing: VW.Spacing.sm) {
            if editingRuleId == rule.id {
                // Editing state
                TextField("", text: $editTrigger)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(width: 172)
                    .background(RoundedRectangle(cornerRadius: 4).fill(VW.Colors.Background.elevated))
                    .onSubmit { commitCorrectionEdit() }

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                TextField("", text: $editReplacement)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(VW.Colors.Background.elevated))
                    .onSubmit { commitCorrectionEdit() }

                Spacer()

                Button { commitCorrectionEdit() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)

                Button { editingRuleId = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                // Display state
                Text(rule.trigger)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 172, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(rule.replacement)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    editTrigger = rule.trigger
                    editReplacement = rule.replacement
                    editingRuleId = rule.id
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(VW.Anim.easeQuick) {
                        replacementManager.remove(rule)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func addCorrection() {
        let trigger = newTrigger.trimmingCharacters(in: .whitespaces)
        let replacement = newReplacement.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !replacement.isEmpty else { return }
        withAnimation(VW.Anim.easeQuick) {
            replacementManager.add(trigger: trigger, replacement: replacement)
        }
        newTrigger = ""
        newReplacement = ""
    }

    private func commitCorrectionEdit() {
        guard let ruleId = editingRuleId else { return }
        let trigger = editTrigger.trimmingCharacters(in: .whitespaces)
        let replacement = editReplacement.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty, !replacement.isEmpty else { return }
        guard var rule = replacementManager.rules.first(where: { $0.id == ruleId }) else { return }
        rule.trigger = trigger
        rule.replacement = replacement
        replacementManager.update(rule)
        editingRuleId = nil
    }
}