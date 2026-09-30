import Foundation
import Observation
import AVFoundation

/// Own once beside AppState; UI and recorder lifecycle are serialized on the main actor.
@MainActor
@Observable
final class MicSampler: NSObject, AVAudioRecorderDelegate {
    private(set) var isRecording = false
    private(set) var isPreparing = false
    private(set) var isProcessing = false
    private(set) var level: Double = 0
    private(set) var seconds: Double = 0
    private(set) var errorMessage: String?
    private(set) var lastRecordingURL: URL?
    var chopType: SampleChopType = .threshold

    @ObservationIgnored private let state: AppState
    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sessionChanged = false

    init(state: AppState) {
        self.state = state
        super.init()
        let inactive: Notification.Name
        if #available(iOS 27.0, *) {
            inactive = AVAudioSession.didBecomeInactiveNotification
        } else {
            inactive = AVAudioSession.interruptionNotification   // iOS 26
        }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: inactive, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRecording || self.isPreparing else { return }
                self.cancelRecording()
                self.fail("Recording was interrupted. Hold SAMPLE RECORD to try again.")
            }
        }
    }

    deinit {
        recorder?.stop()
        if sessionChanged {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
        meterTask?.cancel()
        permissionTask?.cancel()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    func startRecording() {
        guard !isPreparing, !isRecording, !isProcessing else { return }
        errorMessage = nil
        seconds = 0
        level = 0
        generation += 1
        let request = generation
        isPreparing = true
        permissionTask = Task { [weak self] in
            let allowed = await AVAudioApplication.requestRecordPermission()
            guard let self, !Task.isCancelled, self.generation == request else { return }
            self.isPreparing = false
            guard allowed else {
                self.fail("Microphone access is off. Enable it for CRATE in Settings → Privacy & Security → Microphone.")
                return
            }
            self.beginTake()
        }
    }

    private func beginTake() {
        do {
            let directory = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("samples", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let stamp = Int64(Date().timeIntervalSince1970 * 1000)
            let url = directory.appendingPathComponent("rec-\(stamp)-\(UUID().uuidString.prefix(8)).wav")
            let session = AVAudioSession.sharedInstance()
            // Restore even if setActive or recorder preparation fails after category changes.
            sessionChanged = true
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)
            let take = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ])
            take.delegate = self
            take.isMeteringEnabled = true
            recorder = take
            guard take.prepareToRecord(), take.record(forDuration: 120) else {
                throw SampleChopError.unreadableAudio
            }
            lastRecordingURL = url
            isRecording = true
            meterTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(33))
                    guard !Task.isCancelled, let self, self.isRecording, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    let db = Double(recorder.averagePower(forChannel: 0))
                    self.level = db.isFinite ? min(1, max(0, pow(10, db / 20))) : 0
                    self.seconds = recorder.currentTime
                }
            }
        } catch {
            recorder?.stop()
            recorder = nil
            restorePlayback()
            fail("Couldn't start microphone recording: \(error.localizedDescription)")
        }
    }

    func stopRecording(chop: SampleChopType) async {
        // Invalidate an outstanding permission request so release can never start a late take.
        generation += 1
        permissionTask?.cancel()
        permissionTask = nil
        isPreparing = false
        guard isRecording, let take = recorder else { return }
        isRecording = false
        isProcessing = true
        meterTask?.cancel()
        meterTask = nil
        seconds = max(seconds, take.currentTime)
        take.stop()
        recorder = nil
        level = 0
        restorePlayback()
        defer { isProcessing = false }
        do {
            let url = take.url
            let analysis = try await Task.detached(priority: .userInitiated) {
                try SampleChopper.analyze(url: url, chop: chop)
            }.value
            DebugLog.event("sample_rec", ["sec": analysis.duration])
            var sounds: [Int: PadSound] = [:]
            for (index, slice) in analysis.slices.enumerated() {
                sounds[index] = PadSound(id: "\(url.lastPathComponent)-\(index)",
                    name: String(format: "REC %02d", index + 1), category: .chop,
                    fileURL: url, start: slice.start, end: slice.end, rootNote: 60,
                    source: "MIC")
            }
            try await state.engine.loadBank(.d, sounds: sounds)
            guard SampleBankCommit.publish(sounds, to: state) else {
                fail("The engine couldn't load all chops, or a newer bank D load replaced them. The recorded WAV is saved; no successful chop is reported.")
                return
            }
            seconds = analysis.duration
            state.addLog("SAMPLE", String(format: "%d chops · %.1f s", sounds.count, analysis.duration), tint: .grey)
            DebugLog.event("sample_chop", ["slices": sounds.count])
        } catch {
            fail("Couldn't chop the take: \(error.localizedDescription)")
        }
    }

    /// Used on gesture cancellation, view disappearance and interruption; retains the WAV on disk.
    func cancelRecording() {
        generation += 1
        permissionTask?.cancel()
        permissionTask = nil
        isPreparing = false
        isRecording = false
        meterTask?.cancel()
        meterTask = nil
        let take = recorder
        recorder = nil
        take?.stop()
        level = 0
        restorePlayback()
    }

    private func restorePlayback() {
        guard sessionChanged else { return }
        do {
            // Do not deactivate the session: the performance engine remains running.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            sessionChanged = false
        } catch {
            fail("Couldn't restore playback routing: \(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        state.addLog("ERR", message, tint: .red)
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let id = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == id, self.isRecording else { return }
            if flag { await self.stopRecording(chop: self.chopType) }
            else { self.cancelRecording(); self.fail("Recording stopped unexpectedly. Please try another take.") }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let id = ObjectIdentifier(recorder)
        Task { @MainActor [weak self] in
            guard let self, let current = self.recorder, ObjectIdentifier(current) == id else { return }
            self.cancelRecording()
            self.fail("Couldn't save microphone audio. Check available storage and try again.")
        }
    }
}
