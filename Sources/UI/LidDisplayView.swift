import SwiftUI

/// The black OLED lid, direction 05 COLOUR-CODED (design/directions/05-colour.html): title line + LOOP bar,
/// thin Inter hero readouts with the BANKS legend, a mode-dependent main area (SEQ dot grid / CHOP waveform /
/// KEYS waveform / AI log), ONE plain-language result line, ONE timing strip, then the `›` prompt with outlined chips.
/// Vertical rhythm follows the mock's 669×455 lid; narrow (book pose, ~455×669) stacks the legend and wraps the chips.
struct LidDisplayView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width * 1.05
            let narrow = geo.size.width < 560
            let side: CGFloat = narrow ? 24 : 28
            let hero: CGFloat = geo.size.width < 400 ? 48 : 58
            let focused = CrateUI.shared.promptFocused
            VStack(alignment: .leading, spacing: 0) {
                LidTitleRow(state: state, narrow: narrow)
                heroBlock(narrow: narrow, hero: hero)
                    .padding(.top, narrow ? 18 : 21.5)
                Group {
                    if focused {
                        DigComposer(state: state)
                    } else {
                        mainArea(portrait: portrait)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .padding(.top, narrow ? 22 : 26.5)
                Group {
                    if state.punch > 0.01 {
                        PunchStrip(punch: state.punch, fx: state.fx)
                    } else {
                        LidResultLine(state: state)
                            .accessibilityIdentifier(showsLogPanel(portrait) ? "ai-chips" : "ai-log")
                    }
                }
                .frame(height: 16)
                .padding(.top, 12)
                LidTimingStrip(state: state)
                    .frame(height: 8)
                    .padding(.top, 10)
                LidPromptRow(state: state, narrow: narrow, showChips: !focused)
                    .padding(.top, narrow ? 18 : 24)
            }
            .padding(.horizontal, side)
            .padding(.top, 26.5)
            .padding(.bottom, narrow ? 24 : 27)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Theme.oled)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private func heroBlock(narrow: Bool, hero: CGFloat) -> some View {
        if narrow {
            VStack(alignment: .leading, spacing: 20) {
                LidHero(state: state, size: hero, gap: 36)
                BankLegend(state: state)
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                LidHero(state: state, size: hero, gap: 44)
                Spacer(minLength: 0)
                BankLegend(state: state).frame(width: 166)
            }
        }
    }

    /// Modes whose main area is the AI log (the result line then isn't the "ai-log").
    private func showsLogPanel(_ portrait: Bool) -> Bool {
        switch state.mode {
        case .sample, .padFX, .levels16: return true
        case .seq: return portrait
        case .chop, .keys: return false
        }
    }

    @ViewBuilder
    private func mainArea(portrait: Bool) -> some View {
        switch state.mode {
        case .seq:
            if portrait {
                VStack(alignment: .leading, spacing: 16) {
                    SeqGridView(state: state, maxPitch: 30)
                        .frame(height: seqHeight)
                    AILogView(state: state, maxLines: 6, size: 10.5)
                    Spacer(minLength: 0)
                }
            } else {
                SeqGridView(state: state)
            }
        case .chop:
            ChopWaveView(state: state).padding(.bottom, 4)
        case .keys:
            KeysWaveView(state: state).padding(.vertical, 4)
        case .sample:
            VStack(alignment: .leading, spacing: 14) {
                if (0..<16).contains(where: { state.sound(PadID(.b, $0)) != nil }) {
                    ChopWaveView(state: state)
                        .frame(height: portrait ? 120 : 64)
                }
                AILogView(state: state, maxLines: portrait ? 10 : 4, size: 10.5)
                Spacer(minLength: 0)
            }
        case .padFX, .levels16:
            AILogView(state: state, maxLines: portrait ? 12 : 7, size: 10.5)
        }
    }

    /// Portrait SEQ: grid sized to its lanes, the log takes the rest.
    private var seqHeight: CGFloat {
        let rows = max(5, SeqRows.build(state, state.engine.pattern).count)
        return min(320, SeqGridView.fittedHeight(rows: rows, pitch: 30))
    }
}

