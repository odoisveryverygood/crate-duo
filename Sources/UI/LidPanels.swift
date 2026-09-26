import SwiftUI

// MARK: - SEQ: 16-step dot grid of the current bar

struct SeqRow {
    var label: String
    var color: Color
    var pads: [PadID]
}

enum SeqRows {
    /// Lanes that have hits anywhere in the pattern: bank A per lane, bank B merged into CHOP, banks C/D per pad.
    static func build(_ state: AppState, _ p: Pattern) -> [SeqRow] {
        func has(_ pad: PadID) -> Bool {
            !(p.lanes[pad]?.isEmpty ?? true) || !(p.notes[pad]?.isEmpty ?? true)
        }
        var rows: [SeqRow] = []
        for i in 0..<16 {
            let pad = PadID(.a, i)
            if has(pad) { rows.append(SeqRow(label: UIHelpers.bankANames[i], color: Theme.orange, pads: [pad])) }
        }
        let chops = (0..<16).map { PadID(.b, $0) }.filter(has)
        if !chops.isEmpty { rows.append(SeqRow(label: "CHOP", color: Theme.blue, pads: chops)) }
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
        SeqRow(label: "KICK", color: Theme.orange, pads: []),
        SeqRow(label: "SNR", color: Theme.orange, pads: []),
        SeqRow(label: "HAT", color: Theme.orange, pads: []),
        SeqRow(label: "CHOP", color: Theme.blue, pads: []),
        SeqRow(label: "BASS", color: Theme.ochre, pads: []),
    ]
}

struct SeqGridView: View {
    let state: AppState
    var labelWidth: CGFloat = 52
    var maxRowHeight: CGFloat = 32

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
                        .crateLabel(9, tracking: 0.18)
                        .foregroundStyle(Theme.mid)
                        .padding(.leading, labelWidth)
                        .padding(.bottom, 4)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("seq-grid")
        .accessibilityLabel("Sequencer")
    }

    private func draw(_ ctx: GraphicsContext, size: CGSize, frame f: LiveFrame, rows: [SeqRow]) {
        let colW = (size.width - labelWidth) / 16
        let rowH = min(maxRowHeight, size.height / CGFloat(max(rows.count, 1)))
        let d = max(4, min(14, rowH - 8, colW - 6))
        let gridH = rowH * CGFloat(rows.count)
        let barStart = f.bar * 16
        let playing = f.playing
        let playCol = f.stepInBar

        // playhead band
        if playing {
            let x = labelWidth + CGFloat(playCol) * colW
            ctx.fill(Path(CGRect(x: x + 1, y: 0, width: colW - 2, height: gridH)), with: .color(Theme.text.opacity(0.07)))
            ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: gridH)), with: .color(Theme.text.opacity(0.66)))
        }

        for (r, row) in rows.enumerated() {
            let cy = rowH * (CGFloat(r) + 0.5)
            ctx.draw(Text(row.label).crateLabel(9, tracking: 0.12).foregroundStyle(Theme.mid),
                     at: CGPoint(x: 0, y: cy), anchor: .leading)

            // velocity (and note length) per step of this bar
            var cells = [Int: (vel: Int, len: Double)]()
            for pad in row.pads {
                for h in f.pattern.lanes[pad] ?? [] {
                    let s = h.step - barStart
                    if s >= 0 && s < 16 { cells[s] = (max(cells[s]?.vel ?? 0, h.velocity), 1) }
                }
                for n in f.pattern.notes[pad] ?? [] {
                    let s = n.step - barStart
                    if s >= 0 && s < 16 { cells[s] = (max(cells[s]?.vel ?? 0, n.velocity), max(1, n.length)) }
                }
            }

            for s in 0..<16 {
                let cx = labelWidth + colW * (CGFloat(s) + 0.5)
                if playing && s == playCol {
                    let box = CGRect(x: cx - d / 2 - 2, y: cy - d / 2 - 2, width: d + 4, height: d + 4)
                    ctx.stroke(Path(roundedRect: box, cornerRadius: 3), with: .color(Theme.text.opacity(0.33)), lineWidth: 1)
                }
                guard let c = cells[s] else {
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)),
                             with: .color(Theme.dotOff))
                    continue
                }
                let ghost = c.vel < 60
                let color: Color = ghost ? Theme.ghost : row.color.opacity(0.5 + 0.5 * min(1, Double(c.vel - 60) / 58))
                if c.len > 1.5 {
                    let endX = min(labelWidth + colW * 16, cx + colW * CGFloat(c.len - 1))
                    ctx.fill(Path(roundedRect: CGRect(x: cx, y: cy - 1.5, width: endX - cx, height: 3), cornerRadius: 1.5),
                             with: .color(row.color.opacity(0.35)))
                }
                let justPlayed = playing && s == playCol && (f.local - Double(barStart + s)) < f.flashSteps + 0.3
                let dd = justPlayed ? d * 1.25 : d
                ctx.fill(Path(ellipseIn: CGRect(x: cx - dd / 2, y: cy - dd / 2, width: dd, height: dd)), with: .color(color))
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
                        .crateLabel(9, tracking: 0.18)
                        .foregroundStyle(Theme.mid)
                        .padding(6)
                        .background(Color.black)
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
        g.fill(Path(CGRect(x: 0, y: cy - 0.5, width: size.width, height: 1)), with: .color(Theme.rule))

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
            let color = isCur ? Theme.orange : Theme.text
            if isCur {
                g.fill(Path(CGRect(x: x, y: top, width: w, height: h)), with: .color(Theme.orange.opacity(0.08)))
            }
            // marker + number
            g.fill(Path(CGRect(x: x, y: top - 2, width: 1, height: h + 2)), with: .color(isCur ? Theme.orange : Theme.dim))
            g.draw(Text("\(i + 1)").font(Theme.label(8)).foregroundStyle(isCur ? Theme.orange : Theme.mid),
                   at: CGPoint(x: x + 3, y: 6), anchor: .leading)
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
                    g.stroke(path, with: .color(color.opacity(isCur ? 1 : 0.85)), lineWidth: 1.5)
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
                g.fill(Path(CGRect(x: 0, y: cy - 0.5, width: size.width, height: 1)), with: .color(Theme.rule))
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
                g.stroke(path, with: .color(hot ? Theme.orange : Theme.text), lineWidth: 1.4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("keys-wave")
        .accessibilityLabel("Waveform")
    }
}

