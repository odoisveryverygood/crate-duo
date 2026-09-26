// macOS harness for Sources/Audio (not part of the app). Plays through the Mac's speakers.
// Build: tools/audio-harness/build.sh   Run: /tmp/crate-audio-harness <mode> [seconds] [-crateDebugRecord 1 -crateDebugLog 1]
//   checks  — deterministic internals: fills, late[], hat choke, .nextBar swap, overdub insert, bad file, waveform
//   timing  — clicks at known steps through different varispeed rates (onset accuracy check)
//   chops   — mono bank-B chops incl. truncation (compare against the loop file: expected SNR ≥ 18 dB, lag 0)
//   groove  — DefaultKit + dilla_donuts + chops + 808 bass; meter, punch sweep, drop, fill, overdub, KEYS, bpm change,
//             simulated route change
// Env: CRATE_DEBUG_WAV=<path> (with -crateDebugRecord 1) records the master output; HARNESS_TMP=<dir> for scratch files.
import Foundation
import AVFoundation

let args = CommandLine.arguments.filter { !$0.hasPrefix("-crate") && $0 != "1" }
let mode = args.count > 1 ? args[1] : "groove"
let seconds = args.count > 2 ? Double(args[2]) ?? 20 : 20
let kitDir = URL(fileURLWithPath: "/Users/shuhanzhang/crate-build/Resources/DefaultKit")
let grooveURL = URL(fileURLWithPath: "/Users/shuhanzhang/duo-hack/library/grooves.json")
let scratch = URL(fileURLWithPath: ProcessInfo.processInfo.environment["HARNESS_TMP"] ?? NSTemporaryDirectory())

let engine = AudioEngine()
do { try engine.start() } catch { print("start failed: \(error)"); exit(1) }
print("engine started sr=\(engine.engineFormat?.sampleRate ?? 0)")

func kit(_ file: String, _ name: String, _ cat: Category, root: Int? = nil, start: Double = 0, end: Double? = nil) -> PadSound {
    PadSound(id: file, name: name, category: cat, fileURL: kitDir.appendingPathComponent(file), start: start, end: end, rootNote: root)
}

func at(_ t: Double, _ f: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: f) }

func writeClick(to url: URL) throws {
    let sr = 44100.0
    let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
    let n = Int(sr * 0.05)
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
    buf.frameLength = AVAudioFrameCount(n)
    for i in 0..<n {
        let t = Double(i) / sr
        buf.floatChannelData![0][i] = Float(sin(2 * .pi * 2000 * t) * exp(-t * 300) * 0.9)
    }
    let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
    try file.write(from: buf)
}

// MARK: - timing mode
func runTiming() async throws {
    let click = scratch.appendingPathComponent("click.wav")
    try writeClick(to: click)
    try await engine.loadBank(.d, sounds: [0: PadSound(id: "click", name: "CLICK", category: .synth, fileURL: click, rootNote: 60)])
    engine.bpm = 120
    engine.swing = 50
    var p = Pattern()
    p.bars = 1
    p.lanes[PadID(.d, 0)] = [Hit(step: 0, velocity: 127), Hit(step: 4, velocity: 127), Hit(step: 8, velocity: 127), Hit(step: 12, velocity: 127)]
    p.notes[PadID(.d, 0)] = [NoteEvent(step: 2, length: 1, midi: 67, velocity: 127),   // rate 1.5
                             NoteEvent(step: 6, length: 1, midi: 48, velocity: 127),   // rate 0.5
                             NoteEvent(step: 10, length: 1, midi: 72, velocity: 127),  // rate 2
                             NoteEvent(step: 14, length: 1, midi: 60, velocity: 127)]  // rate 1 via note path
    engine.setPattern(p, timing: .now)
    at(0.3) { engine.play() }
    at(0.3 + seconds) { engine.stop() }
}

// MARK: - groove mode
struct GrooveFile: Decodable {
    struct Groove: Decodable { let id: String; let bars: Int; let bpm: Double; let swing: Double; let lanes: [String: [[Double]]] }
    let grooves: [Groove]
    let fills: [FillDef]
}