// MARK: - Title line + LOOP segment bar

/// "J DILLA × JAZZ HOP   GRA PNO · G# · A#m7 – G#m9 …" top-left, "LOOP · 4 BARS ▬▬▬▭" top-right.
/// Long-press the title (the lid's wordmark position) to rotate the back screen.
struct LidTitleRow: View {
    let state: AppState
    var narrow = false

    var body: some View {
        Group {
            if narrow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        titleBlock(withSubtitle: false)
                        Spacer(minLength: 8)
                        LoopBar(state: state)
                    }
                    subtitleText
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 10, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    titleBlock(withSubtitle: true)
                    Spacer(minLength: 8)
                    LoopBar(state: state)
                }
            }
        }
        .frame(minHeight: 10)
    }

    private func titleBlock(withSubtitle: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            if state.isDigging {
                HStack(spacing: 7) {
                    DotSpinner(color: Theme.live, dot: 1.6)
                    Text("DIGGING").font(Theme.inter(9, 600)).tracking(9 * 0.12).foregroundStyle(Theme.lidInk)
                }
                .fixedSize()
            } else {
                Text(title)
                    .font(Theme.inter(9, 600))
                    .tracking(9 * 0.12)
                    .foregroundStyle(Theme.lidInk)
                    .lineLimit(1)
                    .fixedSize()
            }
            if withSubtitle {
                subtitleText
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("style-label")
        .contentShape(Rectangle())
        // Long-press cycles the back (outer) screen's rotation 0 → 90 → 180 → 270, for whichever way the Duo is held.
        .onLongPressGesture(minimumDuration: 0.6) {
            let d = UserDefaults.standard
            let next = (d.double(forKey: "crateCrowdTurn") + 90).truncatingRemainder(dividingBy: 360)
            d.set(next, forKey: "crateCrowdTurn")
            state.addLog("CROWD", "back screen rotated \(Int(next))°", tint: .grey)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logo")
    }

    private var subtitleText: Text {
        Text(subtitle)
            .font(Theme.inter(9, 500))
            .tracking(9 * 0.06)
            .foregroundStyle(Theme.lidGrey1)
    }

    private var title: String {
        if state.mode == .keys {
            let p = state.selectedPad
            let name = UIHelpers.padName(state, p) ?? "PAD \(p.bank.letter)\(p.number)"
            let src = state.sound(p)?.source ?? ""
            return src.isEmpty ? name : "\(name) · \(src.uppercased())"
        }
        let s = state.styleLabel.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? "CRATE" : s.uppercased()
    }

    private var subtitle: String {
        if state.isDigging {
            let p = state.prompt.trimmingCharacters(in: .whitespaces)
            return p.isEmpty ? "Jev is planning" : p
        }
        if state.mode == .keys {
            if !state.scaleLock { return "SCALE LOCK OFF · CHROMATIC" }
            return "SCALE LOCK · " + (UIHelpers.keyDisplay(state.scaleKey) ?? "NO KEY")
        }
        let parts = [state.sampleLabel.uppercased(), state.chordsLabel]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { return state.performOn ? "AI PERFORM ON" : "CR-16 · AI SAMPLER" }
        return parts.joined(separator: " · ")
    }
}

/// `LOOP · 4 BARS` + one 15×3 segment per bar: played bars grey, the current bar fills white as it plays.
/// KEYS mode prints the root and octave instead.
struct LoopBar: View {
    let state: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let f = LiveFrame(state)
            let empty = f.pattern.lanes.isEmpty && f.pattern.notes.isEmpty
            let bars = max(1, empty ? state.bars : f.bars)
            let shown = min(bars, 16)
            let w: CGFloat = bars <= 8 ? 15 : max(4, 144 / CGFloat(shown) - 3)
            let current = f.playing ? f.bar % shown : -1
            let progress = f.playing ? (f.local - Double(f.bar * 16)) / 16 : 0
            HStack(spacing: 9) {
                Text(label(bars))
                    .fieldLabel()
                    .foregroundStyle(Theme.lidGrey1)
                    .lineLimit(1)
                    .fixedSize()
                HStack(spacing: 3) {
                    ForEach(0..<shown, id: \.self) { i in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(i < current ? Theme.lidDone : Theme.lidGrey3)
                            if i == current {
                                Rectangle().fill(Theme.lidInk)
                                    .frame(width: max(1, w * CGFloat(min(1, max(0, progress)))))
                            }
                        }
                        .frame(width: w, height: 3)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let f = LiveFrame(state)
            let empty = f.pattern.lanes.isEmpty && f.pattern.notes.isEmpty
            let cur = max(1, empty ? state.bars : f.bars)
            let next = [1, 2, 4, 8].first { $0 > cur } ?? 1
            Orchestrator.current?.setBars(next)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to change the loop length")
        .accessibilityIdentifier("loop-bar")
        .accessibilityLabel("Loop")
    }

    private func label(_ bars: Int) -> String {
        if state.mode == .keys {
            let root = UIHelpers.rootNote(state, state.selectedPad)
            let base = KeysView.baseMidi(root: root, octave: state.keysOctave)
            let oct = (base + 7) / 12 - 1   // octave of the first C on the keyboard
            return "ROOT \(UIHelpers.noteName(root, flat: "♭")) · OCT \(oct)"
        }
        return "LOOP · \(bars) \(bars == 1 ? "BAR" : "BARS")"
    }
}

// MARK: - Hero readouts (thin Inter numerals, small caps labels)

/// SEQ / SAMPLE / 16 LVL: BPM · SWING · BAR. KEYS: NOTE · SEMI. CHOP: SLICE · BPM · BAR. PAD FX: <FX> % · BPM · BAR.
struct LidHero: View {
    let state: AppState
    var size: CGFloat = 58
    var gap: CGFloat = 44

    var body: some View {
        HStack(alignment: .top, spacing: gap) {
            switch state.mode {
            case .keys:
                let midi = CrateUI.shared.lastMidi
                let note = midi.map { UIHelpers.noteName($0) } ?? "--"
                readout(Text(note), plain: note, label: "NOTE", id: "note")
                let semi = CrateUI.shared.lastSemi.map { UIHelpers.signed($0) } ?? "0"
                readout(Text(semi), plain: semi, label: "SEMI", id: "semi")
            case .padFX:
                let v = String(format: "%03d", Int((state.punch * 100).rounded()))
                readout(Text(v), plain: v, label: (state.fx?.label ?? "PUNCH") + " %", id: "punch")
                live(swing: false)
            case .chop:
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                    let slice = currentSlice(LiveFrame(state), now: ctx.date)
                    let v = slice.map { String(format: "%02d", $0 + 1) } ?? "--"
                    readout(Text(v), plain: v, label: "SLICE", id: "slice")
                }
                live(swing: false)
            default:
                live(swing: true)
            }
        }
    }

    /// BPM, SWING and BAR polled from the engine (always what's actually playing).
    private func live(swing: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let f = LiveFrame(state)
            let bpm = state.engine.bpm.isFinite ? state.engine.bpm : state.bpm
            HStack(alignment: .top, spacing: gap) {
                let b = "\(Int(bpm.rounded()))"
                readout(Text(b), plain: b, label: "BPM", id: "bpm")
                    .contentShape(Rectangle())
                    .gesture(tempoDrag)
                if swing {
                    let s = "\(Int(state.engine.swing.rounded()))"
                    readout(Text(s), plain: s, label: "SWING", id: "swing")
                }
                let bar = Text("\(f.bar + 1)").foregroundStyle(Theme.lidInk)
                let beat = Text(".\(f.beat + 1)").foregroundStyle(Theme.lidGrey1)
                readout(Text("\(bar)\(beat)"), plain: f.barBeat, label: "BAR", id: "bar-beat")
            }
        }
    }

    @State private var dragStartBPM: Double?

    /// Drag the BPM number: up = faster, 1 BPM per 4 pt; one undo step per drag.
    private var tempoDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                guard let orch = Orchestrator.current else { return }
                if dragStartBPM == nil {
                    dragStartBPM = state.bpm
                    orch.checkpoint("tempo \(Int(state.bpm)) BPM")
                }
                orch.setTempo((dragStartBPM ?? state.bpm) - Double(g.translation.height) / 4, checkpoint: false)
            }
            .onEnded { _ in
                dragStartBPM = nil
                state.addLog("TEMPO", "\(Int(state.bpm)) BPM", tint: .orange)
            }
    }

    private func currentSlice(_ f: LiveFrame, now: Date) -> Int? {
        if let p = state.lastHitPad, p.bank == .b, now.timeIntervalSince(state.lastHitTime) < 1.2 { return p.index }
        return f.currentChop() ?? (state.selectedPad.bank == .b ? state.selectedPad.index : nil)
    }

    private func readout(_ value: Text, plain: String, label: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .fieldLabel()
                .foregroundStyle(Theme.lidGrey1)
                .lineLimit(1)
                .fixedSize()
                .frame(height: 6.5)
            value
                .font(Theme.interLight(size))
                .tracking(-0.04 * size)
                .monospacedDigit()
                .foregroundStyle(Theme.lidInk)
                .lineLimit(1)
                .fixedSize()
                .frame(height: size)   // CSS line-height: 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
        .accessibilityValue(plain)
    }
}

