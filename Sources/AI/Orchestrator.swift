import Foundation
import Observation

/// What one DIG did (for the harness / self-test).
struct DigReport {
    var prompt: String
    var plan: Plan
    var totalMs = 0
    var jevMs: Int? = nil
    var retrievalMs = 0
    var loadMs = 0
    var kitIDs: [String] = []
    var loopID: String? = nil
    var superseded = false
}

/// "Jev reacts, GPT composes, your crates supply the sound."
/// dig(prompt): keyword plan → Jev plan race (900 ms) → local retrieval → 3 banks load in parallel → template + chops +
/// rule bass → apply (next bar if playing) → GPT arrangement in the background, swapped in on the next bar.
@MainActor
final class Orchestrator {
    let state: AppState
    let library: LibraryStore
    let jev = JevClient()
    let openAI = OpenAIClient()

    struct Session {
        var drumStyle: Style
        var sampleStyle: Style
        var bars: Int
        var laidback: Double
        var energy: Double
        var chops: ChopSet?
        var harmony: BassWriter.Harmony
        /// MIDI-only beats (house): the chord progression written on C2 (GPT refines it via "chords").
        var chordProg: ChordWriter.Progression? = nil
    }
    var session: Session?
    var lastPattern = Pattern.empty
    var digSerial = 0
    var lastPromptKey = ""
    var repeatCount = 0
    var gptTask: Task<Void, Never>?
    /// Last GPT arrangement that was applied (title/comment for the lid; raw data for the harness).
    var lastArrangement: Arrangement?

    // Performer state (Performer.swift)
    var performHooked = false
    var performPrevOnBar: ((Int) -> Void)?
    var performBusy = false
    var barsSinceFill = 8
    var lastFill = "none"
    var perfEnergy = 0.6
    var perfRotation = 0

    init(state: AppState, library: LibraryStore) {
        self.state = state
        self.library = library
        jev.warmUp()
        if library.isFallback { state.addLog("ERR", "library unreadable → DefaultKit", tint: .red) }
    }

    /// Hooks AppState's actions (onDig / onFlip / onPerformToggle) to this orchestrator.
    func wire() {
        Orchestrator.current = self
        state.onDig = { [weak self] p in self?.submit(p) }
        state.onFlip = { [weak self] in self?.submitFlip() }
        state.onPerformToggle = { [weak self] on in self?.submitPerform(on) }
    }

    nonisolated func submit(_ prompt: String) { Task { @MainActor in await self.dig(prompt) } }
    nonisolated func submitFlip() { Task { @MainActor in await self.dig("flip the sample") } }
    nonisolated func submitPerform(_ on: Bool) { Task { @MainActor in self.setPerform(on) } }

