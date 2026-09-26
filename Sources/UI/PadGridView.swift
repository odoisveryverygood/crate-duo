import SwiftUI
import UniformTypeIdentifiers

/// 4×4 pads in MPC order (pad 1 bottom-left, 13–16 top row) for the current bank.
/// Touch-down triggers (multi-touch), velocity from touch height (top 127, bottom 70).
/// Pads flash orange ≤ 100 ms when hit live or when the sequencer plays them.
struct PadGridView: View {
    let state: AppState
    var gap: CGFloat = 5

    @State private var fingers: [ObjectIdentifier: Int] = [:]
    @State private var liveHits: [Int: Date] = [:]
    @State private var dropHover = false
    @State private var pendingChop: ImportedAudio?
    @State private var importing = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cw = max(1, (size.width - 3 * gap) / 4)
            let ch = max(1, (size.height - 3 * gap) / 4)
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { ctx in
                let frame = LiveFrame(state)
                let now = ctx.date
                let bank = state.bank
                let mode = state.mode
                let held = Set(fingers.values)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<16, id: \.self) { i in
                        let row = 3 - i / 4
                        let col = i % 4
                        let pad = PadID(bank, i)
                        cell(i, pad: pad, mode: mode, lit: isLit(i, pad: pad, mode: mode, held: held, frame: frame, now: now), frame: frame)
                            .frame(width: cw, height: ch)
                            .position(x: CGFloat(col) * (cw + gap) + cw / 2,
                                      y: CGFloat(row) * (ch + gap) + ch / 2)
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .topLeading)
            }
            .overlay(
                TouchSurface { phase, id, pt in
                    handle(phase, id, pt, cw: cw, ch: ch)
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.blue, lineWidth: 3)
                    .opacity(dropHover ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .onDrop(of: [UTType.audio.identifier, UTType.fileURL.identifier], isTargeted: $dropHover) { providers, point in
                guard !importing, pendingChop == nil else { return false }
                importing = true
                let col = min(3, max(0, Int((point.x + gap / 2) / (cw + gap))))
                let row = min(3, max(0, Int((point.y + gap / 2) / (ch + gap))))
                let pad = PadID(state.bank, (3 - row) * 4 + col)
                let accepted = AudioImport.receive(providers, at: pad) { result in
                    switch result {
                    case .success(let audio):
                        if audio.duration > 2 { pendingChop = audio; importing = false }
                        else { Task { await AudioImport.loadOnPad(audio, state: state); importing = false } }
                    case .failure(let error):
                        importing = false
                        state.addLog("ERR", "Drop: \(error.localizedDescription)", tint: .red)
                    }
                }
                if !accepted { importing = false }
                return accepted
            }
        }
        .confirmationDialog("Import audio", isPresented: Binding(
            get: { pendingChop != nil }, set: { if !$0 {
                if let audio = pendingChop { try? FileManager.default.removeItem(at: audio.url) }
                pendingChop = nil
            } }
        ), titleVisibility: .visible) {
            if let audio = pendingChop {
                Button("CHOP 16 into Bank D") {
                    pendingChop = nil
                    importing = true
                    Task { await AudioImport.chop16(audio, state: state); importing = false }
                }
                Button("Load on pad \(audio.pad.bank.letter)\(audio.pad.number)") {
                    pendingChop = nil
                    importing = true
                    Task { await AudioImport.loadOnPad(audio, state: state); importing = false }
                }
            }
        } message: {
            if let audio = pendingChop {
                Text("\(audio.name) · \(String(format: "%.1f", audio.duration)) s")
            }
        }
    }

    private func isLit(_ i: Int, pad: PadID, mode: Mode, held: Set<Int>, frame: LiveFrame, now: Date) -> Bool {
        if held.contains(i) || state.heldPads.contains(pad) { return true }
        if let t = liveHits[i], now.timeIntervalSince(t) < Theme.flash { return true }
        if mode == .levels16 { return false }
        if state.lastHitPad == pad, now.timeIntervalSince(state.lastHitTime) < Theme.flash { return true }
        return frame.sequencerFlash(pad)
    }

    @ViewBuilder
    private func cell(_ i: Int, pad: PadID, mode: Mode, lit: Bool, frame: LiveFrame) -> some View {
        if mode == .levels16 {
            let sel = state.selectedPad
            PadCell(number: i + 1,
                    name: "TUNE \(UIHelpers.signed(i - 7))",
                    placeholder: nil,
                    barColor: state.sound(sel) != nil ? Theme.bank(sel.bank) : nil,
                    lit: lit,
                    selected: i == 7,
                    shortcut: MusicalTyping.padKeys[i].uppercased(),
                    category: state.sound(mode == .levels16 ? state.selectedPad : pad)?.category,
                    bank: pad.bank,
                    spinning: isSounding(i, pad: pad, frame: frame))
                .modifier(PadAccessibility(id: "pad-\(pad.bank.letter)-\(pad.number)",
                                           label: "Tune \(i - 7)") { fire(i, velocity: 112) })
        } else {
            let name = UIHelpers.padName(state, pad)
            PadCell(number: i + 1,
                    name: name,
                    placeholder: pad.bank == .a ? UIHelpers.bankANames[i] : nil,
                    barColor: name != nil ? Theme.bank(pad.bank) : nil,
                    lit: lit,
                    selected: state.selectedPad == pad,
                    shortcut: MusicalTyping.padKeys[i].uppercased(),
                    category: state.sound(mode == .levels16 ? state.selectedPad : pad)?.category,
                    bank: pad.bank,
                    spinning: isSounding(i, pad: pad, frame: frame))
                .modifier(PadAccessibility(id: "pad-\(pad.bank.letter)-\(pad.number)",
                                           label: name ?? "Pad \(pad.number)") { fire(i, velocity: 110) })
        }
    }

    private func isSounding(_ i: Int, pad: PadID, frame: LiveFrame) -> Bool {
        let sound = state.sound(state.mode == .levels16 ? state.selectedPad : pad)
        let duration = max(Theme.flash, (sound?.end ?? ((sound?.start ?? 0) + 0.4)) - (sound?.start ?? 0))
        if fingers.values.contains(i) || state.heldPads.contains(pad) { return true }
        if let hit = liveHits[i], Date().timeIntervalSince(hit) < duration { return true }
        if state.lastHitPad == pad, Date().timeIntervalSince(state.lastHitTime) < duration { return true }
        guard frame.playing else { return false }
        if !frame.soundingNotes(pad).isEmpty { return true }
        return (frame.pattern.lanes[pad] ?? []).contains {
            let time = frame.hitTime($0, pad)
            return frame.pos >= time && frame.age(time) * frame.stepDur < duration
        }
    }

    private func handle(_ phase: TouchPhaseUI, _ id: ObjectIdentifier, _ pt: CGPoint, cw: CGFloat, ch: CGFloat) {
        switch phase {
        case .began:
            let col = min(3, max(0, Int((pt.x + gap / 2) / (cw + gap))))
            let row = min(3, max(0, Int((pt.y + gap / 2) / (ch + gap))))
            let i = (3 - row) * 4 + col
            let yIn = min(max(pt.y - CGFloat(row) * (ch + gap), 0), ch)
            let vel = Int((127 - 57 * yIn / ch).rounded())
            fingers[id] = i
            fire(i, velocity: vel)
        case .moved:
            break
        case .ended:
            fingers[id] = nil
        }
    }

    private func fire(_ i: Int, velocity: Int) {
        let pad = PadID(state.bank, i)
        liveHits[i] = Date()
        if CrateUI.shared.shift {
            state.selectedPad = pad
            CrateUI.shared.shift = false
            return
        }
        if state.mode == .levels16 {
            state.hit(state.selectedPad, velocity: 112, semitones: Double(i - 7))
        } else {
            state.hit(pad, velocity: min(127, max(1, velocity)))
            if state.selectedPad != pad { state.selectedPad = pad }
        }
    }
}