// MARK: - BANKS legend (the screen side of the deck's four bank keys)

struct BankLegend: View {
    let state: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let meters = BankMeters.levels(state, LiveFrame(state), now: ctx.date)
            VStack(spacing: 0) {
                HStack {
                    Text("BANKS").fieldLabel()
                    Spacer(minLength: 8)
                    Text("LEVEL").fieldLabel()
                }
                .foregroundStyle(Theme.lidGrey1)
                .frame(height: 6.5)
                .padding(.bottom, 6)
                ForEach(Bank.allCases, id: \.self) { b in
                    row(b, level: meters[b.rawValue])
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("bank-legend")
        .accessibilityLabel("Banks")
        .accessibilityValue("bank \(state.bank.letter)")
    }

    private func row(_ b: Bank, level: Double?) -> some View {
        let sel = b == state.bank
        let ink = sel ? Theme.lidInk : Theme.lidGrey1
        return HStack(spacing: 0) {
            Rectangle().fill(Theme.bank(b)).frame(width: 2, height: 8)
            Text(b.letter)
                .font(Theme.inter(7.5, 600))
                .foregroundStyle(ink)
                .frame(width: 18, alignment: .leading)
                .padding(.leading, 8)
            Text(Theme.bankName(b))
                .font(Theme.inter(6.8, 500))
                .tracking(6.8 * 0.13)
                .foregroundStyle(ink)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 64, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.lidGrey3)
                    Rectangle().fill(Theme.bank(b)).frame(width: g.size.width * CGFloat(level ?? 0))
                }
            }
            .frame(height: 1.5)
            Text(BankMeters.db(level))
                .font(Theme.mono(6.5))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(height: 16)
    }
}