// MARK: - AI log

struct AILogView: View {
    let state: AppState
    var maxLines = 12
    var size: CGFloat = 11

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if state.log.isEmpty {
                Text("AI LOG · EMPTY")
                    .crateLabel(9, tracking: 0.18)
                    .foregroundStyle(Theme.dim)
            }
            ForEach(state.log.suffix(maxLines)) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.tag.uppercased())
                        .font(Theme.mono(size - 1, bold: true))
                        .foregroundStyle(Theme.tint(line.tint))
                        .frame(width: size * 5.6, alignment: .leading)
                        .lineLimit(1)
                    Text(line.text)
                        .font(Theme.mono(size))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let ms = line.ms {
                        Text(UIHelpers.msText(ms))
                            .font(Theme.mono(size - 1))
                            .foregroundStyle(Theme.mid)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-log")
    }
}

// MARK: - PUNCH strip (hinge FX / PAD FX), shown whenever punch > 0

struct PunchStrip: View {
    let punch: Double

    var body: some View {
        let p = min(1, max(0, punch))
        let cutoff = 20000 * pow(180.0 / 20000, pow(p, 0.85))
        let cells = 24
        let lit = Int((p * Double(cells)).rounded())
        HStack(spacing: 10) {
            Text(p > 0.92 ? "BREAKDOWN" : "PUNCH")
                .crateLabel(9, tracking: 0.16)
                .foregroundStyle(Theme.orange)
            HStack(spacing: 2) {
                ForEach(0..<cells, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < lit ? Theme.orange : Theme.dotOff)
                        .frame(width: 5, height: 9)
                }
            }
            Text("\(Int(p * 100))%")
                .font(Theme.mono(10, bold: true))
                .foregroundStyle(Theme.text)
            Text("LPF \(cutoff >= 1000 ? String(format: "%.1fk", cutoff / 1000) : "\(Int(cutoff))") · VERB \(Int(38 * p))")
                .font(Theme.mono(10))
                .foregroundStyle(Theme.mid)
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
/// and offers the canned prompts.
struct DigComposer: View {
    let state: AppState

    var body: some View {
        let ui = CrateUI.shared
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                SparkShape().fill(Theme.orange).frame(width: 11, height: 11)
                Text("DIG").crateLabel(11).foregroundStyle(Theme.orange)
                Text("DESCRIBE A BEAT, A KIT OR A SOUND · RETURN TO DIG")
                    .crateLabel(9, tracking: 0.14)
                    .foregroundStyle(Theme.mid)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                let on = Int(ctx.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                let empty = ui.draft.isEmpty
                let body = Text(empty ? "4 bar loop, dilla drums + a nujabes piano sample" : ui.draft)
                    .foregroundStyle(empty ? Theme.dim : Theme.text)
                let cursor = Text("▌").foregroundStyle(on ? Theme.orange : Color.clear)
                Text("\(body)\(cursor)")
                    .font(Theme.mono(18))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ActionChips(state: state)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dig-composer")
    }
}
