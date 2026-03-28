import Foundation

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

    public func sttModelDescription(_ modelID: String) -> String? {
        stt?.models.first { $0.id == modelID }?.description
    }

    public func polishModelDescription(_ modelID: String) -> String? {
        polish?.models.first { $0.id == modelID }?.description
    }
}

// MARK: - Providers File Root

struct ProvidersFile: Codable {
    let version: Int
    let providers: [ProviderDefinition]
}