/// Cheap per-bank meters: the bank's LEVEL fader, nudged up by the bank's most recent hit (sequencer or live).
enum BankMeters {
    /// 0…1 per bank, nil for an empty bank.
    static func levels(_ state: AppState, _ f: LiveFrame, now: Date) -> [Double?] {
        var recent = [Double](repeating: .infinity, count: 4)   // seconds since the bank last sounded
        if f.playing {
            for (pad, hits) in f.pattern.lanes {
                for h in hits {
                    recent[pad.bank.rawValue] = min(recent[pad.bank.rawValue], f.age(f.hitTime(h, pad)) * f.stepDur)
                }
            }
            for (pad, notes) in f.pattern.notes {
                for n in notes {
                    let a = f.age(Double(n.step) + f.swingDelay(n.step)) * f.stepDur
                    recent[pad.bank.rawValue] = min(recent[pad.bank.rawValue], a)
                }
            }
        }
        if let p = state.lastHitPad {
            recent[p.bank.rawValue] = min(recent[p.bank.rawValue], now.timeIntervalSince(state.lastHitTime))
        }
        var loaded = [Bool](repeating: false, count: 4)
        var faderSum = [Double](repeating: 0, count: 4)
        var faderN = [Double](repeating: 0, count: 4)
        for pad in state.sounds.keys {
            loaded[pad.bank.rawValue] = true
            faderSum[pad.bank.rawValue] += CrateUI.shared.level(pad)
            faderN[pad.bank.rawValue] += 1
        }
        for pad in f.pattern.lanes.keys { loaded[pad.bank.rawValue] = true }
        for pad in f.pattern.notes.keys { loaded[pad.bank.rawValue] = true }
        return (0..<4).map { i in
            guard loaded[i] else { return nil }
            let fader = faderN[i] > 0 ? faderSum[i] / faderN[i] : 0.66
            let env = recent[i].isFinite ? exp(-max(0, recent[i]) / 0.22) : 0
            let motion = f.playing ? 0.86 + 0.3 * env : 1 + 0.2 * env
            return min(1, max(0, fader * motion))
        }
    }

