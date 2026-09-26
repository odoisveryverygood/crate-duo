import Foundation

/// Drag-in song → 16 chops on bank D → a starter flip playing at once (flip tempo, song key) → gpt-6-sol re-flips the
/// chops in the background and swaps them in on the next bar. Later DIGs (e.g. "dilla drums for this") keep the flip.
extension Orchestrator {
    /// Set by `wire()` so the import path (Transfer) can reach the running orchestrator.
    static weak var current: Orchestrator?

    /// The session's chops came from an imported song (they live on bank D, not bank B).
    var importedFlip: Bool { session?.chops?.loop.id.hasPrefix("import-") == true }
    var chopBank: Bank { importedFlip ? .d : .b }

    @discardableResult
    func importFlip(url: URL, name: String, duration: Double, starts raw: [Double], demo: DemoSample?) async -> Bool {
        let t0 = Date()
        digSerial += 1
        let serial = digSerial
        gptTask?.cancel()
        gptTask = nil
        let keyText = demo?.key ?? state.scaleKey
        let key = Music.parseKey(keyText)
        let root = 60 + (key?.pc ?? 0)
        var starts = Array(raw.filter { $0.isFinite && $0 >= 0 && $0 < duration }.prefix(16))
        if starts.count < 16 { starts = (0..<16).map { duration * Double($0) / 16 } }
        for i in 1..<16 where starts[i] <= starts[i - 1] { starts[i] = starts[i - 1] + 0.005 }
        let label = (demo?.name ?? name).uppercased()
        let short = label.split(separator: " ").prefix(2).joined(separator: " ")
        var sounds: [Int: PadSound] = [:]
        for i in 0..<16 {
            sounds[i] = PadSound(id: "import-chop-\(i)-" + UUID().uuidString,
                                 name: "\(short) \(String(format: "%02d", i + 1))", category: .chop, fileURL: url,
                                 start: starts[i], end: i < 15 ? starts[i + 1] : duration, rootNote: root, source: "import")
        }
        let loadMs = await loadBanks([(.d, sounds)])
        guard serial == digSerial else { return true }
        guard (0..<16).allSatisfy({ state.engine.sound(for: PadID(.d, $0))?.id == sounds[$0]?.id }) else { return false }

        let bars = max(1, min(8, demo?.bars ?? 4))
        let chords = (demo?.chords ?? []).map { ChordInfo.parse($0) }
        var loop = LoopEntry(id: "import-" + DemoSamples.normalize(name), file: url.path, name: label, instrument: "sample",
                             bpm: demo?.bpm ?? 90, bars: bars, durationSec: duration)
        loop.key = keyText
        loop.slices16Sec = starts
        loop.chordsPerBar = demo?.chords
        loop.source = "import"
        let chordsLabel = chords.compactMap { $0?.symbol }.joined(separator: " ")
        let chopSet = ChopSet(loop: loop, spanBars: bars, spanSec: duration, starts: starts, sounds: sounds, chords: chords,
                              bassPerBeat: [], keyPC: key?.pc, keyMinor: key?.minor ?? false, rootNote: root,
                              chordsLabel: chordsLabel)
        session = Session(drumStyle: .dilla, sampleStyle: .dilla, bars: 4, laidback: 0.8, energy: 0.55, chops: chopSet,
                          harmony: BassWriter.Harmony(chopSet))
        state.scaleKey = keyText
        state.sampleLabel = "\(label) · \(keyText ?? "—")"
        state.chordsLabel = chordsLabel
        state.styleLabel = library.styleInfo(.dilla).label
        state.bank = .d
        state.selectedPad = PadID(.d, 0)

        let bpm = demo?.flipBpm ?? 90
        var p = Pattern(bars: 4, swing: 58)
        p.lanes = Self.starterFlip(bars: 4)
        apply(p, bpm: bpm, swing: 58)
        state.addLog("FLIP", "▸ 16 chops · \(keyText ?? "?") · \(Int(bpm.rounded())) BPM", ms: loadMs, tint: .blue)
        DebugLog.event("import_flip", ["name": label, "key": keyText ?? "", "bpm": bpm, "demo": demo != nil,
                                       "slices": starts.map { ($0 * 1000).rounded() / 1000 }, "ms": Self.ms(t0)])
        startGPT(KeywordParser.parse("flip the sample", grooves: library.grooves), take: [.chops], flip: true, serial: serial)
        return true
    }

    /// J Dilla-ish starter flip on bank D (0-based slices; slice n = beat n of the 4-bar loop): a 2-bar phrase
    /// 1 1 3 5 / 2 6 7 5, then a dotted push on bar 3's beats and a turnaround on bar 4's; 2 and 4 drag late
    /// (fractions of a 16th). Hits sit ≥ 1 beat apart so un-stretched beat-long chops never overlap (bank D is polyphonic).
    static func starterFlip(bars: Int) -> [PadID: [Hit]] {
        let phrase: [(step: Int, slice: Int, vel: Int, late: Double)] = [
            (0, 0, 116, 0), (4, 0, 92, 0.22), (8, 2, 106, 0.06), (12, 4, 98, 0.24),
            (16, 1, 112, 0), (20, 5, 96, 0.2), (24, 6, 106, 0.06), (28, 4, 94, 0.26),
            (32, 8, 114, 0), (38, 8, 88, 0.12), (42, 10, 104, 0.16),
            (48, 12, 112, 0), (52, 13, 98, 0.2), (56, 14, 104, 0.06), (60, 15, 94, 0.26)]
        let total = max(1, bars) * 16
        var lanes: [PadID: [Hit]] = [:]
        var rep = 0
        while rep * 64 < total {
            for h in phrase where rep * 64 + h.step < total {
                lanes[PadID(.d, h.slice), default: []].append(Hit(step: rep * 64 + h.step, velocity: h.vel, offset: h.late))
            }
            rep += 1
        }
        return lanes.mapValues { $0.sorted { $0.step < $1.step } }
    }

    /// GPT/local flips write slices on bank B; an imported song's chops live on `bank`: move them there (humanized a little).
    static func moveChops(_ p: Pattern, to bank: Bank) -> Pattern {
        let moved = p.lanes.filter { $0.key.bank == .b }
        guard bank != .b, !moved.isEmpty else { return p }
        var out = p
        out.lanes = p.lanes.filter { $0.key.bank != .b && $0.key.bank != bank }
        out.late = p.late.filter { $0.key.bank != .b && $0.key.bank != bank }
        for (k, hits) in moved {
            out.lanes[PadID(bank, k.index)] = hits.map { h in
                var h = h
                if h.offset == 0, h.step % 4 != 0 { h.offset = 0.12 }
                if h.step % 4 != 0 { h.velocity = min(h.velocity, 94) }
                return h
            }
        }
        return out
    }
}
