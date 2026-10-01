import SwiftUI
import UniformTypeIdentifiers

/// 4×4 pads in MPC order (pad 1 bottom-left, 13–16 top row) for the current bank.
/// Touch-down triggers (multi-touch), velocity from touch height (top 127, bottom 70).
/// Pads flash orange ≤ 100 ms when hit live or when the sequencer plays them.
struct PadGridView: View {
    let state: AppState
    var gap: CGFloat = 5

    @State private var fingers: [ObjectIdentifier: Int] = [:]
    /// Where each finger went down (a take locks when its finger slides up).
    @State private var downAt: [ObjectIdentifier: CGPoint] = [:]
    /// Fingers holding an effect pad on the FX layer (punch-in), newest last.
    @State private var fxFingers: [ObjectIdentifier] = []
    @State private var liveHits: [Int: Date] = [:]
    @State private var dropHover = false
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
            .onChange(of: CrateUI.shared.fxLayer) { _, on in
                if !on, !fxFingers.isEmpty {
                    fxFingers.removeAll()
                    CrateUI.shared.punchOut(state)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.blue, lineWidth: 3)
                    .opacity(dropHover ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .onDrop(of: [UTType.audio.identifier, UTType.fileURL.identifier], isTargeted: $dropHover) { providers, point in
                guard !importing else { return false }
                importing = true
                let col = min(3, max(0, Int((point.x + gap / 2) / (cw + gap))))
                let row = min(3, max(0, Int((point.y + gap / 2) / (ch + gap))))
                let pad = PadID(state.bank, (3 - row) * 4 + col)
                let accepted = AudioImport.receive(providers, at: pad) { result in
                    switch result {
                    case .success(let audio):
                        // A song becomes 16 chops on bank D; a short sound lands on the pad it was dropped on.
                        if audio.duration > 2 { Task { await AudioImport.chop16(audio, state: state); importing = false } }
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
        let ui = CrateUI.shared
        if ui.fxLayer {
            // FX held (or latched): the pads are the effects; tap one to pick it.
            let fx = FXType.padLayout[i]
            FXPadCell(number: i + 1, label: fx?.label ?? "PUNCH", hint: fx?.hint ?? "LPF + SPACE",
                      selected: fx == state.fx && (fx != nil || state.punch > 0.04), held: lit)
                .modifier(PadAccessibility(id: "fx-pad-\(i + 1)", label: fx?.label ?? "PUNCH") { ui.pickFX(i, state) })
        } else if mode == .levels16 {
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
            let recording = ui.recordingPad == pad
            PadCell(number: i + 1,
                    name: name,
                    placeholder: pad.bank == .a ? UIHelpers.bankANames[i] : nil,
                    barColor: name != nil ? Theme.bank(pad.bank) : nil,
                    lit: lit && !recording,
                    selected: state.selectedPad == pad,
                    shortcut: MusicalTyping.padKeys[i].uppercased(),
                    category: state.sound(mode == .levels16 ? state.selectedPad : pad)?.category,
                    bank: pad.bank,
                    spinning: isSounding(i, pad: pad, frame: frame),
                    armed: ui.sampleArmed && ui.recordingPad == nil,
                    recording: recording,
                    recSeconds: recording ? ui.sampler?.seconds ?? 0 : 0)
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
            let ui = CrateUI.shared
            fingers[id] = i
            downAt[id] = pt
            if let rec = ui.recordingPad, ui.recordLocked {
                ui.endTake(rec)   // a locked take: any pad stops it
                fingers[id] = nil
                return
            }
            if ui.fxLayer {
                liveHits[i] = Date()
                fxFingers.append(id)
                ui.punchIn(i, amount: punchAmount(yIn, ch), state)
            } else if ui.sampleArmed {
                ui.beginTake(PadID(state.bank, i))   // hold = record into this pad; lift = done
            } else {
                fire(i, velocity: vel)
            }
        case .moved:
            // recording: slide the finger up off the pad to lock the take (hands-free)
            if let i = fingers[id], let start = downAt[id], CrateUI.shared.recordingPad == PadID(state.bank, i),
               !CrateUI.shared.recordLocked, start.y - pt.y > 44 {
                CrateUI.shared.recordLocked = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DebugLog.event("take_lock", ["pad": "\(state.bank.letter)\(i + 1)"])
            }
            // the newest finger on an effect pad sets the amount: slide up for more
            if fxFingers.last == id, let i = fingers[id] {
                let row = 3 - i / 4
                let yIn = min(max(pt.y - CGFloat(row) * (ch + gap), 0), ch)
                CrateUI.shared.punchMove(amount: punchAmount(yIn, ch), state)
            }
        case .ended:
            if let i = fingers[id], CrateUI.shared.recordingPad == PadID(state.bank, i), !CrateUI.shared.recordLocked {
                CrateUI.shared.endTake(PadID(state.bank, i))
            }
            downAt[id] = nil
            if let k = fxFingers.firstIndex(of: id) {
                fxFingers.remove(at: k)
                if let other = fxFingers.last, let j = fingers[other], CrateUI.shared.fxLayer {
                    CrateUI.shared.punchIn(j, amount: state.punch, state)   // the finger still down takes over
                } else if fxFingers.isEmpty {
                    CrateUI.shared.punchOut(state)
                }
            }
            fingers[id] = nil
        }
    }

    /// Punch-in depth from where the finger is on its pad: bottom edge 25 %, top edge 100 %.
    private func punchAmount(_ yIn: CGFloat, _ ch: CGFloat) -> Double {
        Double(min(1, max(0.25, 0.25 + 0.75 * (1 - yIn / max(1, ch)))))
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
    /// SAMPLE armed: every pad blinks (hold one to record into it).
    var armed = false
    /// This pad is recording the mic right now.
    var recording = false
    var recSeconds: Double = 0
    @AppStorage(PadStyle.storageKey) private var padStyle = "plain"

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(recording ? Theme.orange.opacity(0.14) : (lit ? PadFinish.pressed : PadFinish.key))
            if lit || recording { Rectangle().fill(Theme.orange).frame(height: 3) }
            if recording {
                Text(String(format: "● %.1f s", recSeconds))
                    .font(Deck05.font(7.5, 700))
                    .foregroundStyle(Theme.orange)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 7).padding(.top, 7)
            }
            if padStyle == "records" {
                RecordPad(category: category, bank: bank, active: spinning || lit)
                    .padding(.horizontal, 18).padding(.top, 19).padding(.bottom, 23)
                Text("CR-\(100 + number)")
                    .font(Theme.mono(6)).foregroundStyle(PadFinish.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing).padding(6)
            }
            Text("\(number)")
                .font(Deck05.font(6.5, 500))
                .foregroundStyle(PadFinish.muted.opacity(0.45))
                .padding(.leading, 7)
                .padding(.top, 7)
            // Keyboard legends are intentionally not drawn (keyboard control still works); `shortcut` kept for API.
            Text(name ?? placeholder ?? "")
                .font(Deck05.font(nameSize, 500))
                .tracking(nameSize * 0.03)
                .foregroundStyle(name == nil ? PadFinish.muted.opacity(0.7) : PadFinish.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4.5))
        .overlay(
            RoundedRectangle(cornerRadius: 4.5)
                .strokeBorder(recording ? Theme.orange : (selected && !lit ? PadFinish.muted : PadFinish.seam), lineWidth: 1)
        )
        .overlay {
            if armed {
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    RoundedRectangle(cornerRadius: 4.5)
                        .strokeBorder(Theme.orange, lineWidth: 1.5)
                        .opacity(Int(ctx.date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0 ? 0.9 : 0.15)
                }
                .allowsHitTesting(false)
            }
        }
    }
}
