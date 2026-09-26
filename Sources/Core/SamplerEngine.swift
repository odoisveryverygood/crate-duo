import Foundation

/// The audio engine contract. Agent A implements `AudioEngine`; `MockEngine` backs previews and tests.
protocol SamplerEngine: AnyObject {
    func start() throws

    /// Decode, convert and cache the buffers, then swap the bank in atomically. Keys = pad index 0...15.
    func loadBank(_ bank: Bank, sounds: [Int: PadSound]) async throws
    func sound(for pad: PadID) -> PadSound?

    /// Live trigger, as soon as possible. semitones pitches via varispeed (classic sampler).
    func trigger(_ pad: PadID, velocity: Int, semitones: Double)
    /// KEYS note-off (short fade); no-op for one-shots.
    func release(_ pad: PadID)

    func setPattern(_ p: Pattern, timing: ApplyTiming)
    var pattern: Pattern { get }

    func play()
    func stop()
    var isPlaying: Bool { get }
    var bpm: Double { get set }
    /// MPC swing percent, 50 = straight.
    var swing: Double { get set }

    /// Absolute playback position in steps (the UI polls it at 60 fps for the playhead).
    func position() -> Double
    /// Called on main at each bar start with the absolute bar index.
    var onBar: ((Int) -> Void)? { get set }
    /// Applied to bank-A lanes when that bar is scheduled.
    func queueFill(_ fill: FillDef, atBar bar: Int)

    /// While playing, live triggers are quantized (1/16) into `pattern` (overdub).
    func setRecording(_ on: Bool)

    /// Hinge punch-in FX amount 0...1 (filter / crush / delay / reverb; > 0.92 = breakdown).
    func setPunch(_ amount: Double)
    /// Snap-open: FX off instantly + crash + kick.
    func drop()
    /// PAD FX: which effect `setPunch` drives (nil = the default PUNCH chain). Default impl is a no-op.
    func setFX(_ type: FXType?)

    /// Master RMS 0...1 for meters.
    func level() -> Float
    /// Peak envelope for display (0...1), `points` long.
    func waveform(_ pad: PadID, points: Int) -> [Float]
}
