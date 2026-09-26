import SwiftUI

/// The black lid display: header, hero readouts, a mode-dependent main area (SEQ grid / CHOP waveform /
/// KEYS note + waveform / AI log), then the `›` prompt and result chips. Works landscape (~669×455) and
/// portrait (~455×669).
struct LidDisplayView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width * 1.05
            let narrow = geo.size.width < 520
            VStack(alignment: .leading, spacing: 0) {
                LidHeader(state: state, narrow: narrow)
                LidReadouts(state: state, stacked: narrow, hero: narrow ? 40 : 44)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                if state.punch > 0.01 {
                    PunchStrip(punch: state.punch).padding(.bottom, 10)
                }
                Group {
                    if CrateUI.shared.promptFocused {
                        DigComposer(state: state)
                    } else {
                        mainArea(portrait: portrait, narrow: narrow)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                LidPromptArea(state: state, columns: narrow ? 2 : 4, showsLogPanel: showsLogPanel(portrait))
            }
            .padding(.horizontal, narrow ? 14 : 18)
            .padding(.vertical, 16)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Color.black)
        .ignoresSafeArea(.keyboard)
    }

    private func showsLogPanel(_ portrait: Bool) -> Bool {
        switch state.mode {
        case .sample, .padFX, .levels16: return true
        case .seq: return portrait
        case .chop, .keys: return false
        }
    }

    @ViewBuilder
    private func mainArea(portrait: Bool, narrow: Bool) -> some View {
        switch state.mode {
        case .seq:
            if portrait {
                VStack(alignment: .leading, spacing: 14) {
                    SeqGridView(state: state, labelWidth: narrow ? 44 : 52)
                        .frame(height: seqHeight)
                    Rectangle().fill(Theme.rule).frame(height: 1)
                    AILogView(state: state, maxLines: 10, size: 10.5)
                    Spacer(minLength: 0)
                }
            } else {
                SeqGridView(state: state, labelWidth: narrow ? 44 : 52)
            }
        case .chop:
            ChopWaveView(state: state).padding(.vertical, 6)
        case .keys:
            KeysWaveView(state: state).padding(.vertical, 6)
        case .sample:
            VStack(alignment: .leading, spacing: 12) {
                if (0..<16).contains(where: { state.sound(PadID(.b, $0)) != nil }) {
                    ChopWaveView(state: state)
                        .frame(height: portrait ? 120 : 64)
                }
                AILogView(state: state, maxLines: portrait ? 12 : 5, size: narrow ? 10.5 : 11)
                Spacer(minLength: 0)
            }
        case .padFX, .levels16:
            AILogView(state: state, maxLines: portrait ? 16 : 9, size: narrow ? 10.5 : 11)
        }
    }

    /// Portrait SEQ: grid sized to its lanes, the log takes the rest.
    private var seqHeight: CGFloat {
        let rows = max(5, SeqRows.build(state, state.engine.pattern).count)
        return min(300, CGFloat(rows) * 24)
    }
}

/// CRATE · CR-16 | BANK A · SEQ · 4 BARS | JEV ● 118MS  GPT ● 2.4S (two lines when narrow).
struct LidHeader: View {
    let state: AppState
    var narrow = false
    var size: CGFloat = 10