    /// dB on the deck fader's printed scale (0 · −6 · −12 · −24 · −∞ at 1 · ¾ · ½ · ¼ · 0).
    static func db(_ v: Double?) -> String {
        guard let v, v > 0.015 else { return "−∞" }
        let d: Double
        switch v {
        case 0.75...: d = -6 * (1 - v) / 0.25
        case 0.5..<0.75: d = -6 - (0.75 - v) / 0.25 * 6
        case 0.25..<0.5: d = -12 - (0.5 - v) / 0.25 * 12
        default: d = -24 - (0.25 - v) / 0.25 * 36
        }
        let r = Int(d.rounded())
        return r == 0 ? "0" : "−\(-r)"
    }
}

// MARK: - Result line + timing strip

/// What the latest DIG produced (or the latest event), parsed from the AI log.
struct LidSummary {
    struct Part {
        var text: String
        var color: Color?
    }

    var parts: [Part] = []
    var timings: [(key: String, value: String, ok: Bool)] = []

    init(_ state: AppState) {
        let log = state.log
        guard !log.isEmpty else {
            timings = Self.fallbackTimings(state)
            return
        }
        let start = log.lastIndex { $0.tag == "JEV" || $0.tag == "KW" } ?? log.startIndex
        var kitMs: Int?, sampleMs: Int?, planTag = "JEV", planMs: Int?, gpt: (ms: Int?, ok: Bool)?
        var digParts: [Part] = []
        for line in log[start...] {
            switch line.tag {
            case "JEV", "KW":
                planTag = line.tag
                planMs = line.ms ?? planMs
            case "KIT":
                kitMs = line.ms ?? kitMs
                digParts.append(Part(text: Self.kitPhrase(line.text), color: Theme.bank(.a)))
            case "SAMPLE":
                sampleMs = line.ms ?? sampleMs
                digParts.append(Part(text: Self.samplePhrase(line.text), color: Theme.bank(.b)))
            case "BASS":
                digParts.append(Part(text: "bass line", color: Theme.bank(.c)))
            case "GROOVE":
                digParts.append(Part(text: Self.sentence(line.text), color: Theme.bank(.a)))
            case "GPT":
                gpt = (line.ms, true)
            case "ERR":
                if line.text.hasPrefix("GPT") { gpt = (nil, false) }
                digParts.append(Part(text: line.text, color: Theme.red))
            default:
                break
            }
        }
        // The newest non-DIG event (crowd rotation, bounce, drop…) takes the line until the next DIG.
        let digTags: Set<String> = ["JEV", "KW", "KIT", "SAMPLE", "BASS", "GROOVE", "GPT", "ERR", "PERFORM"]
        if let last = log.last(where: { $0.tag != "PERFORM" }), !digTags.contains(last.tag) {
            parts = [Part(text: Self.sentence(last.tag.lowercased()) + " · " + last.text, color: Self.tint(last.tint))]
        } else {
            parts = Self.dedupe(digParts)
        }

        if let ms = planMs { timings.append((planTag, UIHelpers.msText(ms).spacedUnit, false)) }
        if let ms = kitMs { timings.append(("KIT", UIHelpers.msText(ms).spacedUnit, false)) }
        if let ms = sampleMs { timings.append(("SAMPLE", UIHelpers.msText(ms).spacedUnit, false)) }
        if let g = gpt {
            timings.append(("GPT", g.ms.map { UIHelpers.msText($0).spacedUnit } ?? (g.ok ? "" : "✗"), g.ok))
        }
        if timings.isEmpty { timings = Self.fallbackTimings(state) }
    }

