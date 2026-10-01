import SwiftUI

// Compact lid controls: tempo, loop length, bar position, undo / redo. Every one is a visible tap target;
// nothing is changed by an invisible drag.

/// "100 BPM": tap for the tempo sheet (TAP tempo, ±1, swing). During a count-in it shows the beats left.
struct TempoChip: View {
    let state: AppState
    var size: CGFloat = 13
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if let n = CrateUI.shared.countIn {
                        Text("\(n)").font(Theme.inter(size, 600)).foregroundStyle(Theme.live)
                        Text("COUNT-IN").font(Theme.inter(size * 0.62, 600)).tracking(0.6).foregroundStyle(Theme.live)
                    } else {
                        Text("\(Int(currentBPM(state).rounded()))")
                            .font(Theme.inter(size, 600)).monospacedDigit().foregroundStyle(Theme.lidInk)
                        Text("BPM").font(Theme.inter(size * 0.62, 600)).tracking(0.6).foregroundStyle(Theme.lidGrey1)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.chipStroke, lineWidth: 0.6))
                .contentShape(Rectangle())
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tempo")
                .accessibilityValue("\(Int(currentBPM(state).rounded())) BPM")
            }
        }
        .buttonStyle(ChipPressStyle())
        .accessibilityIdentifier("tempo-chip")
        .sheet(isPresented: $open) {
            TempoSheet(state: state)
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.oled)
        }
    }
}

func currentBPM(_ state: AppState) -> Double { state.engine.bpm.isFinite ? state.engine.bpm : state.bpm }

/// TAP tempo, −1 / +1 and swing presets. The first change in a visit is one UNDO step.
struct TempoSheet: View {
    let state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var taps: [Date] = []
    @State private var checkpointed = false
    @State private var bpm: Double = 90
    @State private var swing: Double = 50

    static let swings: [Double] = [50, 54, 58, 62, 66, 70]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("TEMPO").fieldLabel(7.5).foregroundStyle(Theme.lidGrey1)
                Spacer()
                Button("DONE") { dismiss() }
                    .font(Theme.inter(10, 600)).tracking(0.8).foregroundStyle(Theme.lidInk)
                    .accessibilityIdentifier("tempo-done")
            }
            HStack(spacing: 14) {
                nudge("−", id: "tempo-down") { setBPM(bpm - 1) }
                Text("\(Int(bpm.rounded()))")
                    .font(Theme.interLight(56)).monospacedDigit().tracking(-2)
                    .foregroundStyle(Theme.lidInk)
                    .frame(minWidth: 120)
                    .accessibilityIdentifier("tempo-value")
                nudge("+", id: "tempo-up") { setBPM(bpm + 1) }
            }
            Button(action: tap) {
                Text(taps.count >= 2 ? "TAP · \(taps.count)" : "TAP TEMPO")
                    .font(Theme.inter(12, 700)).tracking(1.6)
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.lidInk))
                    .contentShape(Rectangle())
            }
            .buttonStyle(ChipPressStyle())
            .accessibilityIdentifier("tempo-tap")
            VStack(alignment: .leading, spacing: 8) {
                Text("SWING").fieldLabel(7.5).foregroundStyle(Theme.lidGrey1)
                HStack(spacing: 6) {
                    ForEach(Self.swings, id: \.self) { s in
                        let on = abs(swing - s) < 2
                        Button { setSwing(s) } label: {
                            Text("\(Int(s))")
                                .font(Theme.inter(11, 600)).monospacedDigit()
                                .foregroundStyle(on ? Color.black : Theme.lidInk)
                                .frame(maxWidth: .infinity).frame(height: 36)
                                .background(RoundedRectangle(cornerRadius: 6).fill(on ? Theme.lidInk : Color.black))
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.chipStroke, lineWidth: 0.6)
                                    .opacity(on ? 0 : 1))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ChipPressStyle())
                        .accessibilityIdentifier("swing-\(Int(s))")
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            bpm = currentBPM(state).rounded()
            swing = state.engine.swing
        }
    }

    private func nudge(_ label: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.inter(24, 400)).foregroundStyle(Theme.lidInk)
                .frame(width: 56, height: 56)
                .background(Circle().strokeBorder(Theme.chipStroke, lineWidth: 0.8))
                .contentShape(Circle())
        }
        .buttonStyle(ChipPressStyle())
        .accessibilityIdentifier(id)
    }

    /// Average of the last few tap intervals; a pause of 2 s starts a new count.
    private func tap() {
        let now = Date()
        if let last = taps.last, now.timeIntervalSince(last) > 2 { taps = [] }
        taps.append(now)
        if taps.count > 5 { taps.removeFirst(taps.count - 5) }
        guard taps.count >= 2 else { return }
        let gaps = zip(taps.dropFirst(), taps).map { $0.timeIntervalSince($1) }
        let avg = gaps.reduce(0, +) / Double(gaps.count)
        guard avg > 0.2 else { return }
        setBPM(60 / avg)
    }

    private func setBPM(_ v: Double) {
        let clamped = min(200, max(50, v.rounded()))
        Orchestrator.current?.setTempo(clamped, checkpoint: !checkpointed)
        checkpointed = true
        bpm = clamped
        DebugLog.event("tempo_sheet", ["bpm": clamped])
    }

    private func setSwing(_ s: Double) {
        if !checkpointed { Orchestrator.current?.checkpoint("swing \(Int(swing))") }
        checkpointed = true
        state.engine.swing = s
        state.swing = s
        swing = s
        DebugLog.event("swing", ["swing": s])
    }
}

