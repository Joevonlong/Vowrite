import Foundation

// MARK: - JSONValue (F-073: flexible typed value for per-model request overrides)

/// A minimal Codable JSON value type used to decode arbitrary override payloads
/// from `providers.json` (e.g. `polishOverrides`). Supports all JSON value kinds.
public enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try container.encode(s)
        case .int(let i):     try container.encode(i)
        case .double(let d):  try container.encode(d)
        case .bool(let b):    try container.encode(b)
        case .null:           try container.encodeNil()
        case .array(let a):   try container.encode(a)
        case .object(let o):  try container.encode(o)
        }
    }

    /// Converts this `JSONValue` to a plain Swift value compatible with
    /// `JSONSerialization.data(withJSONObject:)`.
    public func toAny() -> Any {
        switch self {
        case .string(let s):  return s
        case .int(let i):     return i
        case .double(let d):  return d
        case .bool(let b):    return b
        case .null:           return NSNull()
        case .array(let a):   return a.map { $0.toAny() }
        case .object(let o):  return o.mapValues { $0.toAny() }
        }
    }
}

// MARK: - Provider Definition (decoded from providers.json)

public struct ProviderDefinition: Codable, Identifiable {
    public let id: String
    public let name: String
    public let baseURL: String
    public let isOpenAICompatible: Bool?
    public let platformFilter: String?
    public let auth: AuthConfig
    public let capabilities: Capabilities
    public let sttAdapter: String?
    public let sttNote: String?
    public let headers: [String: String]?
    public let stt: PipelineConfig?
    public let polish: PipelineConfig?

    public struct AuthConfig: Codable {
        public let style: String
        public let keyPlaceholder: String?
        public let keyURL: String?
        public let requiresKey: Bool?
        public let supportsOAuth: Bool?
        public let oauthLabel: String?
    }

    public struct Capabilities: Codable {
        public let stt: Bool
        public let polish: Bool
    }

    public struct PipelineConfig: Codable {
        public let defaultModel: String
        public let models: [ModelDef]
    }

    public struct ModelDef: Codable, Identifiable {
        public let id: String
        public let description: String?
        /// F-073: Optional request body overrides merged into the polish payload
        /// before the HTTP call. Prevents server-side thinking latency on
        /// reasoning models that default thinking ON.
        public let polishOverrides: [String: JSONValue]?
    }

    // MARK: - Convenience

    public var requiresAPIKey: Bool {
        auth.requiresKey ?? (auth.style != "none")
    }

    public var defaultSTTModel: String {
        stt?.defaultModel ?? ""
    }

    public var defaultPolishModel: String {
        polish?.defaultModel ?? ""
    }

    public var presetSTTModels: [String] {
        stt?.models.map(\.id) ?? []
    }

    public var presetPolishModels: [String] {
        polish?.models.map(\.id) ?? []
    }

    public var hasSTTSupport: Bool {
        capabilities.stt
    }

    public var hasPolishSupport: Bool {
        capabilities.polish
    }

    public var supportsOAuth: Bool {
        auth.supportsOAuth ?? false
    }

    public var oauthLabel: String? {
        auth.oauthLabel
    }

    public func sttModelDescription(_ modelID: String) -> String? {
        stt?.models.first { $0.id == modelID }?.description
    }

    public func polishModelDescription(_ modelID: String) -> String? {
        polish?.models.first { $0.id == modelID }?.description
    }

    /// F-073: Returns the `polishOverrides` for the given model ID, or nil if
    /// the model is not listed or carries no overrides.
    public func polishOverrides(for modelID: String) -> [String: JSONValue]? {
        polish?.models.first { $0.id == modelID }?.polishOverrides
    }
}

// MARK: - Providers File Root

struct ProvidersFile: Codable {
    let version: Int
    let providers: [ProviderDefinition]
}