    private static func fallbackTimings(_ state: AppState) -> [(key: String, value: String, ok: Bool)] {
        [("JEV", state.jevMs.map { "\($0) ms" } ?? "—", false),
         ("GPT", state.gptSeconds.map { String(format: "%.1f s", $0) } ?? "—", state.gptSeconds != nil)]
    }

    /// One tab per bank: repeated KIT / SAMPLE lines (a re-dig, a flip) keep only the newest.
    private static func dedupe(_ parts: [Part]) -> [Part] {
        var out: [Part] = []
        for p in parts {
            if let c = p.color, c != Theme.red, let i = out.firstIndex(where: { $0.color == c }) {
                out[i] = p
            } else {
                out.append(p)
            }
        }
        return out
    }

    private static func tint(_ t: Tint) -> Color {
        switch t {
        case .orange: return Theme.bank(.a)
        case .blue: return Theme.bank(.b)
        case .ochre: return Theme.bank(.c)
        case .grey: return Theme.bank(.d)
        case .red: return Theme.red
        }
    }

    /// "J DILLA · VNYL KCK / …" → "J Dilla kit"; single-sound swaps pass through.
    static func kitPhrase(_ text: String) -> String {
        if text.hasPrefix("PAD ") { return text }
        let style = text.components(separatedBy: " · ").first ?? text
        return titleCase(style) + " kit"
    }

    /// "NUJ KEYS · piano · Am · 90 BPM · 2 BAR CHOPS" → "Nuj Keys piano in Am, 90 BPM".
    static func samplePhrase(_ text: String) -> String {
        let c = text.components(separatedBy: " · ")
        guard c.count >= 4, c[3].hasSuffix("BPM") else { return sentence(text) }
        let key = c[2].trimmingCharacters(in: .whitespaces)
        let inKey = (key.isEmpty || key == "?" || key == "—") ? "" : " in \(key)"
        return "\(titleCase(c[0])) \(c[1])\(inKey), \(c[3])"
    }

    static func sentence(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let f = t.first else { return t }
        return f.uppercased() + t.dropFirst()
    }

