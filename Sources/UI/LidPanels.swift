import SwiftUI

// MARK: - SEQ: 16-step dot grid of the current bar

struct SeqRow {
    var label: String
    var color: Color
    var pads: [PadID]
}

enum SeqRows {
    /// Lanes that have hits anywhere in the pattern: bank A per lane, bank B merged into CHOP, banks C/D per pad.
    /// Each lane carries its bank's colour (tab + playhead).
    static func build(_ state: AppState, _ p: Pattern) -> [SeqRow] {
        func has(_ pad: PadID) -> Bool {
            !(p.lanes[pad]?.isEmpty ?? true) || !(p.notes[pad]?.isEmpty ?? true)
        }
        var rows: [SeqRow] = []
        for i in 0..<16 {
            let pad = PadID(.a, i)
            if has(pad) { rows.append(SeqRow(label: UIHelpers.bankANames[i], color: Theme.bank(.a), pads: [pad])) }
        }
        let chops = (0..<16).map { PadID(.b, $0) }.filter(has)
        if !chops.isEmpty { rows.append(SeqRow(label: "CHOP", color: Theme.bank(.b), pads: chops)) }
        for bank in [Bank.c, .d] {
            for i in 0..<16 {
                let pad = PadID(bank, i)
                if has(pad) {
                    rows.append(SeqRow(label: UIHelpers.laneLabel(state, pad), color: Theme.bank(bank), pads: [pad]))
                }
            }
        }
        return rows
    }

    static let placeholder = [
        SeqRow(label: "KICK", color: Theme.bank(.a), pads: []),
        SeqRow(label: "SNR", color: Theme.bank(.a), pads: []),
        SeqRow(label: "HAT", color: Theme.bank(.a), pads: []),
        SeqRow(label: "CHOP", color: Theme.bank(.b), pads: []),
        SeqRow(label: "BASS", color: Theme.bank(.c), pads: []),
    ]
}

/// 05 dot sequencer for the current bar: bank-colour lane tabs, white hits, tiny rest dots, hollow ghosts,
/// a step ruler (1 · 5 · 9 · 13 + the playing step) and the playhead split per lane in that lane's bank colour.
struct SeqGridView: View {
    let state: AppState
    /// Largest lane pitch (the mock's 25 pt; portrait allows a little more).
    var maxPitch: CGFloat = 25

    /// Lane label column (the mock's X0).
    static let labelColumn: CGFloat = 54
    /// Extra gap between 4-step groups.
    static let groupGap: CGFloat = 10
    /// First lane centre below the top (the ruler sits above it).
    static let firstLane: CGFloat = 24
    static let bottomPad: CGFloat = 19

