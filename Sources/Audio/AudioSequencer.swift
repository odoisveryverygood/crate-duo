import Foundation
import AVFoundation

// Sequencer + voice allocation for AudioEngine. Everything in this file runs on `q`
// unless noted (the timer, live triggers, pattern swaps and recording all hop onto `q`).

extension AudioEngine {

    // MARK: - Types

    /// One sampler voice: player → varispeed → bank mixer. Per-voice volume/rate apply immediately,
    /// so a voice is only (re)allocated when it is idle *now* (busyUntil ≤ now).
    final class Voice {
        let player = AVAudioPlayerNode()
        let varispeed = AVAudioUnitVarispeed()
        let bank: Bank
        let slot: Int
        var busyUntil: Double = 0     // host seconds when its scheduled audio ends
        var startAt: Double = 0       // host seconds when its scheduled audio starts
        var pad: PadID?
        var live = false              // started by trigger() (release() applies)
        var fading = false
        var token = 0                 // bumps on every (re)allocation / cancel
        init(bank: Bank, slot: Int) { self.bank = bank; self.slot = slot }
    }

    /// A pattern hit or note, resolved to a pad. `offset` already includes `pattern.late[pad]`.
    struct SeqEvent {
        var pad: PadID
        var velocity: Int
        var offset: Double
        var ratchet: Int
        var midi: Int?
        var length: Double?
    }

    /// Pattern indexed by step for O(1) lookup while scheduling.
    struct CompiledPattern {
        var pattern: Pattern
        var byStep: [[SeqEvent]]
        var total: Int { byStep.count }

        init(_ p: Pattern) {
            pattern = p
            let total = max(1, p.bars) * 16
            var steps = [[SeqEvent]](repeating: [], count: total)
            for (pad, hits) in p.lanes {
                let late = p.late[pad] ?? 0
                for h in hits where h.velocity > 0 {
                    let s = ((h.step % total) + total) % total
                    steps[s].append(SeqEvent(pad: pad, velocity: h.velocity, offset: h.offset + late,
                                             ratchet: max(1, h.ratchet), midi: nil, length: nil))
                }
            }
            for (pad, notes) in p.notes {
                let late = p.late[pad] ?? 0
                for n in notes where n.velocity > 0 {
                    let s = ((n.step % total) + total) % total
                    steps[s].append(SeqEvent(pad: pad, velocity: n.velocity, offset: late,
                                             ratchet: 1, midi: n.midi, length: n.length))
                }
            }
            byStep = steps
        }

        var hitCount: Int {
            pattern.lanes.values.reduce(0) { $0 + $1.count } + pattern.notes.values.reduce(0) { $0 + $1.count }
        }
    }

    /// Step ↔ host-time mapping (piecewise linear across BPM changes). Also published for position().
    struct Timeline {
        var playing = false
        var anchorStep = 0
        var anchorTime: Double = 0
        var sps: Double = 60.0 / 90.0 / 4.0
        var prevStep = 0
        var prevTime: Double = 0
        var prevSps: Double = 60.0 / 90.0 / 4.0
        var hasPrev = false

        func position(at t: Double) -> Double {
            guard playing else { return 0 }
            let p: Double
            if hasPrev && t < anchorTime {
                p = Double(prevStep) + (t - prevTime) / prevSps
            } else {
                p = Double(anchorStep) + (t - anchorTime) / sps
            }
            return max(0, p)
        }
    }

    struct SkipKey: Hashable { let step: Int; let pad: PadID }

    // MARK: - Choke groups

    /// Does an event on `cutter` cut the sound of `victim`?
    /// Bank B is mono across the bank (every chop cuts the previous chop: they're slices of one loop).
    /// Bank C is mono/legato per pad (the 808 line never overlaps itself, but it doesn't cut the keys pad),
    /// except the chord pads (C2 keys, C3 synth), which are polyphonic so chord tones ring together.
    /// Bank A: hats (4, 5) and the open hat itself cut the open hat (6). Bank D is polyphonic.
    static func cuts(_ cutter: PadID, _ victim: PadID) -> Bool {
        switch victim.bank {
        case .b: return cutter.bank == .b
        case .d: return cutter.bank == .d   // imported/flip chops: one slice at a time
        case .c: return cutter == victim && !isPoly(victim)
        case .a: return victim.index == 6 && cutter.bank == .a && (4...6).contains(cutter.index)
        case .d: return false
        }
    }