    /// "J DILLA" → "J Dilla"; words with digits or symbols stay as they are.
    static func titleCase(_ s: String) -> String {
        s.split(separator: " ", omittingEmptySubsequences: false).map { w -> String in
            guard w.count > 1, w.allSatisfy({ $0.isLetter }), w == w.uppercased() else { return String(w) }
            return String(w.prefix(1)) + w.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

private extension String {
    /// "118ms" → "118 ms", "4.2s" → "4.2 s" (the timing strip's spacing).
    var spacedUnit: String {
        if hasSuffix("ms") { return String(dropLast(2)) + " ms" }
        if hasSuffix("s") { return String(dropLast(1)) + " s" }
        return self
    }
}

/// ONE plain-language result line (Inter 400 13), a thin bank-colour tab before each part.
struct LidResultLine: View {
    let state: AppState

    var body: some View {
        let s = LidSummary(state)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if s.parts.isEmpty {
                Text(state.isDigging ? "Digging through the crate…" : "Empty crate · describe a beat below and the pads fill from your library")
                    .font(Theme.inter(13))
                    .foregroundStyle(Theme.lidGrey1)
                    .lineLimit(1)
            }
            ForEach(Array(s.parts.enumerated()), id: \.offset) { i, part in
                if i > 0 {
                    Text(" + ").font(Theme.inter(13)).foregroundStyle(Theme.lidInk).fixedSize()
                }
                if let c = part.color {
                    Rectangle().fill(c)
                        .frame(width: 2, height: 10)
                        .offset(y: 0.5)
                        .padding(.leading, 1)
                        .padding(.trailing, 6)
                }
                Text(part.text)
                    .font(Theme.inter(13))
                    .tracking(-0.065)
                    .foregroundStyle(Theme.lidInk)
                    .lineLimit(1)
                    .layoutPriority(Double(s.parts.count - i))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// ONE small timing strip "JEV 95 ms · KIT 3 ms · SAMPLE 120 ms · GPT 4.2 s ✓" (JetBrains Mono 7.5),
/// with the AI PERFORM and PAD FX status on the right.
struct LidTimingStrip: View {
    let state: AppState

    var body: some View {
        let s = LidSummary(state)
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                ForEach(Array(s.timings.enumerated()), id: \.offset) { i, t in
                    if i > 0 {
                        Text("·").foregroundStyle(Theme.lidGrey2).padding(.horizontal, 7)
                    }
                    Text(t.key).foregroundStyle(Theme.lidTimingKey)
                    if !t.value.isEmpty {
                        Text(" " + t.value).foregroundStyle(Theme.lidGrey1)
                    }
                    if t.ok {
                        Text(" ✓").foregroundStyle(Theme.lidInk)
                    }
                }
            }
            .font(Theme.mono(7.5))
            .tracking(7.5 * 0.04)
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ai-timings")
            Spacer(minLength: 10)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if state.performOn {
                    HStack(spacing: 5) {
                        SparkShape().fill(Theme.lidInk).frame(width: 6, height: 6)
                        Text("PERFORM ▸ \(state.lastPerform.isEmpty ? "ON" : state.lastPerform.uppercased())")
                            .foregroundStyle(Theme.lidInk)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("perform-status")
                }
                if let fx = state.fx {
                    Text("FX ▸ \(fx.label) \(Int((state.punch * 100).rounded()))%")
                        .foregroundStyle(state.punch > 0.01 ? Theme.live : Theme.lidGrey1)
                        .accessibilityIdentifier("fx-status")
                }
            }
            .font(Theme.mono(7.5))
            .tracking(7.5 * 0.04)
            .lineLimit(1)
            .fixedSize()
        }
    }
}

// MARK: - Prompt row + chips

/// Rule, `›` prompt, outlined chips (AI PERFORM filled white when on). Narrow lids wrap the chips below.
struct LidPromptRow: View {
    let state: AppState
    var narrow = false
    var showChips = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(Theme.lidRule).frame(height: 0.5)
            HStack(spacing: 6) {
                LidPromptLine(state: state)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showChips && !narrow {
                    LidChips(state: state, ids: LidChips.lidSet, wrap: false)
                }
            }
            .frame(height: 28)
            .padding(.top, 4)
            if showChips && narrow {
                LidChips(state: state, ids: LidChips.lidSet, wrap: true)
                    .padding(.top, 4)
            }
        }
    }
}

/// The lid's `›` prompt: same bindings and behaviour as `PromptLine` (shared draft, ✦ DIG focus request, Esc,
/// submit → dig, "prompt-field"), in the 05 type: Inter, white caret and cursor.
struct LidPromptLine: View {
    let state: AppState
    var placeholder = "Describe a beat, a kit or a flip"

    @Bindable private var ui = CrateUI.shared
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("›")
                .font(Theme.inter(12, 500))
                .foregroundStyle(Theme.lidInk)
                .padding(.trailing, 4)
            ZStack(alignment: .leading) {
                TextField("", text: $ui.draft)
                    .textFieldStyle(.plain)
                    .font(Theme.inter(10.5))
                    .foregroundStyle(Theme.lidInk)
                    .tint(Theme.lidInk)
                    .focused($focused)
                    .submitLabel(.go)
                    .onSubmit(submit)
                    .onKeyPress(.escape) { focused = false; state.promptFocused = false; return .handled }
                    .crateNoAutocorrect()
                    .accessibilityIdentifier("prompt-field")
                    .accessibilityLabel("Prompt")
                if !focused && ui.draft.isEmpty {
                    idleText
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            if state.isDigging {
                DotSpinner(color: Theme.live, dot: 1.6)
            }
        }
        .background {
            // TextField consumes raw presses; register Escape with the hosting controller
            // so it also works while UIKit's text editor is first responder.
            Button { focused = false; state.promptFocused = false } label: { EmptyView() }
                .keyboardShortcut(.cancelAction)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 20)
        .onChange(of: ui.focusRequest) { _, _ in focused = true }
        .onChange(of: ui.blurRequest) { _, _ in focused = false }
        .onChange(of: focused) { _, f in ui.promptFocused = f; state.promptFocused = f }
        .onChange(of: state.promptFocused) { _, f in focused = f }
        .onDisappear { if focused { state.promptFocused = false; ui.promptFocused = false } }
    }

    private var idleText: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let on = Int(ctx.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            let hasPrompt = !state.prompt.isEmpty
            HStack(spacing: 1) {
                Text(hasPrompt ? state.prompt : placeholder)
                    .font(Theme.inter(10.5))
                    .foregroundStyle(hasPrompt ? Theme.lidGrey1 : Theme.lidPlaceholder)
                    .lineLimit(1)
                    .truncationMode(.head)
                Rectangle().fill(Theme.lidInk)
                    .frame(width: 1.5, height: 13)
                    .opacity(on ? 1 : 0)
            }
        }
    }

    private func submit() {
        let t = ui.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        focused = false
        guard !t.isEmpty else { return }
        state.dig(t)
        ui.draft = ""
    }
}

/// 05 outlined chips over `ActionChips.items` (same ids and actions); AI PERFORM is filled white when on.
struct LidChips: View {
    let state: AppState
    var ids: [String]? = nil
    var wrap = true

