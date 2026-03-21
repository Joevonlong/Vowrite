import Foundation

@MainActor
public final class OutputStyleManager: ObservableObject {
    public static let shared = OutputStyleManager()

    nonisolated private static let stylesKey = "vowriteOutputStyles"

    @Published public var styles: [OutputStyle] {
        didSet { saveStyles() }
    }

    private init() {
        if let data = VowriteStorage.defaults.data(forKey: Self.stylesKey),
           let saved = try? JSONDecoder().decode([OutputStyle].self, from: data),
           !saved.isEmpty {
            self.styles = Self.mergeBuiltins(saved: saved)
        } else {
            self.styles = OutputStyle.builtinStyles
        }
    }

    /// Ensure all builtin styles exist (user may have customized them)
    private static func mergeBuiltins(saved: [OutputStyle]) -> [OutputStyle] {
        var result = saved
        for builtin in OutputStyle.builtinStyles {
            if !result.contains(where: { $0.id == builtin.id }) {
                result.insert(builtin, at: 0)
            }
        }
        return result
    }

    public func addStyle(_ style: OutputStyle) {
        styles.append(style)
    }

    public func updateStyle(_ style: OutputStyle) {
        if let idx = styles.firstIndex(where: { $0.id == style.id }) {
            styles[idx] = style
        }
    }

    public func deleteStyle(_ style: OutputStyle) {
        guard !style.isBuiltin else { return }
        styles.removeAll { $0.id == style.id }
    }

    /// Reload all data from UserDefaults.
    /// Used by iOS keyboard extension: user may have changed config in Container App.
    public func reload() {
        if let data = VowriteStorage.defaults.data(forKey: Self.stylesKey),
           let saved = try? JSONDecoder().decode([OutputStyle].self, from: data),
           !saved.isEmpty {
            self.styles = Self.mergeBuiltins(saved: saved)
        }
    }

    public func resetBuiltinStyle(_ style: OutputStyle) {
        guard style.isBuiltin,
              let original = OutputStyle.builtinStyles.first(where: { $0.id == style.id }),
              let idx = styles.firstIndex(where: { $0.id == style.id }) else { return }
        styles[idx] = original
    }

    private func saveStyles() {
        if let data = try? JSONEncoder().encode(styles) {
            VowriteStorage.defaults.set(data, forKey: Self.stylesKey)
        }
    }

    // MARK: - Thread-safe access for services

    /// Thread-safe lookup of an output style's template prompt by ID.
    nonisolated public static func templatePrompt(for styleId: UUID?) -> String? {
        guard let styleId = styleId, styleId != OutputStyle.noneId else { return nil }

        if let data = VowriteStorage.defaults.data(forKey: stylesKey),
           let styles = try? JSONDecoder().decode([OutputStyle].self, from: data),
           let style = styles.first(where: { $0.id == styleId }) {
            return style.templatePrompt.isEmpty ? nil : style.templatePrompt
        }

        // Fall back to builtins
        if let style = OutputStyle.builtinStyles.first(where: { $0.id == styleId }) {
            return style.templatePrompt.isEmpty ? nil : style.templatePrompt
        }

        return nil
    }
}
