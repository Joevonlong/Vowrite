import Foundation

@MainActor
public final class ModeManager: ObservableObject {
    public static let shared = ModeManager()

    nonisolated private static let modesKey = "vowriteModes"
    nonisolated private static let currentModeIdKey = "vowriteCurrentModeId"
    nonisolated private static let defaultModeId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")! // Clean mode

    @Published public var modes: [Mode] {
        didSet { saveModes() }
    }

    @Published public var currentModeId: UUID {
        didSet { VowriteStorage.defaults.set(currentModeId.uuidString, forKey: Self.currentModeIdKey) }
    }

    public var currentMode: Mode {
        modes.first { $0.id == currentModeId } ?? modes[0]
    }

    private init() {
        // Load saved modes or use builtins
        if let data = VowriteStorage.defaults.data(forKey: Self.modesKey),
           let saved = try? JSONDecoder().decode([Mode].self, from: data),
           !saved.isEmpty {
            self.modes = Self.mergeBuiltins(saved: saved)
        } else {
            self.modes = Mode.builtinModes
        }

        // Load current mode selection
        if let idStr = VowriteStorage.defaults.string(forKey: Self.currentModeIdKey),
           let id = UUID(uuidString: idStr) {
            self.currentModeId = id
        } else {
            self.currentModeId = Self.defaultModeId
        }
    }

    /// Ensure all builtin modes exist (user may have customized them)
    private static func mergeBuiltins(saved: [Mode]) -> [Mode] {
        var result = saved
        for builtin in Mode.builtinModes {
            if !result.contains(where: { $0.id == builtin.id }) {
                result.insert(builtin, at: 0)
            }
        }
        return result
    }

    public func select(_ mode: Mode) {
        currentModeId = mode.id
    }

    public func addMode(_ mode: Mode) {
        modes.append(mode)
    }

    public func updateMode(_ mode: Mode) {
        if let idx = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[idx] = mode
        }
    }

    public func deleteMode(_ mode: Mode) {
        guard !mode.isBuiltin else { return }
        modes.removeAll { $0.id == mode.id }
        if currentModeId == mode.id {
            currentModeId = Self.defaultModeId
        }
    }

    /// Reload all data from UserDefaults.
    /// Used by iOS keyboard extension: user may have changed config in Container App.
    public func reload() {
        if let data = VowriteStorage.defaults.data(forKey: Self.modesKey),
           let saved = try? JSONDecoder().decode([Mode].self, from: data),
           !saved.isEmpty {
            self.modes = Self.mergeBuiltins(saved: saved)
        }

        if let idStr = VowriteStorage.defaults.string(forKey: Self.currentModeIdKey),
           let id = UUID(uuidString: idStr) {
            self.currentModeId = id
        }
    }

    public func resetBuiltinMode(_ mode: Mode) {
        guard mode.isBuiltin,
              let original = Mode.builtinModes.first(where: { $0.id == mode.id }),
              let idx = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[idx] = original
    }

    private func saveModes() {
        if let data = try? JSONEncoder().encode(modes) {
            VowriteStorage.defaults.set(data, forKey: Self.modesKey)
        }
    }

    // MARK: - Thread-safe access for services

    /// Thread-safe access to current mode config. Reads directly from UserDefaults.
    nonisolated public static var currentModeConfig: ModeConfig {
        let currentId: UUID
        if let idStr = VowriteStorage.defaults.string(forKey: currentModeIdKey),
           let id = UUID(uuidString: idStr) {
            currentId = id
        } else {
            currentId = defaultModeId
        }

        // Try to load from saved modes
        if let data = VowriteStorage.defaults.data(forKey: modesKey),
           let modes = try? JSONDecoder().decode([Mode].self, from: data),
           let mode = modes.first(where: { $0.id == currentId }) {
            return ModeConfig(from: mode)
        }

        // Fall back to builtins
        if let mode = Mode.builtinModes.first(where: { $0.id == currentId }) {
            return ModeConfig(from: mode)
        }

        // Ultimate fallback: Clean mode
        return ModeConfig(from: Mode.builtinModes[1])
    }
}

/// Lightweight value type for thread-safe service access
public struct ModeConfig {
    public let polishEnabled: Bool
    public let polishModel: String?
    public let sttModel: String?
    public let language: String?
    public let systemPrompt: String
    public let userPrompt: String
    public let temperature: Double
    public let autoPaste: Bool
    public let modeName: String
    public let outputStyleId: UUID?
    // F-063: Translation mode flags
    public let isTranslation: Bool
    public let targetLanguage: String?

    public init(from mode: Mode) {
        self.polishEnabled = mode.polishEnabled
        self.polishModel = mode.polishModel
        self.sttModel = mode.sttModel
        self.language = mode.language
        self.systemPrompt = mode.systemPrompt
        self.userPrompt = mode.userPrompt
        self.temperature = mode.temperature
        self.autoPaste = mode.autoPaste
        self.modeName = mode.name
        self.outputStyleId = mode.outputStyleId
        self.isTranslation = mode.isTranslation
        self.targetLanguage = mode.targetLanguage
    }

    /// Returns a copy with the output style overridden.
    /// Used by iOS keyboard extension when user selects a style independent of mode.
    public func withStyleOverride(_ styleId: UUID?) -> ModeConfig {
        ModeConfig(
            polishEnabled: polishEnabled, polishModel: polishModel, sttModel: sttModel,
            language: language, systemPrompt: systemPrompt, userPrompt: userPrompt,
            temperature: temperature, autoPaste: autoPaste, modeName: modeName,
            outputStyleId: styleId,
            isTranslation: isTranslation, targetLanguage: targetLanguage
        )
    }

    private init(polishEnabled: Bool, polishModel: String?, sttModel: String?,
                 language: String?, systemPrompt: String, userPrompt: String,
                 temperature: Double, autoPaste: Bool, modeName: String,
                 outputStyleId: UUID?,
                 isTranslation: Bool, targetLanguage: String?) {
        self.polishEnabled = polishEnabled
        self.polishModel = polishModel
        self.sttModel = sttModel
        self.language = language
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.temperature = temperature
        self.autoPaste = autoPaste
        self.modeName = modeName
        self.outputStyleId = outputStyleId
        self.isTranslation = isTranslation
        self.targetLanguage = targetLanguage
    }
}