    @discardableResult
    func dig(_ prompt: String) async -> DigReport {
        let t0 = Date()
        digSerial += 1
        let serial = digSerial
        gptTask?.cancel()
        gptTask = nil
        state.isDigging = true
        DebugLog.event("dig_start", ["prompt": prompt])
        let key = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if key == lastPromptKey { repeatCount += 1 } else { repeatCount = 0; lastPromptKey = key }
        let variant = repeatCount
        let seed = Self.fnv(key) &+ UInt64(variant) &* 0x9E37_79B9

        if await handleCommand(prompt) {
            state.isDigging = false
            return DigReport(prompt: prompt, plan: KeywordParser.parse(prompt, grooves: library.grooves))
        }
        checkpoint(prompt.count > 28 ? String(prompt.prefix(26)) + "…" : prompt)
        var plan = KeywordParser.parse(prompt, grooves: library.grooves)
        let kwScope = plan.scope
        let kwStyle = plan.drumStyle
        let kwMs = Self.ms(t0)
        var report = DigReport(prompt: prompt, plan: plan)
        if jev.available, plan.scope != .flip {
            if let r = await jev.ask("plan", state: jevState(prompt), timeout: 0.9) {
                plan.merge(r.answers, ms: r.ms)
                report.jevMs = r.ms
                state.jevMs = r.ms
            } else {
                state.addLog("JEV", "timeout → keyword plan", tint: .grey)
            }
        }
        guard serial == digSerial else { report.superseded = true; return report }
        // An imported song flip keeps its chops: "dilla drums for this" stays drums-only whatever Jev guesses.
        if importedFlip, kwScope == .drumsOnly, [.fullBeat, .sampleOnly].contains(plan.scope) { plan.scope = .drumsOnly }
        // "make it more rnb": a named style that differs from the current drums restyles the kit + groove (sample stays),
        // instead of only nudging the swing.
        if plan.scope == .changeGroove, let ks = kwStyle, let cur = session?.drumStyle, ks != cur {
            plan.scope = .drumsOnly
            plan.drumStyle = ks
        }
        // "a slow sax" / "french jazz piano sample": an instrument and no drums is a sample request, whatever Jev guesses.
        if kwScope == .sampleOnly, [.drumsOnly, .singleSound, .changeGroove, .bassOnly].contains(plan.scope) { plan.scope = .sampleOnly }
        if session == nil, [.sampleOnly, .bassOnly, .changeGroove, .flip].contains(plan.scope) { plan.scope = .fullBeat }
        report.plan = plan
        logPlan(plan, kwMs: kwMs)

        switch plan.scope {
        case .fullBeat: await buildFull(plan, seed: seed, variant: variant, serial: serial, report: &report)
        case .drumsOnly: await buildDrums(plan, seed: seed, variant: variant, serial: serial, report: &report)
        case .sampleOnly: await buildSample(plan, seed: seed, variant: variant, serial: serial, report: &report)
        case .bassOnly: buildBass(plan, variant: variant, serial: serial)
        case .changeGroove: changeGroove(plan, serial: serial)
        case .singleSound: await singleSound(plan, seed: seed, report: &report)
        case .flip: flip(plan, seed: seed, serial: serial)
        }
        report.totalMs = Self.ms(t0)
        if serial == digSerial { state.isDigging = false }
        return report
    }

    /// Waits for the background GPT arrangement (harness / tests).
    func waitForBackground() async { await gptTask?.value }

    // MARK: - full beat

