import AppKit
import Combine
import Foundation
import SwiftUI
import WebKit

@MainActor
public final class BuiltinVoiceEffectSession: NSObject, ObservableObject {
    public enum State: Equatable { case loading, ready, rendered, failed(String) }
    private struct InFlight {
        let revision: Int
        let effectID: Int
        let level: Double
        let phase: String
    }

    @Published public private(set) var state: State = .loading
    @Published public private(set) var webView: WKWebView?
    @Published public private(set) var frameCount = 0
    @Published public private(set) var lastRenderedLevel = 0.0
    @Published public private(set) var lastRenderedPhase = ""

    private let token = UUID().uuidString
    private var pending: (BuiltinVoiceEffect, BuiltinVoiceEffectFrame)?
    private var rendering = false
    private var nextRevision = 0
    private var inFlight: InFlight?
    private var renderTimeout: DispatchWorkItem?

    public override init() {
        super.init()
        configure()
    }

    public func render(effect: BuiltinVoiceEffect, frame: BuiltinVoiceEffectFrame) {
        if webView == nil {
            if case .failed = state { return }
            configure()
        }
        guard state == .ready || state == .rendered, let webView else {
            pending = (effect, frame)
            return
        }
        guard !rendering else {
            pending = (effect, frame)
            return
        }
        rendering = true
        nextRevision += 1
        let revision = nextRevision
        inFlight = InFlight(
            revision: revision,
            effectID: effect.id,
            level: frame.level,
            phase: frame.phase.rawValue
        )
        let arguments: [String: Any] = [
            "id": effect.id,
            "revision": revision,
            "time": frame.time,
            "phase": frame.phase.rawValue,
            "level": frame.level,
            "reducedMotion": frame.reducedMotion,
            "theme": frame.theme.rawValue,
            "shape": effect.shape.rawValue,
        ]
        let timeout = DispatchWorkItem { [weak self, weak webView] in
            guard let self, let webView, self.webView === webView,
                  self.inFlight?.revision == revision else { return }
            self.fail("Built-in Voice Bar did not render the requested frame.")
        }
        renderTimeout?.cancel()
        renderTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: timeout)
        Task { [weak self, weak webView] in
            guard let webView else { return }
            do {
                _ = try await webView.callAsyncJavaScript(
                    "return window.VowriteBuiltinEffects.setState(state)",
                    arguments: ["state": arguments],
                    in: nil,
                    contentWorld: .page
                )
            } catch {
                guard let self, self.webView === webView else { return }
                self.fail(error.localizedDescription)
                return
            }
        }
    }

    public func clear() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "builtinVoiceEffect")
        webView?.stopLoading()
        webView = nil
        pending = nil
        rendering = false
        inFlight = nil
        renderTimeout?.cancel()
        renderTimeout = nil
        state = .loading
    }

    private func configure() {
        guard webView == nil else { return }
        state = .loading
        guard let resourceURL = BuiltinVoiceEffectResources.bundleURL,
              let hostURL = BuiltinVoiceEffectResources.url(forResource: "host", withExtension: "html") else {
            fail("Built-in Voice Bar resources are missing.")
            return
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.add(WeakBuiltinEffectHandler(owner: self), name: "builtinVoiceEffect")

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.setValue(false, forKey: "drawsBackground")
        webView = view

        var components = URLComponents(url: hostURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        guard let url = components?.url else { fail("Built-in Voice Bar host URL is invalid."); return }
        view.loadFileURL(url, allowingReadAccessTo: resourceURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self, weak view] in
            guard let self, let view, self.webView === view, self.state == .loading else { return }
            self.fail("Built-in Voice Bar renderer did not start.")
        }
    }

    fileprivate func receive(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.standardizedFileURL.path == BuiltinVoiceEffectResources.url(forResource: "host", withExtension: "html")?.standardizedFileURL.path,
              let body = message.body as? [String: Any],
              body["token"] as? String == token,
              let type = body["type"] as? String else { return }
        switch type {
        case "ready":
            state = .ready
            if let pending { self.pending = nil; render(effect: pending.0, frame: pending.1) }
        case "frame":
            guard let inFlight,
                  body["revision"] as? Int == inFlight.revision,
                  body["id"] as? Int == inFlight.effectID,
                  let level = body["level"] as? Double,
                  abs(level - inFlight.level) < 0.0001,
                  body["phase"] as? String == inFlight.phase else { return }
            renderTimeout?.cancel()
            renderTimeout = nil
            self.inFlight = nil
            rendering = false
            frameCount = body["frameCount"] as? Int ?? frameCount + 1
            lastRenderedLevel = level
            lastRenderedPhase = inFlight.phase
            state = .rendered
            if let pending { self.pending = nil; render(effect: pending.0, frame: pending.1) }
        case "error": fail(body["message"] as? String ?? "Built-in effect failed to render.")
        default: break
        }
    }

    private func fail(_ message: String) {
        state = .failed(message)
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "builtinVoiceEffect")
        webView?.stopLoading()
        webView = nil
        rendering = false
        inFlight = nil
        renderTimeout?.cancel()
        renderTimeout = nil
    }
}

@MainActor
private final class WeakBuiltinEffectHandler: NSObject, WKScriptMessageHandler {
    weak var owner: BuiltinVoiceEffectSession?
    init(owner: BuiltinVoiceEffectSession) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { owner?.receive(message) }
}

extension BuiltinVoiceEffectSession: WKNavigationDelegate, WKUIDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let hostPath = BuiltinVoiceEffectResources.url(forResource: "host", withExtension: "html")?.standardizedFileURL.path
        let allowed = action.targetFrame?.isMainFrame == true && action.request.url?.isFileURL == true
            && action.request.url?.standardizedFileURL.path == hostPath
        decisionHandler(allowed ? .allow : .cancel)
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard self.webView === webView else { return }
        fail("Built-in Voice Bar renderer stopped unexpectedly.")
    }

    @available(macOS 12.0, *)
    public func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) { decisionHandler(.deny) }
}

public struct BuiltinVoiceEffectWebView: NSViewRepresentable {
    @ObservedObject var session: BuiltinVoiceEffectSession
    public init(session: BuiltinVoiceEffectSession) { self.session = session }
    public func makeNSView(context: Context) -> NSView { NSView() }
    public func updateNSView(_ container: NSView, context: Context) {
        container.subviews.forEach { if $0 !== session.webView { $0.removeFromSuperview() } }
        guard let webView = session.webView else { return }
        if webView.superview !== container { container.addSubview(webView) }
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
    }
}

public struct BuiltinVoiceEffectPreview: View {
    public let effect: BuiltinVoiceEffect
    public let frame: BuiltinVoiceEffectFrame
    @StateObject private var session = BuiltinVoiceEffectSession()

    public init(effect: BuiltinVoiceEffect, frame: BuiltinVoiceEffectFrame) {
        self.effect = effect
        self.frame = frame
    }

    public var body: some View {
        ZStack {
            if case .failed = session.state {
                Image(systemName: "waveform").foregroundStyle(.white.opacity(0.85))
            } else {
                BuiltinVoiceEffectWebView(session: session)
            }
        }
        .onAppear { session.render(effect: effect, frame: frame) }
        .onChange(of: effect) { _, effect in session.render(effect: effect, frame: frame) }
        .onChange(of: frame) { _, frame in session.render(effect: effect, frame: frame) }
        .onDisappear { session.clear() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(effect.name)
    }
}
