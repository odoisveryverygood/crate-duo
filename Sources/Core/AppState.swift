import Foundation
import Observation

/// Single source of truth the UI binds to. The App layer wires the actions (onDig etc.) to the orchestrator.
@Observable
final class AppState {
    var mode: Mode = .seq
    var bank: Bank = .a
    var selectedPad = PadID(.a, 0)
    var sounds: [PadID: PadSound] = [:]

    var bpm: Double = 90
    var swing: Double = 56
    var isPlaying = false
    var isRecording = false
    var bars = 4

    var styleLabel = "CRATE"
    var sampleLabel = ""
    var chordsLabel = ""
    var log: [LogLine] = []
    var prompt = ""
    var isDigging = false
    var jevMs: Int? = nil
    var gptSeconds: Double? = nil

    var keysOctave = 0
    var scaleLock = true
    var scaleKey: String? = nil
    var lastNoteName = ""

    var punch: Double = 0
    var hingeAngle: Double? = nil
    var performOn = false
    var lastPerform = ""

    var lastHitPad: PadID? = nil
    var lastHitTime = Date.distantPast

    @ObservationIgnored var engine: SamplerEngine
    @ObservationIgnored var onDig: ((String) -> Void)?
    @ObservationIgnored var onFlip: (() -> Void)?
    @ObservationIgnored var onPerformToggle: ((Bool) -> Void)?

    init(engine: SamplerEngine) {
        self.engine = engine
    }

    func sound(_ pad: PadID) -> PadSound? { sounds[pad] ?? engine.sound(for: pad) }

    func hit(_ pad: PadID, velocity: Int = 110, semitones: Double = 0) {
        engine.trigger(pad, velocity: velocity, semitones: semitones)
        lastHitPad = pad
        lastHitTime = Date()
        DebugLog.event("pad", ["bank": pad.bank.letter, "i": pad.index, "vel": velocity, "semi": semitones])
    }

    func dig(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        prompt = t
        onDig?(t)
    }

    func togglePlay() {
        if engine.isPlaying { engine.stop() } else { engine.play() }
        isPlaying = engine.isPlaying
    }

    func setRecording(_ on: Bool) {
        isRecording = on
        engine.setRecording(on)
    }

    func addLog(_ tag: String, _ text: String, ms: Int? = nil, tint: Tint = .grey) {
        log.append(LogLine(tag: tag, text: text, ms: ms, tint: tint))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