func runGroove() async throws {
    let t0 = Date()
    async let a: Void = engine.loadBank(.a, sounds: [
        0: kit("01_kick.wav", "KICK", .kick), 1: kit("02_kick_alt.wav", "KICK2", .kick),
        2: kit("03_snare.wav", "SNARE", .snare), 3: kit("04_clap.wav", "CLAP", .clap),
        4: kit("05_chat.wav", "CHAT", .hat), 5: kit("05_chat.wav", "CHAT2", .hat),
        6: kit("06_ohat.wav", "OHAT", .openhat), 7: kit("07_rim.wav", "RIM", .rim),
        8: kit("07_rim.wav", "PERC", .perc), 10: kit("08_shaker.wav", "SHAKE", .shaker),
        11: kit("10_crash.wav", "CRASH", .cymbal), 12: kit("09_808.wav", "808", .eight08, root: 36),
        13: kit("12_fx.wav", "FX", .fx), 14: kit("11_vox.wav", "VOX", .vocal), 15: kit("15_texture.wav", "VINYL", .texture),
    ])
    let loopLen = 5.4545
    var chops: [Int: PadSound] = [:]
    for i in 0..<16 {
        chops[i] = kit("16_loop_chop.wav", "CHOP \(i + 1)", .chop, start: Double(i) * loopLen / 16, end: Double(i + 1) * loopLen / 16)
    }
    let chopSounds = chops
    async let b: Void = engine.loadBank(.b, sounds: chopSounds)
    async let c: Void = engine.loadBank(.c, sounds: [0: kit("09_808.wav", "808 C", .bass, root: 36), 1: kit("13_keys.wav", "KEYS", .keys, root: 60)])
    _ = try await (a, b, c)
    print("loaded 3 banks in \(Int(Date().timeIntervalSince(t0) * 1000)) ms")

    let gf = try JSONDecoder().decode(GrooveFile.self, from: Data(contentsOf: grooveURL))
    let g = gf.grooves.first { $0.id == "dilla_donuts" }!
    var p = Pattern()
    p.bars = 2
    p.swing = g.swing
    for (lane, hits) in g.lanes {
        guard let pad = BankA.pad(forLane: lane) else { continue }
        p.lanes[pad] = hits.map { Hit(step: Int($0[0]), velocity: Int($0[1]), offset: $0.count > 2 ? $0[2] : 0, ratchet: $0.count > 3 ? Int($0[3]) : 1) }
    }
    p.late[PadID(.a, 2)] = 0.05
    for i in 0..<16 { p.lanes[PadID(.b, i)] = [Hit(step: i * 2, velocity: 100)] }
    // Bm-ish bass on the 808 (root 36 = C): B1=35, D2=38, F#1=30→folds to 42, A1=33
    let bass: [(Int, Double, Int)] = [(0, 5, 35), (6, 2, 42), (10, 4, 35), (14, 2, 38), (16, 5, 31), (22, 2, 38), (26, 4, 33), (30, 2, 34)]
    p.notes[PadID(.c, 0)] = bass.map { NoteEvent(step: $0.0, length: $0.1, midi: $0.2, velocity: 104) }
    engine.bpm = 88
    engine.swing = g.swing
    engine.setPattern(p, timing: .now)
    engine.onBar = { bar in print(String(format: "onBar %d  pos=%.2f level=%.2f", bar, engine.position(), engine.level())) }

    at(0.2) { engine.play() }
    // meter smoothness: poll level() at 60 Hz for 2 s like the UI does
    var levels: [Float] = []
    for i in 0..<120 { at(3 + Double(i) / 60) { levels.append(engine.level()) } }
    at(5.1) {
        let zeros = levels.filter { $0 < 0.05 }.count
        let jumps = zip(levels, levels.dropFirst()).map { abs($0 - $1) }.max() ?? 0
        print(String(format: "meter @60Hz: min %.2f max %.2f mean %.2f, near-zero %d/120, max frame jump %.2f",
                     levels.min() ?? 0, levels.max() ?? 0, levels.reduce(0, +) / Float(max(1, levels.count)), zeros, jumps))
    }
    // punch sweep 0 → 1 over 3 s starting at 6 s, hold, then DROP at 10.5 s
    for i in 0...180 { at(6 + Double(i) / 60) { engine.setPunch(Double(i) / 180) } }
    at(10.5) { engine.drop() }
    // fill on bar 7 (queued during bar 5/6)
    at(11) {
        let bar = Int(engine.position() / 16) + 1
        print("queue ROLL at bar \(bar)")
        engine.queueFill(gf.fills.first { $0.id == "snare_roll" }!, atBar: bar)
        engine.queueFill(gf.fills.first { $0.id == "crash_next" }!, atBar: bar + 1)
    }
    // overdub a few rims
    at(14) { engine.setRecording(true) }
    for k in 0..<4 { at(14.2 + Double(k) * 0.34) { engine.trigger(PadID(.a, 7), velocity: 100, semitones: 0) } }
    at(15.8) {
        engine.setRecording(false)
        print("rim lane after overdub: \(engine.pattern.lanes[PadID(.a, 7)]?.map { $0.step } ?? [])")
    }
    // KEYS on bank C over the loop, with releases
    for (k, semi) in [0, 3, 7, 10].enumerated() {
        at(16 + Double(k) * 0.3) { engine.trigger(PadID(.c, 1), velocity: 110, semitones: Double(semi)) }
        at(16.2 + Double(k) * 0.3) { engine.release(PadID(.c, 1)) }
    }
    // bpm change
    at(18) { engine.bpm = 94; print("bpm → 94 at pos \(engine.position())") }
    // simulated route change: the AVAudioEngine stops itself and posts a configuration change
    at(19.5) {
        engine.engine.stop()
        NotificationCenter.default.post(name: .AVAudioEngineConfigurationChange, object: engine.engine)
        print("config change posted at pos \(engine.position())")
    }
    // silent stop (interruption without a notification): the clock tick must self-heal within ~1 s
    at(21) { engine.engine.stop(); print("engine stopped silently at pos \(engine.position())") }
    at(seconds) { engine.stop() }
}