    func buildFull(_ plan: Plan, seed: UInt64, variant: Int, serial: Int, report: inout DigReport) async {
        let (ds, ss) = styles(plan)
        let bars = plan.bars ?? 4
        let laid = plan.laidback ?? PatternBuilder.defaultLaidback(ds)
        // House with no sample words: drums + MIDI bass + MIDI chord stabs, no loop/chops.
        let midiOnly = ChordWriter.wantsMidiOnly(plan.prompt, style: ds)
        let tR = Date()
        let target = Retrieval.kitTarget(library, style: ds, vintage: plan.vintage, brightness: plan.brightness, energy: plan.energy)
        let kit = Retrieval.kit(library, style: ds, target: target, seed: seed)
        let req = LoopRequest(sampleStyle: ss, drumStyle: ds, instrument: plan.instrument, mood: plan.mood, bars: bars,
                              bpm: plan.bpm, excludeID: variant > 0 ? session?.chops?.loop.id : nil)
        let chops = midiOnly ? nil : Retrieval.loop(library, req, seed: seed).map { Retrieval.chops($0, lib: library, bars: bars) }
        let bankC = Retrieval.bankC(library, style: ds, target: target, seed: seed)
        report.retrievalMs = Self.ms(tR)
        report.kitIDs = (0..<16).compactMap { kit[$0]?.id }
        report.loopID = chops?.loop.id
        logKit(ds, kit, ms: report.retrievalMs)

        report.loadMs = await loadBanks([(.a, kit), (.b, chops?.sounds ?? [:]), (.c, bankC)])
        guard serial == digSerial else { return }

        let groove = PatternBuilder.groove(library, style: ds, variant: variant)
        let bpm = chops?.loop.bpm ?? plan.bpm ?? tempoBpm(plan.tempo, style: ds)
        let swing = PatternBuilder.swing(style: ds, groove: groove, laidback: laid, lib: library)
        var p = Pattern(bars: bars, swing: swing)
        if let g = groove { p.lanes = PatternBuilder.drums(g, bars: bars, laidback: laid) }
        if let c = chops { for (k, v) in PatternBuilder.chops(span: c.spanBars, bars: bars) { p.lanes[k] = v } }
        let prog = midiOnly ? ChordWriter.progression(style: ds, key: ChordWriter.keyFromPrompt(plan.prompt)) : nil
        let harmony = prog?.harmony ?? chops.map { BassWriter.Harmony($0) } ?? session?.harmony ?? BassWriter.Harmony(keyPC: 9)
        let noBass = KeywordParser.hasAny(["no bass", "without bass", "no bassline"], plan.prompt.lowercased())
        if midiOnly ? !noBass : (plan.wantsBass ?? 1) >= 0.35 {
            p.notes[PadID(.c, 0)] = BassWriter.write(rhythm: BassWriter.rhythm(library, style: ds), bars: bars, harmony: harmony,
                                                     kicks: PatternBuilder.kickSteps(p.lanes), padRoot: bankC[0]?.rootNote)
        }
        if let pr = prog, bankC[1] != nil { p.notes[ChordWriter.pad] = ChordWriter.write(pr, bars: bars, style: ds) }
        session = Session(drumStyle: ds, sampleStyle: ss, bars: bars, laidback: laid, energy: plan.energy ?? 0.55,
                          chops: midiOnly ? nil : (chops ?? session?.chops), harmony: harmony, chordProg: prog)
        setLabels(drum: ds, chops: chops)
        if let pr = prog {
            // Key guard + scale lock follow the progression's key.
            state.scaleKey = pr.key
            state.chordsLabel = pr.label
            state.sampleLabel = "\(bankC[1]?.name ?? "KEYS") STABS · \(pr.key)"
        }
        apply(p, bpm: bpm, swing: swing)
        if let c = chops { logSample(c, bpm: bpm, ms: report.loadMs) }
        if p.notes[PadID(.c, 0)] != nil {
            state.addLog("BASS", "\(ds.rawValue) rule bass · \(bankC[0]?.name ?? "bass") · \(chops?.chordsLabel ?? prog?.label ?? "key root")",
                         tint: .ochre)
        }
        if let pr = prog, p.notes[ChordWriter.pad] != nil {
            state.addLog("KEYS", "▸ \(pr.label)", tint: .blue)
            DebugLog.event("chords", ["key": pr.key, "label": pr.label, "voicings": pr.chords.map(\.voicing),
                                      "pad": bankC[1]?.id ?? "", "root": bankC[1]?.rootNote ?? -1, "bpm": bpm])
        }
        startGPT(plan, take: prog != nil ? [.drums, .bass, .chords] : [.drums, .bass], flip: false, serial: serial)
    }

    // MARK: - shared helpers

    func styles(_ plan: Plan) -> (Style, Style) {
        let d = plan.drumStyle ?? plan.sampleStyle ?? session?.drumStyle ?? .boombap
        let s = plan.sampleStyle ?? plan.drumStyle ?? session?.sampleStyle ?? d
        return (d, s)
    }

    func tempoBpm(_ tempo: String?, style: Style) -> Double {
        let info = library.styleInfo(style)
        switch tempo {
        case "slow": return info.bpmRange.lowerBound
        case "upbeat", "fast": return info.bpmRange.upperBound
        default: return info.defaultBpm
        }
    }