    /// Polyphonic pads inside the otherwise mono bank C (chords; notes still end at their NoteEvent length).
    static func isPoly(_ pad: PadID) -> Bool { pad.bank == .c && (1...2).contains(pad.index) }

    static func canBeCut(_ pad: PadID) -> Bool {
        pad.bank == .b || pad.bank == .d || (pad.bank == .c && !isPoly(pad)) || (pad.bank == .a && pad.index == 6)
    }

    static func cutsSomething(_ pad: PadID) -> Bool {
        pad.bank == .b || pad.bank == .d || (pad.bank == .c && !isPoly(pad)) || (pad.bank == .a && (4...6).contains(pad.index))
    }

    /// Root used for NoteEvents: the pad's rootNote, else 36 for 808/bass and 60 otherwise (BUILD.md §6 convention).
    static func rootNote(_ s: PadSound) -> Int {
        s.rootNote ?? ((s.category == .eight08 || s.category == .bass) ? 36 : 60)
    }

    // MARK: - Timeline helpers

    func stepTime(_ s: Int) -> Double { anchorTime + Double(s - anchorStep) * sps }

    func swingDelay(_ s: Int) -> Double { (s & 1) == 1 ? (2 * swingQ / 100 - 1) : 0 }

    static func floorDiv(_ a: Int, _ b: Int) -> Int { a >= 0 ? a / b : -((-a + b - 1) / b) }

    func reanchor(step: Int, time: Double, keepPrev: Bool) {
        if keepPrev && timelineQ.playing && anchorTime <= Clock.now() {
            timelineQ.prevStep = anchorStep
            timelineQ.prevTime = anchorTime
            timelineQ.prevSps = sps
            timelineQ.hasPrev = true
        } else if !keepPrev {
            timelineQ.hasPrev = false
        }
        anchorStep = step
        anchorTime = time
        timelineQ.anchorStep = step
        timelineQ.anchorTime = time
        timelineQ.sps = sps
        publishTimeline()
    }

    func publishTimeline() {
        let tl = timelineQ
        stateLock.withLock { shared.timeline = tl }
    }

    func publishPattern() {
        let p = (pending ?? active).pattern
        stateLock.withLock { shared.pattern = p }
    }

    // MARK: - Transport (q)

    func startTransport() {
        guard !playingQ else { return }
        if !isRunning {
            do { try start() } catch {
                stateLock.withLock { shared.playing = false }
                DebugLog.event("audio_error", ["where": "play_start", "error": "\(error)"])
                return
            }
        }
        guard stateLock.withLock({ shared.playing }) else { return }   // stop() arrived first
        playingQ = true
        if let p = pending { active = p; pending = nil; logPatternApplied(active) }
        fills.removeAll()
        skipOnce.removeAll()
        nextStep = 0
        schedBar = 0
        if repeatLen > 0 { captureRepeat(from: 0) }
        anchorStep = 0
        anchorTime = Clock.now() + Self.startDelay
        timelineQ = Timeline(playing: true, anchorStep: 0, anchorTime: anchorTime, sps: sps)
        let tl = timelineQ
        stateLock.withLock {
            shared.timeline = tl
            shared.transportGen += 1
        }
        DebugLog.event("play", ["bpm": (60 / sps / 4 * 100).rounded() / 100, "bars": active.pattern.bars])
        tick()
    }

    func stopTransport() {
        let was = playingQ
        playingQ = false
        timelineQ.playing = false
        publishTimeline()
        guard was else { return }
        let now = Clock.now()
        // Cancel scheduled-but-not-started events; sounding voices ring out.
        for v in allVoices where v.pad != nil && !v.live && v.startAt > now + 0.002 { cancel(v) }
        fills.removeAll()
        skipOnce.removeAll()
        DebugLog.event("stop")
    }

    func applyPattern(_ p: Pattern, timing: ApplyTiming) {
        let c = CompiledPattern(p)
        if timing == .now || !playingQ {
            active = c
            pending = nil
            logPatternApplied(c)
        } else {
            pending = c
        }
    }

    func logPatternApplied(_ c: CompiledPattern) {
        DebugLog.event("pattern_applied", ["bars": c.pattern.bars, "hits": c.hitCount,
                                           "lanes": c.pattern.lanes.count, "noteLanes": c.pattern.notes.count])
    }

