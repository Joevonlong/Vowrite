import Foundation

/// F-077: A preset that pre-fills the Mode editor. Picking a template does not
/// create a special mode type — it just seeds a plain user `Mode` (see
/// `Mode.swift`) with a name/icon/systemPrompt starting point. The resulting
/// Mode has every existing Mode capability (⌃1-9 hotkey, edit, delete, etc.).
public struct ModeTemplate: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let icon: String          // SF Symbol name
    public let summary: String       // one-line description shown in the picker
    public let systemPrompt: String
    /// Whether this template's prompt operates on selected text (`{selected}`).
    /// Informational for the UI; every builtin template with this set to
    /// `true` embeds `{selected}` in its `systemPrompt`.
    public let requiresSelection: Bool

    public init(
        id: String, name: String, icon: String, summary: String,
        systemPrompt: String, requiresSelection: Bool
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.summary = summary
        self.systemPrompt = systemPrompt
        self.requiresSelection = requiresSelection
    }

    // Shared trailer appended to every selection-based template below: the
    // selected text is the content to transform, the spoken transcript is
    // optional guidance layered on top. Mirrors the builtin Command mode's
    // {text}/{selected} phrasing (see Mode.builtinModes).
    private static func selectionPrompt(_ instruction: String) -> String {
        "\(instruction)\n\nText:\n{selected}\n\nSpoken guidance (optional, follow if given): {text}"
    }

    public static let builtins: [ModeTemplate] = [
        ModeTemplate(
            id: "improve-writing",
            name: "Improve Writing",
            icon: "wand.and.stars",
            summary: "Polish clarity, flow, and word choice",
            systemPrompt: selectionPrompt(
                "Improve the clarity, flow, and word choice of the following text "
                + "without changing its meaning or tone. Fix awkward phrasing and "
                + "tighten loose sentences. Preserve all facts, names, and figures "
                + "exactly. Output only the improved text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "fix-grammar",
            name: "Fix Grammar",
            icon: "checkmark.seal",
            summary: "Correct grammar, spelling, and punctuation",
            systemPrompt: selectionPrompt(
                "Fix grammar, spelling, and punctuation errors in the following "
                + "text. Do not change the wording, tone, or meaning beyond what "
                + "correctness requires. Output only the corrected text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-professional",
            name: "Make Professional",
            icon: "briefcase",
            summary: "Rewrite in a businesslike tone",
            systemPrompt: selectionPrompt(
                "Rewrite the following text in a professional, businesslike tone. "
                + "Remove slang and casual phrasing; keep it clear and precise. "
                + "Preserve all facts and intent. Output only the rewritten text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-casual",
            name: "Make Casual",
            icon: "bubble.left",
            summary: "Rewrite in a relaxed, conversational tone",
            systemPrompt: selectionPrompt(
                "Rewrite the following text in a relaxed, conversational tone, as "
                + "if talking to a friend. Keep it natural and easy to read. "
                + "Preserve all facts and intent. Output only the rewritten text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-confident",
            name: "Make Confident",
            icon: "bolt.fill",
            summary: "Remove hedges, sound direct",
            systemPrompt: selectionPrompt(
                "Rewrite the following text to sound more confident and direct. "
                + "Remove hedges like \"maybe\", \"I think\", \"kind of\", and "
                + "qualifiers that weaken the point. Preserve all facts and "
                + "intent. Output only the rewritten text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-friendly",
            name: "Make Friendly",
            icon: "face.smiling",
            summary: "Warm up a blunt or cold tone",
            systemPrompt: selectionPrompt(
                "Rewrite the following text in a warmer, friendlier tone. Soften "
                + "anything that reads as blunt or cold, without losing the "
                + "point. Preserve all facts and intent. Output only the "
                + "rewritten text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-longer",
            name: "Make Longer",
            icon: "arrow.up.left.and.arrow.down.right",
            summary: "Expand with detail and context",
            systemPrompt: selectionPrompt(
                "Expand the following text with more detail, context, or "
                + "supporting sentences, without padding or repeating the same "
                + "idea. Keep the original meaning and tone. Output only the "
                + "expanded text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "make-shorter",
            name: "Make Shorter",
            icon: "arrow.down.right.and.arrow.up.left",
            summary: "Cut to the essential meaning",
            systemPrompt: selectionPrompt(
                "Shorten the following text to its essential meaning. Cut "
                + "redundant words and secondary details; keep the core point "
                + "and tone intact. Output only the shortened text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "simplify",
            name: "Simplify",
            icon: "leaf",
            summary: "Plain words, short sentences",
            systemPrompt: selectionPrompt(
                "Simplify the following text: use plain words, short sentences, "
                + "and remove jargon where possible. Preserve the meaning "
                + "exactly. Output only the simplified text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "paraphrase",
            name: "Paraphrase",
            icon: "arrow.triangle.2.circlepath",
            summary: "Reword while keeping the same meaning",
            systemPrompt: selectionPrompt(
                "Rewrite the following text with different wording and sentence "
                + "structure while keeping the exact same meaning. Do not add or "
                + "remove information. Output only the paraphrased text."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "tldr",
            name: "TL;DR",
            icon: "doc.text.magnifyingglass",
            summary: "One-sentence summary of the main point",
            systemPrompt: selectionPrompt(
                "Write a one-sentence TL;DR that captures the main point of the "
                + "following text. Output only that sentence, nothing else."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "summarize-3-bullets",
            name: "Summarize in 3 Bullets",
            icon: "list.bullet",
            summary: "Three key points as bullets",
            systemPrompt: selectionPrompt(
                "Summarize the following text as exactly 3 bullet points, each "
                + "one a distinct key point. Output only the bullets, nothing "
                + "else."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "find-action-items",
            name: "Find Action Items",
            icon: "checklist",
            summary: "Extract concrete tasks as a list",
            systemPrompt: selectionPrompt(
                "Extract every action item from the following text as a bullet "
                + "list. Each bullet is one concrete task; include the owner if "
                + "the text names one. Output only the list — if there are no "
                + "action items, output \"No action items found.\""
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "pros-cons",
            name: "Pros & Cons",
            icon: "plusminus.circle",
            summary: "List pros and cons as two columns",
            systemPrompt: selectionPrompt(
                "List the pros and cons found in or implied by the following "
                + "text, under two headings \"Pros\" and \"Cons\", each as "
                + "bullets. Output only the two lists."
            ),
            requiresSelection: true
        ),
        ModeTemplate(
            id: "eli5",
            name: "Explain Like I'm 5",
            icon: "person.fill.questionmark",
            summary: "Simple terms, short sentences, no jargon",
            systemPrompt: selectionPrompt(
                "Explain the following text in simple terms a five-year-old "
                + "could understand: short sentences, everyday words, simple "
                + "analogies where helpful. Preserve the core meaning. Output "
                + "only the explanation."
            ),
            requiresSelection: true
        )
    ]
}
