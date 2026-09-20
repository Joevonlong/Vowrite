import Combine
import Foundation

public enum BuiltinVoiceEffectResources {
    public static var bundleURL: URL? { bundle?.bundleURL }

    static func url(forResource name: String, withExtension extensionName: String) -> URL? {
        bundle?.url(forResource: name, withExtension: extensionName)
    }

    private static var bundle: Bundle? {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let resources = Bundle.main.resourceURL else { return nil }
            let url = resources.appendingPathComponent("VowriteMac_BuiltinVoiceEffects.bundle", isDirectory: true)
            return Bundle(url: url)
        }
        return Bundle.module
    }
}

public struct BuiltinVoiceEffect: Codable, Identifiable, Equatable, Sendable {
    public enum Shape: String, Codable, Sendable { case wide, compact }

    public let id: Int
    public let number: String
    public let name: String
    public let english: String
    public let category: String
    public let description: String
    public let motion: String
    public let shape: Shape
}

public enum BuiltinVoiceEffectCatalog {
    public static let all: [BuiltinVoiceEffect] = {
        guard let url = BuiltinVoiceEffectResources.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let effects = try? JSONDecoder().decode([BuiltinVoiceEffect].self, from: data),
              effects.map(\.id) == Array(1...80) else { return [] }
        return effects
    }()

    public static let categories: [String] = {
        var seen: Set<String> = []
        return all.compactMap { seen.insert($0.category).inserted ? $0.category : nil }
    }()

    public static func effect(id: Int?) -> BuiltinVoiceEffect? {
        guard let id, (1...80).contains(id) else { return nil }
        return all.first { $0.id == id }
    }
}

public final class BuiltinVoiceEffectSelection: ObservableObject {
    public static let key = "builtinVoiceEffectID"
    public static let shared = BuiltinVoiceEffectSelection()

    @Published public private(set) var selectedID: Int?
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.integer(forKey: Self.key)
        selectedID = BuiltinVoiceEffectCatalog.effect(id: stored) == nil ? nil : stored
        if selectedID == nil { defaults.removeObject(forKey: Self.key) }
    }

    public var selectedEffect: BuiltinVoiceEffect? { BuiltinVoiceEffectCatalog.effect(id: selectedID) }

    public func select(_ id: Int?) {
        selectedID = BuiltinVoiceEffectCatalog.effect(id: id)?.id
        if let selectedID { defaults.set(selectedID, forKey: Self.key) }
        else { defaults.removeObject(forKey: Self.key) }
    }
}

public struct BuiltinVoiceEffectFrame: Equatable, Sendable {
    public enum Phase: String, Sendable { case idle, listening, processing, done, error }
    public enum Theme: String, Sendable { case dark, light }

    public let phase: Phase
    public let time: Double
    public let level: Double
    public let reducedMotion: Bool
    public let theme: Theme

    public init(phase: Phase, time: Double, level: Double, reducedMotion: Bool, theme: Theme = .dark) {
        self.phase = phase
        self.time = max(0, time)
        self.level = min(1, max(0, level))
        self.reducedMotion = reducedMotion
        self.theme = theme
    }
}