    /// BPM change: re-anchor at the next unscheduled step (already-scheduled steps keep the old tempo).
    func applyBpm(_ v: Double) {
        let newSps = 60.0 / v / 4.0
        guard abs(newSps - sps) > 1e-9 else { return }
        if playingQ {
            let t = stepTime(nextStep)
            let step = nextStep
            sps = newSps
            if step != anchorStep { reanchor(step: step, time: t, keepPrev: true) }
            else { timelineQ.sps = newSps; publishTimeline() }
        } else {
            sps = newSps
            timelineQ.sps = newSps
            publishTimeline()
        }
        fxQ.async { if self.fxTypeQ != .comb { self.delayFX.delayTime = self.fxDelayTime(for: self.fxTypeQ, sps: newSps) } }
    }

    // MARK: - Clock tick (q, every 5 ms)

    func tick() {
        guard playingQ else { return }
        let now = Clock.now()
        if !engine.isRunning {   // interrupted / stopped underneath us: retry at most once a second
            if now - lastRestartAttempt > 1.0 { restartOnQ(reason: "tick") }
            return
        }
        // Stalled (debugger, app suspended)? Skip missed steps instead of bursting them late.
        if stepTime(nextStep) < now - 0.03 {
            var s = nextStep
            var guardCount = 0
            while stepTime(s) < now && guardCount < 100_000 {
                if s % 16 == 0 { enterBar(s / 16) }
                s += 1; guardCount += 1
            }
            nextStep = s
        }
        let horizon = now + Self.lookahead + 0.5 * sps   // +½ step so early (negative-offset) hits are still ≥ lookahead ahead
        var n = 0
        while stepTime(nextStep) < horizon && n < 64 {
            scheduleStep(nextStep, now: now)
            nextStep += 1
            n += 1
        }
    }

    func scheduleStep(_ s: Int, now: Double) {
        let bar = Self.floorDiv(s, 16)
        if s - bar * 16 == 0 { enterBar(bar) }
        schedBar = bar
        for ev in events(at: s) { scheduleEvent(ev, step: s, now: now) }
    }