private struct PadAccessibility: ViewModifier {
    let id: String
    let label: String
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(id)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

/// Direction 05 pad with optional direction 07 vinyl; orange is reserved for live hits.
struct PadCell: View {
    let number: Int
    let name: String?
    let placeholder: String?
    let barColor: Color?
    let lit: Bool
    var selected = false
    var nameSize: CGFloat = 10
    var shortcut: String = ""
    var category: Category? = nil
    var bank: Bank = .a
    var spinning = false
    @AppStorage(PadStyle.storageKey) private var padStyle = "plain"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(lit ? PadFinish.pressed : PadFinish.key)
            if lit { Rectangle().fill(Theme.orange).frame(height: 3) }
            if padStyle == "records" {
                RecordPad(category: category, bank: bank, active: spinning || lit)
                    .padding(.horizontal, 18).padding(.top, 19).padding(.bottom, 23)
                Text("CR-\(100 + number)")
                    .font(Theme.mono(6)).foregroundStyle(PadFinish.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(6)
            }
            Text(String(format: "%02d", number))
                .font(PadFinish.label(8))
                .tracking(0.8)
                .foregroundStyle(PadFinish.muted)
                .padding(.leading, 7)
                .padding(.top, 8)
            Text(shortcut)
                .font(Theme.label(9))
                .foregroundStyle(PadFinish.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(7)
                .offset(y: padStyle == "records" ? 10 : 0)
            Text(name ?? placeholder ?? "")
                .font(PadFinish.label(nameSize))
                .tracking(nameSize * 0.06)
                .foregroundStyle(name == nil ? PadFinish.muted : PadFinish.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4.5))
        .overlay(
            RoundedRectangle(cornerRadius: 4.5)
                .strokeBorder(selected && !lit ? PadFinish.muted : PadFinish.seam, lineWidth: 1)
        )

    }
}
