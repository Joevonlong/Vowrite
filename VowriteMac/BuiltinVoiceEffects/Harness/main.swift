import AppKit
import BuiltinVoiceEffects
import SwiftUI

private struct CapsuleLayoutPreview: View {
    let effect: BuiltinVoiceEffect

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let level = 0.55 + sin(time * 3.2) * 0.3
            VStack(alignment: .leading, spacing: 18) {
                previewRow("Compact · Recording", size: .compact, phase: .listening, time: time, level: level)
                previewRow("Normal · Recording", size: .normal, phase: .listening, time: time, level: level)
                previewRow("Compact · Processing", size: .compact, phase: .processing, time: time, level: level)
                previewRow("Normal · Processing", size: .normal, phase: .processing, time: time, level: level)
            }
        }
    }

    private func previewRow(
        _ label: String,
        size: BuiltinVoiceEffectCapsuleSize,
        phase: BuiltinVoiceEffectFrame.Phase,
        time: Double,
        level: Double
    ) -> some View {
        HStack(spacing: 18) {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 150, alignment: .trailing)
            BuiltinVoiceEffectCapsule(
                effect: effect,
                frame: .init(phase: phase, time: time, level: level, reducedMotion: false),
                size: size,
                durationText: size == .normal ? "0:08" : nil
            )
            .allowsHitTesting(false)
        }
    }
}

let arguments = CommandLine.arguments
let suiteIndex = arguments.firstIndex(of: "--suite")
let suiteName = suiteIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    ?? "com.vowrite.builtin-effects.harness.preferences"
guard let defaults = UserDefaults(suiteName: suiteName) else {
    fputs("Unable to create isolated defaults suite.\n", stderr)
    exit(2)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

if arguments.contains("--smoke") {
    Task { @MainActor in
        guard let resourceURL = BuiltinVoiceEffectResources.bundleURL,
              let appResources = Bundle.main.resourceURL,
              Bundle.main.bundleURL.pathExtension == "app",
              resourceURL.path.hasPrefix(appResources.path + "/") else {
            fputs("Packaged built-in resource bundle unavailable.\n", stderr)
            exit(9)
        }
        let selection = BuiltinVoiceEffectSelection(defaults: defaults)
        selection.select(80)
        guard BuiltinVoiceEffectSelection(defaults: defaults).selectedID == 80,
              BuiltinVoiceEffectCatalog.effect(id: 1) != nil else {
            fputs("Selection persistence failed.\n", stderr)
            exit(3)
        }

        let session = BuiltinVoiceEffectSession()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 104, height: 28),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: BuiltinVoiceEffectWebView(session: session))
        window.orderFront(nil)

        @MainActor func waitUntil(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
            for _ in 0..<100 {
                if condition() { return true }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return false
        }

        guard await waitUntil({ session.state == .ready }) else {
            fputs("WK renderer did not become ready: \(session.state)\n", stderr)
            exit(4)
        }
        window.orderOut(nil)
        for id in 1...80 {
            guard let nextEffect = BuiltinVoiceEffectCatalog.effect(id: id) else {
                fputs("Catalog is missing effect \(id).\n", stderr)
                exit(5)
            }
            let previousCount = session.frameCount
            let phase: BuiltinVoiceEffectFrame.Phase = id == 80 ? .processing : .listening
            let level = id == 80 ? 0.9 : 0.2 + Double(id % 7) * 0.1
            session.render(
                effect: nextEffect,
                frame: .init(phase: phase, time: Double(id) / 10, level: level, reducedMotion: true)
            )
            guard await waitUntil({ session.frameCount > previousCount && session.lastRenderedPhase == phase.rawValue }) else {
                fputs("WK renderer did not acknowledge effect \(id).\n", stderr)
                exit(6)
            }
            do {
                let result = try await session.webView?.callAsyncJavaScript(
                    """
                    const canvas = document.getElementById('effect');
                    const pixels = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
                    let visible = 0;
                    for (let index = 3; index < pixels.length; index += 4) if (pixels[index] > 0) visible += 1;
                    return visible;
                    """,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
                guard let visible = result as? NSNumber, visible.intValue > 0 else {
                    fputs("Effect \(id) rendered no visible pixels.\n", stderr)
                    exit(7)
                }
            } catch {
                fputs("Effect \(id) pixel check failed: \(error)\n", stderr)
                exit(8)
            }
        }
        session.clear()
        print(
            "BUILTIN_EFFECT_SMOKE_OK effects=\(BuiltinVoiceEffectCatalog.all.count) "
                + "frames=\(session.frameCount) canvas=104x28 resource=\(resourceURL.path)"
        )
        window.close()
        app.terminate(nil)
    }
} else if arguments.contains("--layout-preview"),
          let effect = BuiltinVoiceEffectCatalog.effect(id: 1) {
    let root = CapsuleLayoutPreview(effect: effect)
        .padding(24)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 310),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "Compact Voice Bar Layouts"
    window.contentView = NSHostingView(rootView: root)
    window.center()
    window.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
} else {
    let selection = BuiltinVoiceEffectSelection(defaults: defaults)
    let root = VStack(alignment: .leading, spacing: 14) {
        Text("Voice Bar Effects").font(.title2.bold())
        BuiltinVoiceEffectSelectorView(selection: selection)
    }
    .padding(20)
    .frame(width: 660)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = "Vowrite Voice Bar Effects"
    window.contentView = NSHostingView(rootView: ScrollView { root })
    window.center()
    window.makeKeyAndOrderFront(nil)
    app.activate(ignoringOtherApps: true)
}

app.run()