    /// Loads banks in parallel (engine swaps each atomically), then mirrors them into state.sounds.
    func loadBanks(_ banks: [(Bank, [Int: PadSound])]) async -> Int {
        let t = Date()
        let engine = state.engine
        let jobs = banks.filter { !$0.1.isEmpty }
        // MockEngine isn't thread-safe (its loads are instant anyway): load sequentially. Real engines load in parallel.
        let errors: [String] = engine is MockEngine ? await { () async -> [String] in
            var errs: [String] = []
            for (bank, sounds) in jobs {
                do { try await engine.loadBank(bank, sounds: sounds) } catch { errs.append("bank \(bank.letter): \(error)") }
            }
            return errs
        }() : await withTaskGroup(of: String?.self) { group in
            for (bank, sounds) in jobs {
                group.addTask {
                    do { try await engine.loadBank(bank, sounds: sounds); return nil } catch { return "bank \(bank.letter): \(error)" }
                }
            }
            var errs: [String] = []
            for await e in group { if let e { errs.append(e) } }
            return errs
        }
        for e in errors {
            state.addLog("ERR", String(e.prefix(80)), tint: .red)
            DebugLog.event("error", ["where": "loadBank", "msg": String(e.prefix(300))])
        }
        var s = state.sounds
        for (bank, sounds) in jobs {
            s = s.filter { $0.key.bank != bank }
            for (i, snd) in sounds { s[PadID(bank, i)] = snd }
        }
        state.sounds = s
        return Self.ms(t)
    }

    /// Every bass/keys note (bank C) snaps into the loop's key: rule bass and GPT bass both pass through here.
    func keyGuarded(_ pattern: Pattern) -> Pattern {
        guard let k = Music.parseKey(state.scaleKey) else { return pattern }
        var p = pattern
        var moved = 0
        for (pad, notes) in p.notes where pad.bank == .c {
            p.notes[pad] = notes.map { n in
                var n = n
                let m = Music.snap(n.midi, keyPC: k.pc, minor: k.minor)
                if m != n.midi { moved += 1; n.midi = m }
                return n
            }
        }
        if moved > 0 { DebugLog.event("key_guard", ["moved": moved, "key": state.scaleKey ?? ""]) }
        // A flip re-orders the chops, so a bass that follows the original chord order clashes: flips get drums, no bass.
        if p.lanes.keys.contains(where: { $0.bank == .d }) { p.notes = p.notes.filter { $0.key.bank != .c || $0.key.index != 0 } }
        return p
    }

    func apply(_ pattern: Pattern, bpm: Double?, swing: Double?) {
        let e = state.engine
        let p = keyGuarded(pattern)
        if let b = bpm { if abs(e.bpm - b) > 0.001 { e.bpm = b }; state.bpm = b }
        if let s = swing { e.swing = s; state.swing = s }
        state.bars = p.bars
        lastPattern = p
        if e.isPlaying { e.setPattern(p, timing: .nextBar) } else { e.setPattern(p, timing: .now); e.play() }
        state.isPlaying = e.isPlaying
        DebugLog.event("pattern", ["bars": p.bars, "lanes": p.lanes.count, "hits": PatternBuilder.hitCount(p),
                                   "notes": PatternBuilder.noteCount(p), "swing": p.swing, "bpm": e.bpm])
    }

    func setLabels(drum: Style, chops: ChopSet?) {
        state.styleLabel = library.styleInfo(drum).label
        guard let c = chops else { return }
        state.sampleLabel = "\(c.loop.name) · \(c.loop.key ?? "—")"
        state.chordsLabel = c.chordsLabel
        state.scaleKey = c.loop.key
    }

    func jevState(_ prompt: String) -> String {
        let s = session
        let pads = s == nil ? "empty" : "A drums, B chops" + (lastPattern.notes.isEmpty ? "" : ", C bass")
        return "User request: \"\(prompt)\"\nCurrent session: bpm \(Int(state.bpm)); drum style \(s?.drumStyle.rawValue ?? "none"); "
            + "sample \(s?.chops?.loop.name ?? "none") (\(s?.chops?.loop.key ?? "-")); pads loaded: \(pads)."
    }

    static func ms(_ since: Date) -> Int { Int((Date().timeIntervalSince(since) * 1000).rounded()) }

    static func fnv(_ s: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100_0000_01B3 }
        return h
    }
}