/// The playing bar.beat, small ("2.3").
struct BarReadout: View {
    let state: AppState
    var size: CGFloat = 13

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let f = LiveFrame(state)
            HStack(spacing: 0) {
                Text("\(f.bar + 1)").foregroundStyle(f.playing ? Theme.lidInk : Theme.lidGrey1)
                Text(".\(f.beat + 1)").foregroundStyle(Theme.lidGrey1)
            }
            .font(Theme.inter(size, 500)).monospacedDigit()
            .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("bar-beat")
        .accessibilityLabel("Bar")
    }
}

/// The LOOP bar as a menu: tap it, pick 1, 2, 4 or 8 bars.
struct LoopMenu: View {
    let state: AppState
    var compact = false

    var body: some View {
        Menu {
            ForEach([1, 2, 4, 8], id: \.self) { n in
                Button {
                    Orchestrator.current?.setBars(n)
                } label: {
                    if n == currentBars { Label("\(n) \(n == 1 ? "bar" : "bars")", systemImage: "checkmark") }
                    else { Text("\(n) \(n == 1 ? "bar" : "bars")") }
                }
            }
        } label: {
            LoopBar(state: state, compact: compact)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("loop-bar")
        .accessibilityLabel("Loop length")
        .accessibilityValue("\(currentBars) bars")
    }

    private var currentBars: Int {
        let p = state.engine.pattern
        return max(1, p.lanes.isEmpty && p.notes.isEmpty ? state.bars : p.bars)
    }
}

/// ↶ ↷ (dim when there's nothing to undo / redo).
struct HistoryButtons: View {
    var size: CGFloat = 30

    var body: some View {
        let undo = CrateUndoSignal.shared
        HStack(spacing: 4) {
            icon("arrow.uturn.backward", on: undo.canUndo, id: "undo") {
                Task { @MainActor in await Orchestrator.current?.undo() }
            }
            icon("arrow.uturn.forward", on: undo.canRedo, id: "redo") {
                Task { @MainActor in await Orchestrator.current?.redo() }
            }
        }
    }

    private func icon(_ name: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? Theme.lidInk : Theme.lidGrey2)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.chipStroke, lineWidth: 0.6))
                .contentShape(Rectangle())
        }
        .buttonStyle(ChipPressStyle())
        .disabled(!on)
        .accessibilityIdentifier("history-\(id)")
        .accessibilityLabel(id == "undo" ? "Undo" : "Redo")
    }
}

/// KEEP JAM: shows up once you've played pads over the loop with REC off; one tap writes that jam into the beat
/// (like the MPC's retrospective record, without the button combo). Gone a minute after the last hit.
struct KeepJamChip: View {
    let state: AppState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let info = state.engine.jamInfo()
            if info.count > 0, info.age < 60 {
                Button { Orchestrator.current?.keepJam() } label: {
                    HStack(spacing: 5) {
                        Circle().fill(Theme.live).frame(width: 6, height: 6)
                        Text("KEEP JAM").font(Theme.inter(6.8, 700)).tracking(0.7).foregroundStyle(Color.black)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 21)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.lidInk))
                    .contentShape(Rectangle())
                }
                .buttonStyle(ChipPressStyle())
                .accessibilityIdentifier("chip-keep-jam")
                .accessibilityLabel("Keep jam, \(info.count) hits")
            }
        }
        .fixedSize()
    }
}