    /// The chips the mock prints on the prompt row.
    static let lidSet = ["chip-undo", "chip-redo", "chip-dilla-nujabes", "chip-house-kit", "chip-vintage-break", "chip-flip-it", "chip-ai-perform"]

    var body: some View {
        let items = ActionChips.items.filter { ids?.contains($0.id) ?? true }
        if wrap {
            ChipFlow(spacing: 5, lineSpacing: 5) {
                ForEach(items) { chip($0) }
            }
        } else {
            HStack(spacing: 5) {
                ForEach(items) { chip($0) }
            }
            .fixedSize()
        }
    }

    private func chip(_ item: ActionChips.Item) -> some View {
        let isPerform = item.id == "chip-ai-perform"
        let on = isPerform && state.performOn
        let dim = (item.id == "chip-undo" && !CrateUndoSignal.shared.canUndo) || (item.id == "chip-redo" && !CrateUndoSignal.shared.canRedo)
        let ink = on ? Color.black : Theme.chipText
        return Button {
            tap(item)
        } label: {
            HStack(spacing: 5) {
                if isPerform {
                    SparkShape().fill(ink).frame(width: 7, height: 7)
                }
                Text(item.label)
                    .font(Theme.inter(6.8, 600))
                    .tracking(6.8 * 0.1)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, 9)
            .frame(height: 21)
            .background(RoundedRectangle(cornerRadius: 4).fill(on ? Theme.lidInk : Color.black))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.chipStroke, lineWidth: 0.5).opacity(on ? 0 : 1))
            .opacity(dim ? 0.35 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChipPressStyle())
        .accessibilityIdentifier(item.id)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Same actions as `ActionChips`.
    private func tap(_ item: ActionChips.Item) {
        let ui = CrateUI.shared
        switch item.id {
        case "chip-undo":
            Task { @MainActor in await Orchestrator.current?.undo() }
        case "chip-redo":
            Task { @MainActor in await Orchestrator.current?.redo() }
        case "chip-flip-it":
            state.onFlip?()
            DebugLog.event("flip")
        case "chip-ai-perform":
            let on = !state.performOn
            state.performOn = on
            state.onPerformToggle?(on)
            DebugLog.event("perform_toggle", ["on": on])
        default:
            if let p = item.prompt {
                ui.draft = ""
                ui.blurRequest += 1
                state.dig(p)
            }
        }
    }
}
