import AVFoundation
import Foundation

/// One-pad edits from the lid: ‹ › swaps in the next library sound of the same type, and the pad editor trims a
/// pad's start / end. Every change is one UNDO step.
extension Orchestrator {
    /// Library one-shots can be swapped; slices of a loop, takes and imported files can't.
    func canSwap(_ pad: PadID) -> Bool {
        guard let s = state.sound(pad), ![.chop, .loop].contains(s.category) else { return false }
        return !library.candidates(s.category.rawValue).isEmpty
    }

    /// ‹ › : the next (step +1) or previous (−1) sound of the pad's type, ranked for the current style.
    func swapSound(_ pad: PadID, step: Int) async {
        guard canSwap(pad), let cur = state.sound(pad) else { return }
        let style = session?.drumStyle ?? .boombap
        var rng = SeededRNG(seed: 0xC4A7E)   // same order every time, so ‹ and › walk one list
        let ranked = Retrieval.ranked(library, category: cur.category.rawValue, style: style,
                                      target: library.styleInfo(style).kit, rng: &rng)
        guard ranked.count > 1 else { return }
        let at = ranked.firstIndex { $0.id == cur.id } ?? (step > 0 ? -1 : 0)
        let next = ranked[((at + step) % ranked.count + ranked.count) % ranked.count]
        let snd = Retrieval.padSound(next, lib: library)
        checkpoint("\(pad.bank.letter)\(pad.number) sound")
        var bank: [Int: PadSound] = [:]
        for i in 0..<16 {
            let id = PadID(pad.bank, i)
            if let s = state.engine.sound(for: id) ?? state.sounds[id] { bank[i] = s }
        }
        bank[pad.index] = snd
        let ms = await loadBanks([(pad.bank, bank)])
        state.hit(pad)
        state.addLog("KIT", "\(pad.bank.letter)\(pad.number) ← \(snd.name)", ms: ms, tint: .orange)
        DebugLog.event("swap", ["pad": "\(pad.bank.letter)\(pad.number)", "id": snd.id, "step": step])
    }

    // MARK: Session after a project opens

    /// Projects don't store the AI session. Rebuild it from the pads (the library loop behind bank B's chops) and the
    /// saved style label, so ‹ › on a chop, FLIP IT and the bass keep working after a relaunch. Imported songs and
    /// beats without a library sample get no session, as before.
    func restoreSession() {
        session = nil
        let chopSounds = (0..<16).compactMap { state.engine.sound(for: PadID(.b, $0)) ?? state.sounds[PadID(.b, $0)] }
        guard let path = chopSounds.first?.fileURL.standardizedFileURL.path,
              let loop = library.loops.first(where: { library.fileURL($0.file).standardizedFileURL.path == path })
        else { return }
        let bars = max(1, state.engine.pattern.bars)
        let chops = Retrieval.chops(loop, lib: library, bars: bars)
        let sampleStyle = Style.allCases.max { loop.style($0) < loop.style($1) } ?? .boombap
        let label = state.styleLabel.uppercased()
        let drumStyle = Style.allCases.first { library.styleInfo($0).label.uppercased() == label } ?? sampleStyle
        session = Session(drumStyle: drumStyle, sampleStyle: sampleStyle, bars: bars, laidback: 0.5, energy: 0.5,
                          chops: chops, harmony: BassWriter.Harmony(chops))
        DebugLog.event("session_restore", ["loop": loop.id, "drum": drumStyle.rawValue, "sample": sampleStyle.rawValue])
    }

    // MARK: Sample swap (crate digging)

    /// The beat's sample (bank B chops from a DIG) can be swapped for another library loop; an imported song can't.
    func canSwapSample(_ pad: PadID) -> Bool {
        guard pad.bank == .b, chopBank == .b, let c = session?.chops, let s = state.sound(pad) else { return false }
        return c.sounds.values.contains { $0.fileURL == s.fileURL }
    }