    static func fittedHeight(rows: Int, pitch: CGFloat) -> CGFloat {
        firstLane + CGFloat(max(rows, 1) - 1) * pitch + bottomPad
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { _ in
            let f = LiveFrame(state)
            let rows = SeqRows.build(state, f.pattern)
            Canvas { ctx, size in
                draw(ctx, size: size, frame: f, rows: rows.isEmpty ? SeqRows.placeholder : rows)
            }
            .overlay(alignment: .bottomLeading) {
                if rows.isEmpty {
                    Text("EMPTY PATTERN · PRESS ✦ DIG OR TAP A CHIP")
                        .fieldLabel()
                        .foregroundStyle(Theme.lidGrey1)
                        .padding(.leading, Self.labelColumn)
                        .padding(.bottom, 2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("seq-grid")
        .accessibilityLabel("Sequencer")
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, frame f: LiveFrame, rows: [SeqRow]) {
        let n = rows.count
        let top = Self.firstLane
        let pitch = min(maxPitch, max(11, (size.height - top - 12) / CGFloat(max(n - 1, 1))))
        let x0 = Self.labelColumn
        let colW = (size.width - x0 - 3 * Self.groupGap) / 16
        func cx(_ i: Int) -> CGFloat { x0 + CGFloat(i) * colW + CGFloat(i / 4) * Self.groupGap + colW / 2 }
        let k = min(1, max(0.7, pitch / 25))
        let dHit = 9 * k, dNow = 10 * k, dGhost = 6 * k
        let segH = min(19, pitch - 3)
        let playing = f.playing
        let now = f.stepInBar
        let barStart = f.bar * 16

        // step ruler: 1 · 5 · 9 · 13 in grey, the playing step in white
        let rulerY = top - 20.5
        for i in [0, 4, 8, 12] where !(playing && i == now) {
            ctx.draw(Text("\(i + 1)").font(Theme.inter(7, 500)).monospacedDigit().foregroundStyle(Theme.lidGrey2),
                     at: CGPoint(x: cx(i), y: rulerY), anchor: .center)
        }
        if playing {
            ctx.draw(Text("\(now + 1)").font(Theme.inter(7, 500)).monospacedDigit().foregroundStyle(Theme.lidInk),
                     at: CGPoint(x: cx(now), y: rulerY), anchor: .center)
        }

        for (r, row) in rows.enumerated() {
            let cy = top + CGFloat(r) * pitch

            // velocity (and note length) per step of this bar
            var cells = [Int: (vel: Int, len: Double)]()
            for pad in row.pads {
                for h in f.pattern.lanes[pad] ?? [] {
                    let s = h.step - barStart
                    if s >= 0 && s < 16 { cells[s] = (max(cells[s]?.vel ?? 0, h.velocity), max(1, cells[s]?.len ?? 1)) }
                }
                for note in f.pattern.notes[pad] ?? [] {
                    let s = note.step - barStart
                    if s >= 0 && s < 16 { cells[s] = (max(cells[s]?.vel ?? 0, note.velocity), max(1, note.length)) }
                }
            }
            let hot = playing && cells[now] != nil

            // bank tab + lane label
            ctx.fill(Path(CGRect(x: 0, y: cy - 4.5, width: 2, height: 9)), with: .color(row.color))
            ctx.draw(Text(row.label).font(Theme.inter(7.5, 500)).tracking(0.75)
                        .foregroundStyle(hot ? Theme.lidInk : Theme.lidGrey1),
                     at: CGPoint(x: 9, y: cy), anchor: .leading)

            // held notes: a hairline to the note's end
            for (s, c) in cells where c.len > 1.5 {
                let end = min(15, s + Int(c.len.rounded(.up)) - 1)
                if end > s {
                    ctx.fill(Path(CGRect(x: cx(s), y: cy - 0.5, width: cx(end) - cx(s), height: 1)),
                             with: .color(Theme.lidRest))
                }
            }

            // this lane's playhead, in its bank colour
            if playing {
                ctx.fill(Path(CGRect(x: cx(now) - 1, y: cy - segH / 2, width: 2, height: segH)), with: .color(row.color))
            }

            for s in 0..<16 {
                let x = cx(s)
                guard let c = cells[s] else {
                    if !(playing && s == now) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: cy - 1, width: 2, height: 2)), with: .color(Theme.lidRest))
                    }
                    continue
                }
                let ghost = c.vel < 60
                if playing && s == now {
                    let d = ghost ? dGhost + 2 : dNow
                    ctx.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: cy - d / 2, width: d, height: d)), with: .color(row.color))
                } else if ghost {
                    let d = dGhost - 1
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - d / 2, y: cy - d / 2, width: d, height: d)),
                               with: .color(Theme.lidGhost), lineWidth: 1)
                } else {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - dHit / 2, y: cy - dHit / 2, width: dHit, height: dHit)),
                             with: .color(Theme.lidInk))
                }
            }
        }
    }
}

// MARK: - CHOP: bank-B source waveform with 16 numbered slice markers