// MARK: - chops mode: mono truncation + slice timing (python rebuilds the expected signal from the loop file)
func runChops() async throws {
    let loopLen = 5.4545
    var chops: [Int: PadSound] = [:]
    for i in 0..<16 {
        chops[i] = kit("16_loop_chop.wav", "CHOP \(i + 1)", .chop, start: Double(i) * loopLen / 16, end: Double(i + 1) * loopLen / 16)
    }
    try await engine.loadBank(.b, sounds: chops)
    // (step, chop): chop 0 is cut after 1 step by chop 1, chop 5 after 1 step by a 2x ratchet, etc.
    let events: [(Int, Int)] = [(0, 0), (1, 1), (4, 2), (6, 3), (7, 5), (8, 8), (12, 9), (14, 10), (15, 12),
                                (16, 0), (18, 1), (20, 4), (21, 6), (24, 8), (26, 11), (28, 14), (30, 15)]
    var p = Pattern()
    p.bars = 2
    for (s, c) in events { p.lanes[PadID(.b, c), default: []].append(Hit(step: s, velocity: 127)) }
    engine.bpm = 88
    engine.swing = 50
    engine.setPattern(p, timing: .now)
    let json = try JSONSerialization.data(withJSONObject: ["events": events.map { [$0.0, $0.1] }, "bpm": 88, "loopLen": loopLen])
    try json.write(to: scratch.appendingPathComponent("chops.json"))
    at(0.3) { engine.play() }
    at(0.3 + seconds) { engine.stop() }
}