    /// ‹ › on a chop: the previous / next library loop for this beat (same instrument and style, close to the tempo),
    /// chopped onto bank B under the same rhythm while the beat keeps playing. The bass follows the new chords.
    /// One UNDO step each; no GPT round trip, so it's instant.
    func swapSample(step: Int) async {
        guard var s = session, let cur = s.chops else { return }
        let e = state.engine
        let bars = max(1, e.pattern.bars)
        let req = LoopRequest(sampleStyle: s.sampleStyle, drumStyle: s.drumStyle, instrument: cur.loop.instrument,
                              bars: bars, bpm: currentBPM(state))
        if !sampleCrate.contains(where: { $0.id == cur.loop.id }) {
            sampleCrate = Retrieval.rankedLoops(library, req, seed: 0x5A3D)
        }
        let ranked = sampleCrate
        guard ranked.count > 1 else { return }
        let at = ranked.firstIndex { $0.id == cur.loop.id } ?? (step > 0 ? -1 : 0)
        let next = ranked[((at + step) % ranked.count + ranked.count) % ranked.count]
        checkpoint("sample \(cur.loop.name)")
        digSerial += 1                      // a GPT rewrite still in flight was for the old sample
        gptTask?.cancel()
        gptTask = nil
        let chops = Retrieval.chops(next, lib: library, bars: bars)
        let ms = await loadBanks([(.b, chops.sounds)])
        var p = e.pattern
        if chops.spanBars != cur.spanBars {
            p.lanes = p.lanes.filter { $0.key.bank != .b }
            for (k, v) in PatternBuilder.chops(span: chops.spanBars, bars: bars) { p.lanes[k] = v }
        }
        let harmony = BassWriter.Harmony(chops)
        if p.notes[PadID(.c, 0)] != nil {
            p.notes[PadID(.c, 0)] = BassWriter.write(rhythm: BassWriter.rhythm(library, style: s.drumStyle), bars: bars,
                                                     harmony: harmony, kicks: PatternBuilder.kickSteps(p.lanes),
                                                     padRoot: bassRoot())
        }
        s.chops = chops
        s.harmony = harmony
        session = s
        setLabels(drum: s.drumStyle, chops: chops)
        setTempo(next.bpm, checkpoint: false)
        e.setPattern(p, timing: e.isPlaying ? .nextBar : .now)
        lastPattern = p
        logSample(chops, bpm: next.bpm, ms: ms)
        if !e.isPlaying { state.hit(state.selectedPad.bank == .b ? state.selectedPad : PadID(.b, 0)) }
        DebugLog.event("sample_swap", ["from": cur.loop.id, "to": next.id, "step": step, "ms": ms])
    }

    // MARK: Trim

    /// Seconds of audio in a pad's source file (cached).
    func sourceDuration(_ s: PadSound) -> Double {
        if let d = Self.durations[s.fileURL] { return d }
        let d = (try? AVAudioFile(forReading: s.fileURL)).map { Double($0.length) / max(1, $0.processingFormat.sampleRate) } ?? 0
        if d > 0 { Self.durations[s.fileURL] = d }
        return d
    }

    private static var durations: [URL: Double] = [:]

    /// A chop slice shares its edges with the slices next to it (same file, touching boundaries).
    func sharedEdges(_ pad: PadID) -> (prev: PadSound?, next: PadSound?) {
        guard let s = state.sound(pad) else { return (nil, nil) }
        func near(_ a: Double?, _ b: Double?) -> Bool { a != nil && b != nil && abs(a! - b!) < 0.002 }
        let prev = pad.index > 0 ? state.sound(PadID(pad.bank, pad.index - 1)) : nil
        let next = pad.index < 15 ? state.sound(PadID(pad.bank, pad.index + 1)) : nil
        return (prev.flatMap { $0.fileURL == s.fileURL && near($0.end, s.start) ? $0 : nil },
                next.flatMap { $0.fileURL == s.fileURL && near($0.start, s.end) ? $0 : nil })
    }

    /// The editor's START / END handles and knobs (seconds in the source file). Moving a slice edge moves the
    /// neighbouring slice's edge with it, like dragging the line between them.
    func trimPad(_ pad: PadID, start: Double? = nil, end: Double? = nil) async {
        guard var s = state.sound(pad) else { return }
        let dur = sourceDuration(s)
        guard dur > 0 else { return }
        var (prev, next) = sharedEdges(pad)
        let oldStart = s.start, oldEnd = s.end ?? dur
        if let t = start {
            let lo = prev.map { $0.start + 0.03 } ?? 0
            s.start = min(oldEnd - 0.02, max(lo, t))
            if prev != nil { prev!.end = s.start }
        }
        if let t = end {
            let hi = next.map { ($0.end ?? dur) - 0.03 } ?? dur
            let e = min(hi, max(s.start + 0.02, t))
            s.end = e >= dur - 0.0005 ? nil : e
            if next != nil { next!.start = e }
        }
        guard abs(s.start - oldStart) > 0.0005 || abs((s.end ?? dur) - oldEnd) > 0.0005 else { return }
        checkpoint("trim \(pad.bank.letter)\(pad.number)")
        var bank: [Int: PadSound] = [:]
        for i in 0..<16 {
            let id = PadID(pad.bank, i)
            if let x = state.engine.sound(for: id) ?? state.sounds[id] { bank[i] = x }
        }
        bank[pad.index] = s
        if let p = prev { bank[pad.index - 1] = p }
        if let n = next { bank[pad.index + 1] = n }
        _ = await loadBanks([(pad.bank, bank)])
        state.hit(pad)
        state.addLog("EDIT", String(format: "%@%d · %.2f – %.2f s", pad.bank.letter, pad.number, s.start, s.end ?? dur),
                     tint: Self.tint(pad.bank))
        DebugLog.event("trim", ["pad": "\(pad.bank.letter)\(pad.number)", "start": s.start, "end": s.end ?? dur])
    }

    static func tint(_ b: Bank) -> Tint { [.orange, .blue, .ochre, .grey][b.rawValue] }
}
