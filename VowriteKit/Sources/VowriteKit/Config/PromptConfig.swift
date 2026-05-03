import Foundation

public enum PromptConfig {
    private static let legacySystemPromptKey = "promptSystemPrompt"
    private static let userPromptKey = "promptUserPrompt"

    /// The base system prompt. Loaded from bundle resource
    /// `Resources/Prompts/polish.system.md` at first access and cached for the
    /// process lifetime. The file is the canonical source of truth — Swift code
    /// does not own this content. Developers edit the `.md` and rebuild.
    ///
    /// Not user-editable at runtime. The user-facing customization layer is
    /// `PromptConfig.userPrompt` (and per-mode prompts) — see
    /// `SpeculativePolish.buildSystemPrompt(for:)` for the cascade order.
    public static var systemPrompt: String { PromptResources.polishSystem }

    public static var userPrompt: String {
        get { VowriteStorage.defaults.string(forKey: userPromptKey) ?? "" }
        set { VowriteStorage.defaults.set(newValue, forKey: userPromptKey) }
    }

    public static var isUserPromptLocked: Bool {
        get { VowriteStorage.defaults.bool(forKey: "promptUserPromptLocked") }
        set { VowriteStorage.defaults.set(newValue, forKey: "promptUserPromptLocked") }
    }

    /// Remove any legacy user-modified system prompt from UserDefaults.
    /// Call once at app launch to clean up.
    public static func migrateLegacySystemPrompt() {
        VowriteStorage.defaults.removeObject(forKey: legacySystemPromptKey)
    }

    public static var effectiveSystemPrompt: String {
        let base = systemPrompt
        let user = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if user.isEmpty {
            return base
        }
        return "\(base)\n\n---\nUser preferences:\n\(user)"
    }

    /// Translation-mode system prompt template. `{targetLanguageName}` is
    /// substituted with the resolved `SupportedLanguage.displayName` at
    /// request-build time (see `SpeculativePolish.buildSystemPrompt`).
    ///
    /// Loaded from `Resources/Prompts/translate.system.md`. Translation mode
    /// deliberately skips `PromptContext` expansion so the user's clipboard or
    /// selected text is never sent to the LLM as content to translate.
    public static var translationSystemPromptTemplate: String {
        PromptResources.translateSystem
    }
}

// MARK: - Bundle-backed resource loading

/// Loads the base prompt files from the VowriteKit bundle. Both files are
/// shipped as bundle resources via `Package.swift` (`.process("Resources")`),
/// so the lookups must succeed in any built copy of the app — a missing file
/// is a packaging bug, not a runtime condition we can recover from.
private enum PromptResources {
    static let polishSystem: String = load("polish.system", ext: "md")
    static let translateSystem: String = load("translate.system", ext: "md")

    private static func load(_ name: String, ext: String) -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: ext,
            subdirectory: "Prompts"
        ) ?? Bundle.module.url(forResource: name, withExtension: ext) else {
            fatalError("VowriteKit bundle is missing required prompt resource: Prompts/\(name).\(ext). Verify Package.swift includes 'Resources' and the file ships in the built bundle.")
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            fatalError("Failed to read prompt resource Prompts/\(name).\(ext): \(error)")
        }
    }
}
