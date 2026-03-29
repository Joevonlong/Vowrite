import Foundation

/// Built-in recording indicator presets.
public enum IndicatorPreset: String, CaseIterable, Codable, Sendable {
    case classicBar
    case orbPulse

    public var displayName: String {
        switch self {
        case .classicBar: return "Classic Bar"
        case .orbPulse: return "Orb Pulse"
        }
    }

    public var iconName: String {
        switch self {
        case .classicBar: return "waveform"
        case .orbPulse: return "circle.radiowaves.left.and.right"
        }
    }

    private static let key = "indicatorPreset"

    public static var current: IndicatorPreset {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let preset = IndicatorPreset(rawValue: raw) else { return .classicBar }
            return preset
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
