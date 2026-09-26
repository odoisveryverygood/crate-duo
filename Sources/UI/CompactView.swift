import SwiftUI

/// Outer display (closed, ~466×678): a mini lid (BPM, bar, style/sample, 2 log lines, prompt + chips),
/// the 4×4 pads, and a bottom row with banks, transport and ✦ DIG.
struct CompactView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 16
            let topInset = max(inset, geo.safeAreaInsets.top)
            Group {
                if geo.size.width > geo.size.height {
                    // Closed, held sideways: readouts + transport left, square pad grid right.
                    HStack(spacing: 12) {
                        VStack(spacing: 10) {
                            miniLid
                            Spacer(minLength: 0)
                            bottomRow(stacked: true)
                        }
                        .frame(width: geo.size.width * 0.44)
                        PadGridView(state: state, gap: 5)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    VStack(spacing: 10) {
                        miniLid
                        PadGridView(state: state, gap: 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        bottomRow(stacked: false)
                    }
                }
            }
            .padding(.horizontal, inset)
            .padding(.top, topInset)
            .padding(.bottom, max(inset, geo.safeAreaInsets.bottom))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(OuterField.aluminium)
        .ignoresSafeArea(.keyboard)
        .crateDeferEdgeGestures()
    }

    private var miniLid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CRATE / CR-16").font(OuterField.type(9, weight: 600)).tracking(1.2).foregroundStyle(OuterField.white)
                Spacer(minLength: 6)
                let bank = Text(state.bank.letter).foregroundStyle(OuterField.bank(state.bank))
                Text("BANK \(bank) · \(state.mode.label)").font(OuterField.type(9, weight: 500)).foregroundStyle(OuterField.secondary)
            }
            .lineLimit(1)
            HStack(alignment: .bottom, spacing: 18) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
                    let f = LiveFrame(state)
                    let bpm = state.engine.bpm.isFinite ? state.engine.bpm : state.bpm
                    HStack(alignment: .bottom, spacing: 18) {
                        mini(String(format: "%03d", Int(bpm.rounded())), "BPM", id: "bpm")
                        mini(f.barBeat, "BAR.BEAT", color: OuterField.white, id: "bar-beat")
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    if state.isDigging {
                        HStack(spacing: 6) {
                            DotSpinner(color: Theme.orange, dot: 2)
                            Text("DIGGING").font(OuterField.type(11, weight: 600)).tracking(1.1).foregroundStyle(Theme.orange)
                        }
                    } else {
                        Text(state.styleLabel.isEmpty ? "CRATE" : state.styleLabel.uppercased())
                            .font(OuterField.type(11, weight: 600)).tracking(1.1)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Text(state.sampleLabel.isEmpty ? "AI SAMPLER" : state.sampleLabel.uppercased())
                        .font(OuterField.type(9, weight: 500)).tracking(0.9)
                        .foregroundStyle(Theme.mid)
                        .lineLimit(1)
                }
            }
            logLines
            PromptLine(state: state, fontSize: 11, placeholder: "ask for a beat")
            compactChips
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.black))
    }

    private var compactChips: some View {
        ChipFlow(spacing: 5, lineSpacing: 5) {
            ForEach(ActionChips.items.filter { ["chip-undo", "chip-redo", "chip-flip-it", "chip-ai-perform"].contains($0.id) }) { item in
                let on = item.id == "chip-ai-perform" && state.performOn
                Button {
                    switch item.id {
                    case "chip-undo":
                        Task { @MainActor in await Orchestrator.current?.undo() }
                    case "chip-redo":
                        Task { @MainActor in await Orchestrator.current?.redo() }
                    case "chip-flip-it":
                        state.onFlip?()
                        DebugLog.event("flip")
                    case "chip-ai-perform":
                        state.performOn.toggle()
                        state.onPerformToggle?(state.performOn)
                        DebugLog.event("perform_toggle", ["on": state.performOn])
                    default:
                        if let prompt = item.prompt {
                            CrateUI.shared.draft = ""
                            CrateUI.shared.blurRequest += 1
                            state.dig(prompt)
                        }
                    }
                } label: {
                    Text(item.label).font(OuterField.type(8, weight: 600)).tracking(0.8)
                        .foregroundStyle(on ? OuterField.ink : OuterField.white)
                        .padding(.horizontal, 9).frame(height: 25)
                        .background(on ? OuterField.white : Color.black, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(OuterField.secondary.opacity(0.5), lineWidth: 0.5))
                }
                .buttonStyle(ChipPressStyle())
                .accessibilityIdentifier(item.id).accessibilityLabel(item.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
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
                        .foregroundStyle(OuterField.secondary)
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
            Text(value).font(OuterField.type(40, weight: 300)).tracking(-1.6).monospacedDigit().foregroundStyle(color).fixedSize()
            Text(label).font(OuterField.type(8, weight: 600)).tracking(1.1).foregroundStyle(OuterField.secondary).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    @ViewBuilder
    private func bottomRow(stacked: Bool) -> some View {
        if stacked {
            VStack(spacing: 10) {
                banks
                transport
            }
        } else {
            HStack(spacing: 16) {
                banks.frame(width: 160)
                transport
            }
        }
    }

    private var banks: some View {
        HStack(spacing: 0) {
            ForEach(Bank.allCases, id: \.self) { bank in
                let selected = state.bank == bank
                Button { CrateUI.shared.selectBank(bank, state) } label: {
                    VStack(spacing: 4) {
                        Circle().fill(selected ? OuterField.ink : OuterField.key)
                            .overlay(Circle().strokeBorder(OuterField.seam, lineWidth: selected ? 0 : 0.5))
                            .overlay(Circle().fill(OuterField.bank(bank)).frame(width: 7, height: 7))
                            .frame(width: 29, height: 29)
                        Text(bank.letter).font(OuterField.type(8, weight: 600))
                            .foregroundStyle(selected ? OuterField.ink : OuterField.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bank-\(bank.letter)")
                .accessibilityLabel("Bank \(bank.letter)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var transport: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let playing = state.engine.isPlaying || state.isPlaying
            HStack(spacing: 5) {
                control("rec", symbol: "circle.fill", active: state.isRecording) {
                    state.setRecording(!state.isRecording)
                }
                control("play", symbol: "play.fill", active: playing) {
                    if !state.engine.isPlaying { state.togglePlay() } else { state.isPlaying = true }
                }
                control("stop", symbol: "stop.fill", active: false) {
                    if state.engine.isPlaying { state.togglePlay() } else { state.isPlaying = false }
                    if state.isRecording { state.setRecording(false) }
                }
                Button { CrateUI.shared.digPressed(state) } label: {
                    HStack(spacing: 5) {
                        SparkShape().fill(OuterField.key).frame(width: 9, height: 9)
                        Text("DIG").font(OuterField.type(10, weight: 600)).tracking(1)
                    }
                    .foregroundStyle(OuterField.key)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(state.isDigging ? Theme.orange : OuterField.ink, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dig-button").accessibilityLabel("Dig")
            }
        }
    }

    private func control(_ id: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 12))
                .foregroundStyle(active ? OuterField.key : OuterField.ink)
                .frame(width: 40, height: 44)
                .background(active ? (id == "rec" ? Theme.orange : OuterField.ink) : OuterField.key,
                            in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id).accessibilityLabel(id.uppercased())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

}

/// Legacy tent view, kept in the same Field type language as the accessory card.
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
                        .font(OuterField.type(min(geo.size.height * 0.42, 220), weight: 300))
                        .foregroundStyle(age < Theme.flash ? Theme.orange : OuterField.white)
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

#Preview("Compact · portrait") {
    CompactView(state: AppState(engine: MockEngine())).frame(width: 466, height: 678)
}
#Preview("Compact · landscape") {
    CompactView(state: AppState(engine: MockEngine())).frame(width: 678, height: 466)
}
