import AVFoundation
import Foundation

public final class AudioEngine {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioRecorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var outputURL: URL?
    private var usingRecorderFallback = false
    public private(set) var currentLevel: Float = 0

    /// When false, AudioEngine will NOT configure or deactivate the AVAudioSession.
    /// Set to false when an external caller (e.g. BackgroundRecordingService) manages the session.
    public var manageAudioSession: Bool = true

    public init() {}

    public func startRecording() throws {
        #if os(iOS)
        if manageAudioSession {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.record, mode: .default)
            } catch {
                #if DEBUG
                print("[Vowrite] AudioEngine: .record failed (\(error.localizedDescription)), trying .playAndRecord")
                #endif
                try session.setCategory(.playAndRecord, mode: .default)
            }
            try session.setActive(true)
            #if DEBUG
            print("[Vowrite] AudioEngine: session configured (manageAudioSession=true)")
            #endif
        } else {
            #if DEBUG
            print("[Vowrite] AudioEngine: skipping session setup (manageAudioSession=false)")
            #endif
        }
        #endif

        // Try AVAudioEngine first; always fall back to AVAudioRecorder on failure.
        // AVAudioEngine can fail even in the main app on some devices/iOS versions.
        do {
            try startWithAudioEngine()
            usingRecorderFallback = false
            #if DEBUG
            print("[Vowrite] AudioEngine: AVAudioEngine started successfully")
            #endif
        } catch {
            #if DEBUG
            print("[Vowrite] AudioEngine: AVAudioEngine failed (\(error.localizedDescription)), falling back to AVAudioRecorder")
            #endif
            try startWithAudioRecorder()
            usingRecorderFallback = true
            #if DEBUG
            print("[Vowrite] AudioEngine: AVAudioRecorder started successfully (fallback)")
            #endif
        }
    }

    // MARK: - AVAudioEngine path (macOS + iOS main app)

    private func startWithAudioEngine() throws {
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("vowrite_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let file = try AVAudioFile(forWriting: url, settings: settings)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? file.write(from: buffer)
            self?.updateLevel(buffer: buffer)
        }

        try engine.start()
        self.audioEngine = engine
        self.audioFile = file
        self.outputURL = url
    }

    // MARK: - AVAudioRecorder fallback (keyboard extensions)

    private func startWithAudioRecorder() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("vowrite_\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true

        guard recorder.record() else {
            throw NSError(domain: "com.vowrite.audio", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "AVAudioRecorder.record() returned false"])
        }

        // Poll meters for audio level
        let timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak recorder] _ in
            guard let recorder = recorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let db = recorder.averagePower(forChannel: 0)
            let output: Float = db > -45 ? Float.random(in: 0.6...1.0) : 0.0
            DispatchQueue.main.async {
                self?.currentLevel = output
            }
        }

        self.audioRecorder = recorder
        self.meterTimer = timer
        self.outputURL = url
    }

    public func stopRecording() -> URL? {
        if usingRecorderFallback {
            meterTimer?.invalidate()
            meterTimer = nil
            audioRecorder?.stop()
            audioRecorder = nil
        } else {
            audioEngine?.inputNode.removeTap(onBus: 0)
            audioEngine?.stop()
            audioEngine = nil
            audioFile = nil
        }

        currentLevel = 0

        #if os(iOS)
        if manageAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false)
            #if DEBUG
            print("[Vowrite] AudioEngine: session deactivated (manageAudioSession=true)")
            #endif
        } else {
            #if DEBUG
            print("[Vowrite] AudioEngine: skipping session deactivation (manageAudioSession=false)")
            #endif
        }
        #endif

        return outputURL
    }

    private func updateLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)

        var peak: Float = 0
        for i in 0..<count {
            let abs = fabsf(channelData[i])
            if abs > peak { peak = abs }
        }

        // Any sound above noise floor → random high value (0.6-1.0) each frame
        // Silent → 0. This keeps the waveform constantly jumping while speaking.
        let db = 20 * log10f(max(peak, 1e-6))
        let output: Float = db > -45 ? Float.random(in: 0.6...1.0) : 0.0

        DispatchQueue.main.async { [weak self] in
            self?.currentLevel = output
        }
    }
}