    /// Bar boundary: apply a pending (.nextBar) pattern, log fills, fire onBar on main at the bar's host time.
    func enterBar(_ bar: Int) {
        schedBar = bar
        if let p = pending {
            active = p
            pending = nil
            logPatternApplied(p)
        }
        if let f = fills[bar] { DebugLog.event("fill", ["bar": bar, "id": f.id]) }
        for k in fills.keys where k < bar - 1 { fills.removeValue(forKey: k) }
        let barTime = stepTime(bar * 16)
        let gen = stateLock.withLock { shared.transportGen }
        let delay = max(0, barTime - Clock.now())
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.stateLock.withLock({ self.shared.transportGen }) == gen else { return }
            self.onBar?(bar)
        }
    }

    func compiled(forBar bar: Int) -> CompiledPattern {
        if bar > schedBar, let p = pending { return p }
        return active
    }

    /// All events at absolute step `s`; BEAT REPEAT (PAD FX) remaps steps ≥ repeatFrom onto the captured slice.
    func events(at s: Int) -> [SeqEvent] {
        guard repeatLen > 0, s >= repeatFrom else { return naturalEvents(at: s) }
        let src: Int
        if repeatLen == 1 {
            src = repeatHit
        } else {
            let b = Self.floorDiv(repeatHit, repeatLen) * repeatLen
            src = b + ((s - b) % repeatLen + repeatLen) % repeatLen
        }
        var evs = naturalEvents(at: src)
        if repeatRatchet > 1 { for i in evs.indices { evs[i].ratchet = min(8, evs[i].ratchet * repeatRatchet) } }
        return evs
    }

    /// The pattern (looped over totalSteps) with bar fills applied to bank-A lanes.
    func naturalEvents(at s: Int) -> [SeqEvent] {
        let bar = Self.floorDiv(s, 16)
        let inBar = s - bar * 16
        let comp = compiled(forBar: bar)
        var out = comp.byStep[((s % comp.total) + comp.total) % comp.total]
        if !fills.isEmpty {
            if let f = fills[bar] { applyFill(f.ops, inBar: inBar, nextBarOps: false, comp: comp, into: &out) }
            if let f = fills[bar - 1] { applyFill(f.ops, inBar: inBar, nextBarOps: true, comp: comp, into: &out) }
        }
        return out
    }

    private func applyFill(_ ops: [FillOp], inBar: Int, nextBarOps: Bool, comp: CompiledPattern, into out: inout [SeqEvent]) {
        for op in ops {
            switch op.op {
            case "clear" where !nextBarOps:
                guard inBar >= (op.fromStep ?? 0), let lanes = op.lanes else { continue }
                let idx = Set(lanes.compactMap { BankA.index(forLane: $0) })
                if !idx.isEmpty { out.removeAll { $0.pad.bank == .a && idx.contains($0.pad.index) } }
            case "add" where !nextBarOps, "addNextBar" where nextBarOps:
                guard let lane = op.lane, let pad = BankA.pad(forLane: lane), let hits = op.hits else { continue }
                let late = comp.pattern.late[pad] ?? 0
                for h in hits where h.count >= 2 && Int(h[0].rounded()) == inBar && h[1] > 0 {
                    out.append(SeqEvent(pad: pad, velocity: Int(h[1].rounded()),
                                        offset: (h.count > 2 ? h[2] : 0) + late,
                                        ratchet: h.count > 3 ? max(1, Int(h[3].rounded())) : 1,
                                        midi: nil, length: nil))
                }
            default:
                continue
            }
        }
    }

    // MARK: - Scheduling events

    func scheduleEvent(_ ev: SeqEvent, step s: Int, now: Double) {
        if !skipOnce.isEmpty, skipOnce.remove(SkipKey(step: s, pad: ev.pad)) != nil { return }
        guard ev.velocity > 0, let pa = audio(for: ev.pad) else { return }
        let base = stepTime(s) + (swingDelay(s) + ev.offset) * sps
        let r = max(1, min(8, ev.ratchet))
        let semis = semitones(for: ev, audio: pa)
        let cuttable = Self.canBeCut(ev.pad)
        for k in 0..<r {
            let t = max(base + Double(k) * sps / Double(r), now + 0.003)
            let vel = Int((Double(ev.velocity) * pow(0.85, Double(k))).rounded())
            var end: Double? = nil
            if let len = ev.length { end = t + max(0.25, len) * sps }
            if cuttable, let cut = nextCutTime(victim: ev.pad, after: t, fromStep: s) { end = min(end ?? cut, cut) }
            startVoice(pa, pad: ev.pad, at: t, velocity: vel, semitones: semis, endAt: end, live: false, now: now)
        }
    }

    func semitones(for ev: SeqEvent, audio pa: PadAudio) -> Double {
        guard let midi = ev.midi else { return 0 }
        let root = Self.rootNote(pa.sound)
        var m = midi
        // Octave-fold safety net for 808/bass (idempotent with the pattern builders' fold).
        if pa.sound.category == .eight08 || pa.sound.category == .bass { m = Music.fold(midi, near: root) }
        return Double(max(-36, min(36, m - root)))
    }

    /// Earliest time > t at which a pattern event cuts `victim` (mono groups / hat choke). Scans up to 2 bars ahead.
    func nextCutTime(victim: PadID, after t: Double, fromStep s: Int) -> Double? {
        let eps = 0.004
        var best: Double? = nil
        for s2 in s..<(s + 33) {
            let st = stepTime(s2)
            if let b = best, st - 0.5 * sps > b { break }
            for ev in events(at: s2) where Self.cuts(ev.pad, victim) {
                guard audio(for: ev.pad) != nil else { continue }
                let base = st + (swingDelay(s2) + ev.offset) * sps
                let r = max(1, min(8, ev.ratchet))
                for k in 0..<r {
                    let tk = base + Double(k) * sps / Double(r)
                    if tk > t + eps {
                        if best == nil || tk < best! { best = tk }
                        break
                    }
                }
            }
        }
        return best
    }

    // MARK: - Voices

    /// Schedule `pa` on a free voice. `at == nil` = as soon as possible (live).
    /// `endAt` truncates (frame-limited copy with a ~3 ms fade) for chokes / note lengths.
    func startVoice(_ pa: PadAudio, pad: PadID, at t: Double?, velocity: Int, semitones: Double,
                    endAt: Double?, live: Bool, now: Double) {
        guard let fmt = engineFormat, isRunning,
              pa.buffer.format.sampleRate == fmt.sampleRate, pa.buffer.format.channelCount == fmt.channelCount else { return }
        let rate = Float(min(4, max(0.25, pow(2.0, semitones / 12) * Double(rateMulQ))))
        let sr = fmt.sampleRate
        let start = t ?? now
        var buffer = pa.buffer
        var dur = Double(pa.frames) / sr / Double(rate)
        if let e = endAt, e - start < dur - 0.003 {
            let d = max(0.006, e - start)
            let frames = min(pa.frames, Int(d * sr * Double(rate)))
            let fade = Int(0.012 * sr * Double(rate))
            if let cut = Loader.truncated(pa.buffer, frames: frames, fadeFrames: fade) {
                buffer = cut
                dur = d
            }
        }
        let v = allocateVoice(bank: pad.bank, now: now, rate: rate)
        v.token &+= 1
        v.pad = pad
        v.live = live
        v.fading = false
        v.startAt = start
        v.busyUntil = start + dur + 0.005
        let oldRate = v.varispeed.rate
        if oldRate != rate { v.varispeed.rate = rate }
        v.player.volume = Self.velocityGain(velocity)
        guard let t = t else {
            v.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            return
        }
        // AVAudioPlayerNode converts a host time to its own sample time using the rate it last *rendered* at,
        // so after a varispeed change a host-time start lands at Δ·r_old/r_new (measured: up to ±110 ms).
        // Fix: once the voice has rendered a few cycles at the new rate, the conversion is exact (measured ≤ 4 ms).
        if oldRate == rate {
            v.player.scheduleBuffer(buffer, at: AVAudioTime(hostTime: Clock.hostTicks(t)), options: [], completionHandler: nil)
        } else if t - now > Self.rateSettle + 0.02 {
            let tok = v.token
            q.asyncAfter(deadline: .now() + Self.rateSettle) {
                guard v.token == tok else { return }
                v.player.scheduleBuffer(buffer, at: AVAudioTime(hostTime: Clock.hostTicks(t)), options: [], completionHandler: nil)
            }
        } else {
            // Too close to defer: first-order correction (measured ≤ ~18 ms).
            let corrected = now + (t - now) * Double(rate) / Double(oldRate)
            v.player.scheduleBuffer(buffer, at: AVAudioTime(hostTime: Clock.hostTicks(corrected)), options: [], completionHandler: nil)
        }
    }

    /// How long a voice renders at a new varispeed rate before a host-time schedule is trusted.
    static let rateSettle = 0.028

    static func velocityGain(_ v: Int) -> Float {
        Float(pow(Double(max(1, min(127, v))) / 127.0, 1.6))
    }

    /// Round-robin over voices that are idle now (preferring one already at `rate`, so its host-time
    /// mapping is exact); steal the one that finishes soonest if none are idle.
    func allocateVoice(bank: Bank, now: Double, rate: Float) -> Voice {
        let pool = pools[bank.rawValue]
        let n = pool.count
        let startIdx = roundRobin[bank.rawValue]
        var firstIdle: Int? = nil
        for k in 0..<n {
            let i = (startIdx + k) % n
            guard pool[i].busyUntil <= now else { continue }
            if pool[i].varispeed.rate == rate {
                roundRobin[bank.rawValue] = (i + 1) % n
                return pool[i]
            }
            if firstIdle == nil { firstIdle = i }
        }
        if let i = firstIdle {
            roundRobin[bank.rawValue] = (i + 1) % n
            return pool[i]
        }
        var victim = pool[0]
        for v in pool where v.busyUntil < victim.busyUntil { victim = v }
        cancel(victim)
        roundRobin[bank.rawValue] = (victim.slot + 1) % n
        return victim
    }

    /// Stop a voice immediately (only used for voices that haven't started, or when stealing).
    func cancel(_ v: Voice) {
        v.token &+= 1
        v.player.stop()
        try? v.player.cratePlay()
        v.busyUntil = 0
        v.pad = nil
        v.live = false
        v.fading = false
    }

    /// Short volume ramp, then stop (mono cuts, KEYS note-off).
    func fade(_ v: Voice, over d: Double) {
        guard !v.fading else { return }
        let tok = v.token
        let startVol = v.player.volume
        v.fading = true
        v.live = false
        v.busyUntil = Clock.now() + d + 0.02
        v.player.volume = startVol * 0.7
        let steps = 4
        for i in 1...steps {
            q.asyncAfter(deadline: .now() + d * Double(i) / Double(steps)) {
                guard v.token == tok else { return }
                if i < steps {
                    v.player.volume = startVol * 0.7 * Float(steps - i) / Float(steps)
                } else {
                    v.player.volume = 0
                    self.cancel(v)
                }
            }
        }
    }

    // MARK: - Live (q)

    func liveTrigger(_ pad: PadID, velocity: Int, semitones: Double, tapTime: Double, record: Bool) {
        if !isRunning {
            do { try start() } catch { return }
        } else if !engine.isRunning {
            guard restartOnQ(reason: "trigger") else { return }
        }
        guard let pa = audio(for: pad) else { return }
        let now = Clock.now()
        let pool = pools[pad.bank.rawValue]
        if Self.cutsSomething(pad) {
            for v in pool where !v.fading && v.busyUntil > now && v.startAt <= now + 0.002 {
                if let vp = v.pad, Self.cuts(pad, vp) { fade(v, over: vp.bank == .b || vp.bank == .d ? 0.03 : 0.006) }
            }
        }
        var end: Double? = nil
        if playingQ && Self.canBeCut(pad) {
            let s = max(0, Int(timelineQ.position(at: now).rounded(.down)))
            end = nextCutTime(victim: pad, after: now + 0.003, fromStep: s)
        }
        startVoice(pa, pad: pad, at: nil, velocity: velocity, semitones: semitones, endAt: end, live: true, now: now)
        if record && playingQ && stateLock.withLock({ shared.recording }) {
            recordLive(pad, velocity: velocity, semitones: semitones, tapTime: tapTime, audio: pa)
        }
    }

    /// KEYS note-off: the UI calls this when the last finger lifts (or a single finger slides to a new key),
    /// so it fades every live voice of the pad (10 ms). No-op for unpitched one-shots (drums).
    func liveRelease(_ pad: PadID) {
        guard let pa = audio(for: pad), pa.sound.category.isPitched else { return }
        let now = Clock.now()
        for v in pools[pad.bank.rawValue] where v.live && !v.fading && v.pad == pad && v.busyUntil > now {
            fade(v, over: 0.010)
        }
    }

    // MARK: - Recording (q)

    /// Quantize a live hit to the nearest 16th (−25 ms latency compensation) and overdub it into the pattern.
    func recordLive(_ pad: PadID, velocity: Int, semitones: Double, tapTime: Double, audio pa: PadAudio) {
        let pos = timelineQ.position(at: tapTime - Self.recordLatency)
        let qStep = Int(pos.rounded())
        let semi = Int(semitones.rounded())
        let vel = max(1, min(127, velocity))
        let root = Self.rootNote(pa.sound)

        var p = active.pattern
        let step = Self.insert(into: &p, pad: pad, absStep: qStep, velocity: vel, semi: semi, root: root)
        active = CompiledPattern(p)
        if var pp = pending?.pattern {
            _ = Self.insert(into: &pp, pad: pad, absStep: qStep, velocity: vel, semi: semi, root: root)
            pending = CompiledPattern(pp)
        }
        // Already sounded live: don't let the scheduler play it again this pass.
        if qStep >= nextStep { skipOnce.insert(SkipKey(step: qStep, pad: pad)) }
        publishPattern()
        DebugLog.event("rec_hit", ["pad": "\(pad.bank.letter)\(pad.index)", "step": step, "abs": qStep, "semi": semi])
    }

    /// Returns the pattern step used.
    static func insert(into p: inout Pattern, pad: PadID, absStep: Int, velocity: Int, semi: Int, root: Int) -> Int {
        if p.bars < 1 { p.bars = 1 }
        let total = p.bars * 16
        let step = ((absStep % total) + total) % total
        if semi == 0 {
            var hits = p.lanes[pad] ?? []
            if let i = hits.firstIndex(where: { $0.step == step }) {
                hits[i].velocity = max(hits[i].velocity, velocity)
            } else {
                hits.append(Hit(step: step, velocity: velocity))
                hits.sort { $0.step < $1.step }
            }
            p.lanes[pad] = hits
        } else {
            var notes = p.notes[pad] ?? []
            let midi = root + semi
            notes.removeAll { $0.step == step && $0.midi == midi }
            notes.append(NoteEvent(step: step, length: 1, midi: midi, velocity: velocity))
            notes.sort { $0.step < $1.step }
            p.notes[pad] = notes
        }
        return step
    }
}