struct ChopWaveView: View {
    let state: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let f = LiveFrame(state)
            let slices = (0..<16).map { PadID(.b, $0) }
            let sounds = slices.map { state.sound($0) }
            let loaded = sounds.contains { $0 != nil }
            let current = currentSlice(f, now: ctx.date)
            Canvas { g, size in
                draw(g, size: size, sounds: sounds, current: current, loaded: loaded)
            }
            .overlay {
                if !loaded {
                    Text("NO SAMPLE IN BANK B · PRESS ✦ DIG")
                        .fieldLabel()
                        .foregroundStyle(Theme.lidGrey1)
                        .padding(6)
                        .background(Theme.oled)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("chop-wave")
        .accessibilityLabel("Chop waveform")
    }

    private func currentSlice(_ f: LiveFrame, now: Date) -> Int? {
        if let p = state.lastHitPad, p.bank == .b, now.timeIntervalSince(state.lastHitTime) < 1.2 { return p.index }
        if let c = f.currentChop() { return c }
        return state.selectedPad.bank == .b ? state.selectedPad.index : nil
    }

    private func draw(_ g: GraphicsContext, size: CGSize, sounds: [PadSound?], current: Int?, loaded: Bool) {
        let top: CGFloat = 16
        let h = size.height - top
        let cy = top + h / 2
        let blue = Theme.bank(.b)
        g.fill(Path(CGRect(x: 0, y: cy - 0.25, width: size.width, height: 0.5)), with: .color(Theme.lidGrey3))

        // slice widths proportional to duration when known
        var durs = sounds.map { s -> Double in
            guard let s, let e = s.end, e > s.start else { return 1 }
            return e - s.start
        }
        let total = durs.reduce(0, +)
        if total <= 0 { durs = Array(repeating: 1, count: 16) }
        let sum = durs.reduce(0, +)
        var x: CGFloat = 0
        for i in 0..<16 {
            let w = size.width * CGFloat(durs[i] / sum)
            let isCur = current == i
            if isCur {
                g.fill(Path(CGRect(x: x, y: top, width: w, height: h)), with: .color(blue.opacity(0.12)))
            }
            // marker + number (the playing slice gets bank B's colour, like its lane playhead)
            g.fill(Path(CGRect(x: x, y: top - 2, width: isCur ? 2 : 1, height: h + 2)),
                   with: .color(isCur ? blue : Theme.lidGrey3))
            g.draw(Text("\(i + 1)").font(Theme.inter(7, 500)).monospacedDigit()
                        .foregroundStyle(isCur ? Theme.lidInk : Theme.lidGrey2),
                   at: CGPoint(x: x + 4, y: 6), anchor: .leading)
            if loaded {
                let pts = max(4, Int(w / 3))
                let wave = WaveCache.shared.wave(state, PadID(.b, i), points: pts)
                if !wave.isEmpty {
                    var path = Path()
                    for (j, a) in wave.enumerated() {
                        let px = x + (CGFloat(j) + 0.5) / CGFloat(wave.count) * w
                        let amp = CGFloat(min(1, max(0, a))) * (h / 2 - 6)
                        path.move(to: CGPoint(x: px, y: cy - max(0.5, amp)))
                        path.addLine(to: CGPoint(x: px, y: cy + max(0.5, amp)))
                    }
                    g.stroke(path, with: .color(isCur ? Theme.lidInk : Theme.lidInk.opacity(0.55)), lineWidth: 1.5)
                }
            }
            x += w
        }
    }
}

// MARK: - KEYS: waveform of the selected pad, oscillating faster for higher notes

struct KeysWaveView: View {
    let state: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let pad = state.selectedPad
            let env = WaveCache.shared.wave(state, pad, points: 160)
            let semi = Double(CrateUI.shared.lastSemi ?? 0)
            let hot = ctx.date.timeIntervalSince(state.lastHitTime) < 0.15 && state.lastHitPad == pad
            Canvas { g, size in
                let cy = size.height / 2
                g.fill(Path(CGRect(x: 0, y: cy - 0.25, width: size.width, height: 0.5)), with: .color(Theme.lidGrey3))
                guard !env.isEmpty else { return }
                let cycles = 16 * pow(2, semi / 12)
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    let t = Double(x / size.width)
                    let fi = t * Double(env.count - 1)
                    let i0 = Int(fi), i1 = min(env.count - 1, i0 + 1)
                    let e = Double(env[i0]) + (Double(env[i1]) - Double(env[i0])) * (fi - Double(i0))
                    let y = cy - CGFloat(sin(t * cycles * 2 * .pi) * min(1, e)) * (size.height / 2 - 8)
                    if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    x += 1.5
                }
                g.stroke(path, with: .color(hot ? Theme.bank(pad.bank) : Theme.lidInk), lineWidth: 1.2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("keys-wave")
        .accessibilityLabel("Waveform")
    }
}

// MARK: - AI log

/// The AI log panel (SAMPLE / PAD FX / 16 LVL, portrait SEQ): tint tab, JB tag, Inter text, JB timing.
struct AILogView: View {
    let state: AppState
    var maxLines = 12
    var size: CGFloat = 10.5

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if state.log.isEmpty {
                Text("AI LOG · EMPTY")
                    .fieldLabel()
                    .foregroundStyle(Theme.lidGrey2)
            }
            ForEach(state.log.suffix(maxLines)) { line in
                HStack(alignment: .center, spacing: 0) {
                    Rectangle().fill(tint(line.tint)).frame(width: 2, height: 9)
                        .padding(.trailing, 7)
                    Text(line.tag.uppercased())
                        .font(Theme.mono(7.5))
                        .tracking(0.3)
                        .foregroundStyle(Theme.lidTimingKey)
                        .frame(width: 44, alignment: .leading)
                        .lineLimit(1)
                    Text(line.text)
                        .font(Theme.inter(size))
                        .foregroundStyle(line.tint == .red ? Theme.red : Theme.lidInk)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let ms = line.ms {
                        Text(UIHelpers.msText(ms))
                            .font(Theme.mono(7.5))
                            .foregroundStyle(Theme.lidGrey1)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-log")
    }

    private func tint(_ t: Tint) -> Color {
        switch t {
        case .orange: return Theme.bank(.a)
        case .blue: return Theme.bank(.b)
        case .ochre: return Theme.bank(.c)
        case .grey: return Theme.bank(.d)
        case .red: return Theme.red
        }
    }
}

// MARK: - PUNCH strip (hinge FX / PAD FX), shown in the result line's slot whenever punch > 0

struct PunchStrip: View {
    let punch: Double
    /// Selected PAD FX (nil = the default PUNCH chain, which shows its LPF / VERB readout).
    var fx: FXType? = nil

    var body: some View {
        let p = min(1, max(0, punch))
        let cutoff = 20000 * pow(180.0 / 20000, pow(p, 0.85))
        let cells = 24
        let lit = Int((p * Double(cells)).rounded())
        HStack(spacing: 10) {
            Text(fx?.label ?? (p > 0.92 ? "BREAKDOWN" : "PUNCH"))
                .fieldLabel(7.5)
                .foregroundStyle(Theme.lidInk)
                .fixedSize()
            HStack(spacing: 2) {
                ForEach(0..<cells, id: \.self) { i in
                    Rectangle()
                        .fill(i < lit ? Theme.live : Theme.lidGrey3)
                        .frame(width: 4, height: 9)
                }
            }
            Text("\(Int(p * 100))%")
                .font(Theme.inter(13))
                .monospacedDigit()
                .foregroundStyle(Theme.lidInk)
                .fixedSize()
            Text(fx.map { $0.hint } ?? "LPF \(cutoff >= 1000 ? String(format: "%.1fk", cutoff / 1000) : "\(Int(cutoff))") · VERB \(Int(38 * p))")
                .font(Theme.mono(7.5))
                .foregroundStyle(Theme.lidGrey1)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("punch-strip")
    }
}

// MARK: - DIG composer (lid main area while the prompt is focused)

/// Echoes the draft near the top of the lid (the keyboard may cover the bottom prompt line in book pose)
/// and offers every canned prompt.
struct DigComposer: View {
    let state: AppState

    var body: some View {
        let ui = CrateUI.shared
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                SparkShape().fill(Theme.lidInk).frame(width: 8, height: 8)
                Text("DIG").fieldLabel(7.5).foregroundStyle(Theme.lidInk)
                Text("DESCRIBE A BEAT, A KIT OR A SOUND · RETURN TO DIG")
                    .fieldLabel()
                    .foregroundStyle(Theme.lidGrey1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let on = Int(ctx.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                let empty = ui.draft.isEmpty
                let body = Text(empty ? "4 bar loop, dilla drums + a nujabes piano sample" : ui.draft)
                    .foregroundStyle(empty ? Theme.lidPlaceholder : Theme.lidInk)
                let cursor = Text("|").foregroundStyle(on ? Theme.lidInk : Color.clear)
                Text("\(body)\(cursor)")
                    .font(Theme.interLight(24))
                    .tracking(-0.5)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            LidChips(state: state, ids: LidChips.lidSet)
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dig-composer")
    }
}
