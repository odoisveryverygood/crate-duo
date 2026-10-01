import SwiftUI

/// The lid on an iPhone (about 40 % of the screen, over the deck), five rows so the beat gets the room:
/// one header line (project · tempo · bar · loop length · undo / redo), the pad line, the main area (step grid,
/// pad editor or the DIG composer), the result line, and the `›` prompt with FLIP IT / AI PERFORM.
struct PhoneLidView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let focused = CrateUI.shared.promptFocused
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 8) {
                    LidProjectChip(state: state)
                        .frame(maxWidth: geo.size.width * 0.3, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    TempoChip(state: state, size: 12)
                    BarReadout(state: state, size: 12)
                    Spacer(minLength: 4)
                    LoopMenu(state: state, compact: true)
                    HistoryButtons(size: 28)
                }
                .frame(height: 30)
                PadLine(state: state)
                    .padding(.top, 10)
                Group {
                    if focused {
                        DigComposer(state: state)
                    } else if CrateUI.shared.editorOpen {
                        PadEditorView(state: state)
                    } else {
                        mainArea
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .padding(.top, 8)
                Group {
                    if state.punch > 0.04 {
                        PunchStrip(punch: state.punch, fx: state.fx)
                    } else {
                        LidResultLine(state: state)
                    }
                }
                .frame(height: 16)
                .padding(.top, 6)
                LidPromptRow(state: state, narrow: false, showChips: !focused, chipIDs: LidChips.phoneSet)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Theme.oled)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private var mainArea: some View {
        switch state.mode {
        case .seq:
            // A full beat can have 9+ lanes: keep a comfortable row pitch and scroll instead of squashing.
            GeometryReader { g in
                let rows = max(5, SeqRows.build(state, state.engine.pattern).count)
                let need = SeqGridView.fittedHeight(rows: rows, pitch: 15)
                if need > g.size.height {
                    ScrollView(.vertical, showsIndicators: false) {
                        SeqGridView(state: state, maxPitch: 15).frame(height: need)
                    }
                } else {
                    SeqGridView(state: state, maxPitch: 22)
                }
            }
        case .chop:
            ChopWaveView(state: state)
        case .keys:
            KeysWaveView(state: state)
        case .sample:
            if (0..<16).contains(where: { state.sound(PadID(.b, $0)) != nil }) {
                ChopWaveView(state: state)
            } else {
                AILogView(state: state, maxLines: 5, size: 10.5)
            }
        case .padFX, .levels16:
            AILogView(state: state, maxLines: 5, size: 10.5)
        }
    }
}

/// The current project on the lid (the deck's PROJECT chip on the Duo): tap → the projects sheet.
struct LidProjectChip: View {
    let state: AppState
    @State private var store = ProjectStore.shared
    @State private var open = false

    var body: some View {
        Button { open = true } label: {
            HStack(spacing: 5) {
                Text(store.currentName.uppercased())
                    .font(Theme.inter(9, 600))
                    .tracking(9 * 0.12)
                    .foregroundStyle(Theme.lidInk)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Theme.lidGrey1)
            }
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("project-chip")
        .accessibilityLabel("Project \(store.currentName)")
        .sheet(isPresented: $open) {
            ProjectsView(state: state)
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.oled)
        }
    }
}
