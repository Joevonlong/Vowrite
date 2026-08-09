import XCTest
@testable import VowriteKit

final class SpeculativePolishProviderRoutingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RecordingURLProtocol.reset()
    }

    override func tearDown() {
        RecordingURLProtocol.reset()
        super.tearDown()
    }

    func testClaudePrepareAndExecuteSkipChatCompletionsAndUseNativeMessages() async throws {
        let configuration = APIEndpointConfiguration(
            provider: .claude,
            model: "claude-sonnet-5",
            baseURL: "https://api.anthropic.test/v1"
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [RecordingURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        let nativeService = ClaudePolishService(session: session)
        let ordinaryService = AIPolishService(
            configurationProvider: { configuration },
            credentialProvider: { _ in "test-claude-key" },
            claudeService: nativeService,
            session: session
        )
        let speculative = SpeculativePolish(
            configurationProvider: { configuration },
            fallbackPolish: { text, modeConfig, promptContext in
                try await ordinaryService.polish(
                    text: text,
                    modeConfig: modeConfig,
                    promptContext: promptContext
                )
            }
        )

        let modeConfig = ModeConfig(from: Mode.builtinModes[1])
        speculative.warmUpConnection()
        speculative.prepare(modeConfig: modeConfig)

        XCTAssertNil(speculative.preparedRequestURL)
        XCTAssertTrue(RecordingURLProtocol.requests.isEmpty)

        let result = try await speculative.execute(
            transcript: "hello world",
            modeConfig: modeConfig
        )

        XCTAssertEqual(result, "Native Claude response")
        let requests = RecordingURLProtocol.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.absoluteString, "https://api.anthropic.test/v1/messages")
        XCTAssertFalse(requests.contains { $0.url?.path.contains("/chat/completions") == true })
    }

    func testCompatibleProvidersKeepPreparedOpenAIPath() {
        for provider in [APIProvider.openai, .groq, .deepseek, .kimi, .gemini] {
            XCTAssertEqual(
                SpeculativePolish.transportStrategy(for: provider),
                .preparedOpenAICompatible,
                "\(provider.providerID) should keep speculative preparation"
            )
        }
    }

    func testSameProviderReconfigurationInvalidatesPreparedIdentity() {
        let original = SpeculativePolish.requestIdentity(
            providerID: "groq",
            baseURL: "https://api.groq.com/openai/v1",
            model: "openai/gpt-oss-120b",
            authMethod: "apiKey",
            credential: "key-a"
        )

        XCTAssertNotEqual(
            original,
            SpeculativePolish.requestIdentity(
                providerID: "groq",
                baseURL: "https://proxy.example/v1",
                model: "openai/gpt-oss-120b",
                authMethod: "apiKey",
                credential: "key-a"
            )
        )
        XCTAssertNotEqual(
            original,
            SpeculativePolish.requestIdentity(
                providerID: "groq",
                baseURL: "https://api.groq.com/openai/v1",
                model: "openai/gpt-oss-20b",
                authMethod: "apiKey",
                credential: "key-a"
            )
        )
        XCTAssertNotEqual(
            original,
            SpeculativePolish.requestIdentity(
                providerID: "groq",
                baseURL: "https://api.groq.com/openai/v1",
                model: "openai/gpt-oss-120b",
                authMethod: "oauth",
                credential: "key-b"
            )
        )
    }
}

private final class RecordingURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var recordedRequests: [URLRequest] = []

    static var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests
    }

    static func reset() {
        lock.lock()
        recordedRequests = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.recordedRequests.append(request)
        Self.lock.unlock()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        let body = """
        data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Native Claude response"}}

        data: {"type":"message_stop"}

        """.data(using: .utf8)!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