// MARK: - checks mode: deterministic internals (fills, events, chokes, bad files, waveform)
func runChecks() async throws {
    var failures = 0
    func check(_ ok: Bool, _ msg: String) { print((ok ? "PASS " : "FAIL ") + msg); if !ok { failures += 1 } }

    // bad file: pad skipped, others load, no throw
    try await engine.loadBank(.d, sounds: [0: PadSound(id: "x", name: "BAD", category: .fx, fileURL: URL(fileURLWithPath: "/nope/missing.wav")),
                                           1: kit("01_kick.wav", "KICK", .kick)])
    check(engine.sound(for: PadID(.d, 0)) == nil && engine.sound(for: PadID(.d, 1)) != nil, "missing file skipped, other pad loaded")
    try await engine.loadBank(.a, sounds: [2: kit("03_snare.wav", "SNARE", .snare), 4: kit("05_chat.wav", "CHAT", .hat),
                                           6: kit("06_ohat.wav", "OHAT", .openhat), 11: kit("10_crash.wav", "CRASH", .cymbal),
                                           0: kit("01_kick.wav", "KICK", .kick)])
    let wf = engine.waveform(PadID(.a, 0), points: 64)
    check(wf.count == 64 && (wf.max() ?? 0) > 0.3 && (wf.max() ?? 2) <= 1, "waveform 64 pts, peak \(wf.max() ?? 0)")
    check(engine.waveform(PadID(.b, 9), points: 10) == [Float](repeating: 0, count: 10), "empty pad waveform = zeros")
    let big = engine.waveform(PadID(.a, 0), points: 4000)
    check(big.count == 4000, "waveform 4000 pts")

    let gf = try JSONDecoder().decode(GrooveFile.self, from: Data(contentsOf: grooveURL))
    var p = Pattern()
    p.bars = 1
    p.lanes[PadID(.a, 2)] = [Hit(step: 4, velocity: 110), Hit(step: 12, velocity: 110), Hit(step: 14, velocity: 90)]
    p.lanes[PadID(.a, 4)] = [Hit(step: 0, velocity: 80), Hit(step: 3, velocity: 80)]
    p.lanes[PadID(.a, 6)] = [Hit(step: 2, velocity: 90)]
    p.late[PadID(.a, 2)] = 0.1
    engine.q.sync {
        engine.applyPattern(p, timing: .now)
        engine.fills[5] = gf.fills.first { $0.id == "snare_roll" }!
        engine.fills[6] = gf.fills.first { $0.id == "crash_next" }!
        engine.schedBar = 4
        engine.anchorStep = 0; engine.anchorTime = 100; engine.sps = 0.125; engine.swingQ = 60
        let bar5 = (0..<16).map { s in engine.events(at: 80 + s).filter { $0.pad == PadID(.a, 2) }.map { $0.velocity } }
        check(bar5[4] == [110] && bar5[12] == [58] && bar5[13] == [70] && bar5[14] == [86] && bar5[15] == [104],
              "snare_roll: cleared from 12, added 12-15 → \(bar5.enumerated().filter { !$0.element.isEmpty }.map { "\($0.offset):\($0.element)" })")
        check(engine.events(at: 80 + 4).first { $0.pad == PadID(.a, 2) }?.offset == 0.1, "late[pad] folded into offset")
        let bar6 = (0..<16).map { engine.events(at: 96 + $0).filter { $0.pad == PadID(.a, 11) }.count }
        let bar7 = (0..<16).map { engine.events(at: 112 + $0).filter { $0.pad == PadID(.a, 11) }.count }
        check(bar6.reduce(0, +) == 0 && bar7[0] == 1 && bar7.reduce(0, +) == 1, "crash_next at bar 6 → cymbal at bar 7 step 0")
        check(engine.events(at: 64 + 12).filter { $0.pad == PadID(.a, 2) }.map { $0.velocity } == [110], "bar 4 untouched by bar-5 fill")
        // open hat (step 2) is cut by the closed hat at step 3 (odd step → swung by 0.2 steps)
        let t2 = engine.stepTime(2)
        let cut = engine.nextCutTime(victim: PadID(.a, 6), after: t2, fromStep: 2)
        let want = engine.stepTime(3) + (2 * 60 / 100 - 1) * 0.125
        check(cut != nil && abs(cut! - want) < 1e-9, "open hat choked by hat at swung step 3 (cut \(cut.map { $0 - t2 } ?? -1)s)")
        check(engine.nextCutTime(victim: PadID(.a, 2), after: t2, fromStep: 2) == nil || !AudioEngine.canBeCut(PadID(.a, 2)), "snare never choked")
        // .nextBar swap
        var p2 = p; p2.lanes[PadID(.a, 0)] = [Hit(step: 0, velocity: 127)]
        engine.playingQ = true
        engine.applyPattern(p2, timing: .nextBar)
        check(engine.pending != nil && engine.active.pattern.lanes[PadID(.a, 0)] == nil, ".nextBar pending until the bar boundary")
        check(engine.events(at: 16 * 5 + 16).contains { $0.pad == PadID(.a, 0) }, "lookahead into the next bar sees the pending pattern")
        engine.enterBar(5)
        check(engine.pending == nil && engine.active.pattern.lanes[PadID(.a, 0)] != nil, "pending applied at the bar boundary")
        engine.playingQ = false
        // recording insert
        var rp = Pattern(); rp.bars = 2
        let st = AudioEngine.insert(into: &rp, pad: PadID(.c, 0), absStep: 37, velocity: 100, semi: 7, root: 36)
        check(st == 5 && rp.notes[PadID(.c, 0)]?.first?.midi == 43 && rp.notes[PadID(.c, 0)]?.first?.length == 1, "rec note: abs 37 → step 5, midi 43")
        _ = AudioEngine.insert(into: &rp, pad: PadID(.a, 0), absStep: 64, velocity: 90, semi: 0, root: 60)
        _ = AudioEngine.insert(into: &rp, pad: PadID(.a, 0), absStep: 32, velocity: 120, semi: 0, root: 60)
        check(rp.lanes[PadID(.a, 0)]?.count == 1 && rp.lanes[PadID(.a, 0)]?.first?.velocity == 120, "rec hit dedupes by step (max velocity)")
    }
    // restore sequencer state for real playback
    engine.q.sync { engine.anchorTime = 0; engine.schedBar = 0; engine.fills.removeAll(); engine.sps = 60 / 90 / 4 }
    print(failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED")
}

Task {
    do {
        switch mode {
        case "timing": try await runTiming()
        case "chops": try await runChops()
        case "checks": try await runChecks()
        default: try await runGroove()
        }
    } catch { print("harness error: \(error)"); exit(1) }
}
DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 1.5) {
    print("done. final level=\(engine.level()) pattern bars=\(engine.pattern.bars)")
    exit(0)
}
RunLoop.main.run()