    var body: some View {
        Group {
            if narrow {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { logo; Spacer(minLength: 8); right }
                    middle
                }
            } else {
                HStack {
                    logo
                    Spacer(minLength: 8)
                    middle
                    Spacer(minLength: 8)
                    right
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var logo: some View {
        Text("CRATE · CR-16").crateLabel(size).foregroundStyle(Theme.text)
    }

    private var middle: some View {
        let p = state.engine.pattern
        let bars = (p.lanes.isEmpty && p.notes.isEmpty) ? state.bars : p.bars
        let tail: String = state.mode == .keys ? "OCT \(keysOctaveNumber)" : "\(max(1, bars)) BARS"
        let bank = Text(state.bank.letter).foregroundStyle(Theme.orange)
        return Text("BANK \(bank) · \(state.mode.label) · \(tail)")
            .crateLabel(size)
            .foregroundStyle(Theme.mid)
    }

    @ViewBuilder
    private var right: some View {
        if state.mode == .keys {
            let root = UIHelpers.rootNote(state, state.selectedPad)
            let r = Text(UIHelpers.noteName(root, flat: "♭")).foregroundStyle(Theme.orange)
            Text("ROOT \(r)").crateLabel(size).foregroundStyle(Theme.mid)
        } else {
            let jevOn = state.jevMs != nil
            let gptOn = state.gptSeconds != nil
            let jev = state.jevMs.map { "\($0)MS" } ?? "—"
            let gpt = state.gptSeconds.map { String(format: "%.1fS", $0) } ?? "—"
            let d1 = Text("●").font(Theme.mono(size - 1)).foregroundStyle(jevOn ? Theme.orange : Theme.dim)
            let d2 = Text("●").font(Theme.mono(size - 1)).foregroundStyle(gptOn ? Theme.orange : Theme.dim)
            Text("JEV \(d1) \(jev)   GPT \(d2) \(gpt)")
                .crateLabel(size)
                .foregroundStyle(Theme.mid)
                .accessibilityIdentifier("ai-timings")
        }
    }

    private var keysOctaveNumber: Int {
        let root = UIHelpers.rootNote(state, state.selectedPad)
        let base = KeysView.baseMidi(root: root, octave: state.keysOctave)
        return (base + 7) / 12 - 1   // octave of the first C on the keyboard
    }
}

/// Hero readouts in Doto. SEQ/SAMPLE: BPM · SWING % · BAR.BEAT (+ style / sample · chords).
/// KEYS: NOTE · SEMI (+ pad name · source / SCALE LOCK). CHOP: SLICE. PAD FX: PUNCH.
struct LidReadouts: View {
    let state: AppState
    var stacked = false
    var hero: CGFloat = 44

    var body: some View {
        if stacked {
            VStack(alignment: .leading, spacing: 10) {
                numbers
                info(alignment: .leading)
            }
        } else {
            HStack(alignment: .bottom, spacing: 24) {
                numbers
                Spacer(minLength: 8)
                info(alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var numbers: some View {
        HStack(alignment: .bottom, spacing: stacked ? 20 : 26) {
            switch state.mode {
            case .keys:
                let midi = CrateUI.shared.lastMidi
                readout(midi.map { UIHelpers.noteName($0) } ?? "--", "NOTE", color: Theme.orange, id: "note")
                readout(CrateUI.shared.lastSemi.map { UIHelpers.signed($0) } ?? "0", "SEMI", id: "semi")
            case .padFX:
                readout(String(format: "%03d", Int((state.punch * 100).rounded())), "PUNCH %", color: Theme.orange, id: "punch")
                live
            case .chop:
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                    let f = LiveFrame(state)
                    let slice = currentSlice(f)
                    readout(slice.map { String(format: "%02d", $0 + 1) } ?? "--", "SLICE", color: Theme.blue, id: "slice")
                }
                live
            default:
                live
            }
        }
    }

    /// BPM, SWING and BAR.BEAT polled from the engine (always what's actually playing).
    private var live: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let f = LiveFrame(state)
            let bpm = state.engine.bpm.isFinite ? state.engine.bpm : state.bpm
            HStack(alignment: .bottom, spacing: stacked ? 20 : 26) {
                readout(String(format: "%03d", Int(bpm.rounded())), "BPM", id: "bpm")
                if state.mode != .padFX && state.mode != .chop {
                    readout("\(Int(state.engine.swing.rounded()))", "SWING %", id: "swing")
                }
                readout(f.barBeat, "BAR.BEAT", color: Theme.orange, id: "bar-beat")
            }
        }
    }

    private func currentSlice(_ f: LiveFrame) -> Int? {
        if let p = state.lastHitPad, p.bank == .b, Date().timeIntervalSince(state.lastHitTime) < 1.2 { return p.index }
        return f.currentChop() ?? (state.selectedPad.bank == .b ? state.selectedPad.index : nil)
    }

    private func readout(_ value: String, _ label: String, color: Color = Theme.text, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Theme.doto(hero))
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .frame(height: hero * 0.74)
            Text(label)
                .crateLabel(9, tracking: 0.18)
                .foregroundStyle(Theme.mid)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    @ViewBuilder
    private func info(alignment: HorizontalAlignment) -> some View {
        let textAlign: TextAlignment = alignment == .leading ? .leading : .trailing
        VStack(alignment: alignment, spacing: 6) {
            if state.isDigging {
                HStack(spacing: 8) {
                    DotSpinner(color: Theme.orange, dot: 2.5)
                    Text("DIGGING").crateLabel(13, tracking: 0.14).foregroundStyle(Theme.orange)
                }
            } else {
                Text(title)
                    .crateLabel(13, tracking: 0.14)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(textAlign)
            }
            Text(subtitle)
                .font(Theme.label(9))
                .tracking(9 * 0.14)
                .foregroundStyle(Theme.mid)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(textAlign)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("style-label")
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
        if state.mode == .keys {
            if !state.scaleLock { return "SCALE LOCK: OFF · CHROMATIC" }
            return "SCALE LOCK: " + (UIHelpers.keyDisplay(state.scaleKey) ?? "NO KEY")
        }
        let parts = [state.sampleLabel.uppercased(), state.chordsLabel]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { return state.performOn ? "AI PERFORM ON" : "AI SAMPLER · PRESS ✦ DIG" }
        return parts.joined(separator: " · ")
    }
}

/// Bottom of the lid: rule, `›` prompt, then result chips (or suggestion chips while typing / before the first dig).
struct LidPromptArea: View {
    let state: AppState
    var columns = 4
    var showsLogPanel = false

    var body: some View {
        let suggest = (state.log.isEmpty || showsLogPanel) && !CrateUI.shared.promptFocused
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Theme.rule).frame(height: 1)
            HStack(spacing: 10) {
                PromptLine(state: state)
                if state.performOn {
                    Text("PERFORM ▸ \(state.lastPerform.isEmpty ? "ON" : state.lastPerform.uppercased())")
                        .font(Theme.mono(10, bold: true))
                        .foregroundStyle(Theme.orange)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityIdentifier("perform-status")
                }
            }
            if suggest {
                ActionChips(state: state)
            } else if !state.log.isEmpty {
                ResultChips(lines: Array(state.log.suffix(columns)), columns: columns)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(showsLogPanel ? "ai-chips" : "ai-log")
            }
        }
        .padding(.top, 8)
    }
}
