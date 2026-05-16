import SwiftUI
import SwiftData
import Combine
import VowriteKit

@MainActor
final class AppState: ObservableObject {
    @Published var state: VowriteState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastResult: String?
    @Published var lastRawTranscript: String?

    // Forwarded from backgroundService (nested ObservableObject won't trigger view updates otherwise)
    @Published var bgServiceActive = false
    @Published var bgServiceRecording = false
    @Published var bgServiceError: String?
    @Published var bgServiceRemainingTime: TimeInterval? = nil
    @Published var historyUnavailable: Bool = false

    let modelContainer: ModelContainer
    let engine: DictationEngine
    let backgroundService = BackgroundRecordingService()

    private var cancellables = Set<AnyCancellable>()

    var isRecording: Bool { engine.isRecording }
    var hasAPIKey: Bool { engine.hasAPIKey }

    // MARK: Stats
    var totalDictationTime: TimeInterval { engine.totalDictationTime }
    var totalWords: Int { engine.totalWords }
    var totalDictations: Int { engine.totalDictations }

    init() {
        let schema = Schema([DictationRecord.self])
        let primary: ModelConfiguration
        if let storeURL = VowriteStorage.swiftDataURL {
            primary = ModelConfiguration(storeURL.lastPathComponent, schema: schema, isStoredInMemoryOnly: false, groupContainer: .identifier(VowriteStorage.appGroupID))
        } else {
            primary = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        if let container = try? ModelContainer(for: schema, configurations: [primary]) {
            modelContainer = container
        } else {
            // Fallback to in-memory store so the app still boots; HistoryView shows a banner.
            // Note: keyboard extension reads the App Group store directly, so its records will
            // also be unavailable until the underlying issue (App Group entitlement, disk
            // corruption, schema mismatch) is resolved.
            let inMemory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [inMemory])
            } catch {
                fatalError("In-memory model container failed to initialize: \(error)")
            }
            historyUnavailable = true
        }

        engine = DictationEngine(
            textOutput: iOSClipboardOutput(),
            permissions: iOSPermissionManager(),
            overlay: iOSOverlayProvider(),
            feedback: iOSFeedback()
        )

        // Forward engine state to AppState for views
        engine.$state.assign(to: &$state)
        engine.$audioLevel.assign(to: &$audioLevel)
        engine.$recordingDuration.assign(to: &$recordingDuration)
        engine.$lastResult.assign(to: &$lastResult)
        engine.$lastRawTranscript.assign(to: &$lastRawTranscript)

        // Forward backgroundService state so SwiftUI views react to changes
        backgroundService.$isActive.assign(to: &$bgServiceActive)
        backgroundService.$isRecording.assign(to: &$bgServiceRecording)
        backgroundService.$activationError.assign(to: &$bgServiceError)
        backgroundService.$remainingTime.assign(to: &$bgServiceRemainingTime)

        // Wire history save callback
        engine.onRecordComplete = { [weak self] rawTranscript, finalText, duration, wasTranslation in
            guard let self = self else { return }
            let record = DictationRecord(
                rawTranscript: rawTranscript,
                polishedText: finalText,
                duration: duration,
                detectedLanguage: nil,
                wasTranslation: wasTranslation ? true : nil
            )
            let context = self.modelContainer.mainContext
            context.insert(record)
            try? context.save()
        }
    }

    func toggleRecording() { engine.toggleRecording() }
    func startRecording() { engine.startRecording() }
    func stopRecording() { engine.stopRecording() }
    func cancelRecording() { engine.cancelRecording() }

    /// Import pending records written by keyboard extension
    func importPendingRecords() {
        let pending = PendingRecordStore.consumeAll()
        guard !pending.isEmpty else { return }

        let context = modelContainer.mainContext
        for pending in pending {
            let record = DictationRecord(
                rawTranscript: pending.rawTranscript,
                polishedText: pending.polishedText,
                duration: pending.duration,
                detectedLanguage: nil
            )
            context.insert(record)
        }
        try? context.save()
    }
}
