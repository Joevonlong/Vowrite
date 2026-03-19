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
        didSet { UserDefaults.standard.set(currentModeId.uuidString, forKey: Self.currentModeIdKey) }
    }

    public var currentMode: Mode {
        modes.first { $0.id == currentModeId } ?? modes[0]
    }

    private init() {
        // Load saved modes or use builtins
        if let data = UserDefaults.standard.data(forKey: Self.modesKey),
           let saved = try? JSONDecoder().decode([Mode].self, from: data),
           !saved.isEmpty {
            self.modes = Self.mergeBuiltins(saved: saved)
        } else {
            self.modes = Mode.builtinModes
        }

        // Load current mode selection
        if let idStr = UserDefaults.standard.string(forKey: Self.currentModeIdKey),
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

    public func resetBuiltinMode(_ mode: Mode) {
        guard mode.isBuiltin,
              let original = Mode.builtinModes.first(where: { $0.id == mode.id }),
              let idx = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        modes[idx] = original
    }

    private func saveModes() {
        if let data = try? JSONEncoder().encode(modes) {
            UserDefaults.standard.set(data, forKey: Self.modesKey)
        }
    }

    // MARK: - Thread-safe access for services

    /// Thread-safe access to current mode config. Reads directly from UserDefaults.
    nonisolated public static var currentModeConfig: ModeConfig {
        let currentId: UUID
        if let idStr = UserDefaults.standard.string(forKey: currentModeIdKey),
           let id = UUID(uuidString: idStr) {
            currentId = id
        } else {
            currentId = defaultModeId
        }

        // Try to load from saved modes
        if let data = UserDefaults.standard.data(forKey: modesKey),
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
    }
}
