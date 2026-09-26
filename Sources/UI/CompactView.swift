import SwiftUI

/// Outer display (closed, ~466×678): a mini lid (BPM, bar, style/sample, 2 log lines, prompt + chips),
/// the 4×4 pads, and a bottom row with banks, transport and ✦ DIG.
struct CompactView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 12
            let topInset = max(inset, geo.safeAreaInsets.top)
            Group {
                if geo.size.width > geo.size.height {
                    // Closed, held sideways: readouts + transport left, square pad grid right.
                    HStack(spacing: 12) {
                        VStack(spacing: 10) {
                            miniLid
                            Spacer(minLength: 0)
                            bottomRow.frame(height: 40)
                        }
                        .frame(width: geo.size.width * 0.44)
                        PadGridView(state: state, gap: 8)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 10) {
                        miniLid
                        PadGridView(state: state, gap: 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        bottomRow
                            .frame(height: 40)
                    }
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, topInset)
            .padding(.bottom, max(inset, geo.safeAreaInsets.bottom))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Theme.chassis)
        .ignoresSafeArea(.keyboard)
        .crateDeferEdgeGestures()
    }

    private var miniLid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CRATE · CR-16").crateLabel(9).foregroundStyle(Theme.text)
                Spacer(minLength: 6)
                let bank = Text(state.bank.letter).foregroundStyle(Theme.orange)
                Text("BANK \(bank) · \(state.mode.label)").crateLabel(9).foregroundStyle(Theme.mid)
            }
            .lineLimit(1)
            HStack(alignment: .bottom, spacing: 18) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                    let f = LiveFrame(state)
                    let bpm = state.engine.bpm.isFinite ? state.engine.bpm : state.bpm
                    HStack(alignment: .bottom, spacing: 18) {
                        mini(String(format: "%03d", Int(bpm.rounded())), "BPM", id: "bpm")
                        mini(f.barBeat, "BAR.BEAT", color: Theme.orange, id: "bar-beat")
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    if state.isDigging {
                        HStack(spacing: 6) {
                            DotSpinner(color: Theme.orange, dot: 2)
                            Text("DIGGING").crateLabel(11, tracking: 0.14).foregroundStyle(Theme.orange)
                        }
                    } else {
                        Text(state.styleLabel.isEmpty ? "CRATE" : state.styleLabel.uppercased())
                            .crateLabel(11, tracking: 0.14)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(state.sampleLabel.isEmpty ? "AI SAMPLER" : state.sampleLabel.uppercased())
                        .crateLabel(8.5, tracking: 0.14)
                        .foregroundStyle(Theme.mid)
                        .lineLimit(1)
                }
            }
            logLines
            PromptLine(state: state, fontSize: 11, placeholder: "ask for a beat")
            ActionChips(state: state, size: 8,
                        only: ["chip-dilla-nujabes", "chip-house-kit", "chip-flip-it", "chip-ai-perform"])
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
    }

    private var logLines: some View {
        VStack(alignment: .leading, spacing: 3) {
            let lines = Array(state.log.suffix(2))
            if lines.isEmpty {
                Text("TYPE A VIBE OR TAP A CHIP")
                    .crateLabel(8.5, tracking: 0.16)
                    .foregroundStyle(Theme.dim)
                Text(" ").font(Theme.mono(10))
            }
            ForEach(lines) { line in
                HStack(spacing: 6) {
                    Text(line.tag.uppercased() + (line.ms.map { " " + UIHelpers.msText($0) } ?? ""))
                        .font(Theme.mono(10, bold: true))
                        .foregroundStyle(Theme.tint(line.tint))
                        .fixedSize()
                    Text(line.text)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-log")
    }

    private func mini(_ value: String, _ label: String, color: Color = Theme.text, id: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(Theme.doto(30)).foregroundStyle(color).fixedSize().frame(height: 30 * 0.74)
            Text(label).crateLabel(8, tracking: 0.18).foregroundStyle(Theme.mid).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var bottomRow: some View {
        HStack(spacing: 6) {
            ForEach(Bank.allCases, id: \.self) { b in
                BankButton(bank: b, selected: state.bank == b, height: 40) { CrateUI.shared.selectBank(b, state) }
                    .frame(width: 38)
            }
            Spacer(minLength: 4)
            TransportRow(state: state, height: 40)
                .frame(width: 132)
            DigButton(state: state, height: 40)
                .frame(maxWidth: 110)
        }
    }
}

/// Tent pose (audience side): the huge name of the last-hit pad in Doto + a dot-matrix level meter.
struct CrowdView: View {
    let state: AppState

    /// Hats and shakers tick every 16th, so the crowd display follows the "big" hits.
    private static let skipA: Set<Int> = [4, 5, 6, 10]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
            let f = LiveFrame(state)
            let (pad, age) = lastHit(f, now: ctx.date)
            let level = Double(state.engine.level())
            GeometryReader { geo in
                VStack(spacing: 0) {
                    HStack {
                        Text("CRATE · CR-16").crateLabel(11).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(String(format: "%03d", Int(state.engine.bpm.rounded()))) BPM · \(f.barBeat)")
                            .crateLabel(11)
                            .foregroundStyle(Theme.mid)
                    }
                    Spacer(minLength: 0)
                    Text(pad.map { UIHelpers.padName(state, $0) ?? "PAD \($0.number)" } ?? "CRATE")
                        .font(Theme.doto(min(geo.size.height * 0.42, 220)))
                        .foregroundStyle(pad.map { Theme.bank($0.bank) } ?? Theme.text)
                        .opacity(age < Theme.flash ? 1 : max(0.55, 1 - age * 0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("crowd-name")
                    Spacer(minLength: 0)
                    if state.performOn {
                        Text("AI PERFORM ▸ \(state.lastPerform.isEmpty ? "ON" : state.lastPerform.uppercased())")
                            .font(Theme.mono(12, bold: true))
                            .foregroundStyle(Theme.orange)
                            .padding(.bottom, 10)
                    }
                    LevelMeter(level: level)
                        .frame(height: 18)
                        .accessibilityIdentifier("crowd-level")
                }
                .padding(20)
            }
        }
        .background(Color.black)
    }

    private func lastHit(_ f: LiveFrame, now: Date) -> (PadID?, Double) {
        let liveAge = now.timeIntervalSince(state.lastHitTime)
        if let p = state.lastHitPad, liveAge < 1.5 { return (p, liveAge) }
        guard f.playing else { return (state.lastHitPad, liveAge) }
        var best: (PadID, Double)? = nil
        for (pad, hits) in f.pattern.lanes {
            if pad.bank == .a && Self.skipA.contains(pad.index) { continue }
            for h in hits where h.velocity >= 60 {
                let a = f.age(f.hitTime(h, pad))
                if best == nil || a < best!.1 { best = (pad, a) }
            }
        }
        guard let b = best else { return (state.lastHitPad, liveAge) }
        return (b.0, b.1 * f.stepDur)
    }
}

/// Horizontal dot-matrix level meter (orange, last segments red-hot).
struct LevelMeter: View {
    var level: Double
    var segments = 32

    var body: some View {
        GeometryReader { g in
            let lit = Int((pow(min(1, max(0, level)), 0.5) * Double(segments)).rounded())
            HStack(spacing: 3) {
                ForEach(0..<segments, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(i < lit ? (i > segments - 5 ? Theme.red : Theme.orange) : Theme.dotOff)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}
