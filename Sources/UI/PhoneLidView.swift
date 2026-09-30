import SwiftUI

/// The lid on an iPhone (about 40 % of the screen, over the deck): project + LOOP bar, the hero readouts,
/// the mode's main area (SEQ grid / CHOP / KEYS waveform / AI log), the result line and the `›` prompt with chips.
/// Same parts as `LidDisplayView`, minus the BANKS legend (the deck's bank keys carry the colours).
struct PhoneLidView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            // Tall phones (Pro Max) also get the style line and the timing strip.
            let roomy = geo.size.height >= 340 && geo.size.width >= 300
            let focused = CrateUI.shared.promptFocused
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 12) {
                    LidProjectChip(state: state)
                    Spacer(minLength: 8)
                    LoopBar(state: state)
                }
                if roomy {
                    LidTitleRow(state: state, showLoop: false)
                        .padding(.top, 8)
                }
                LidHero(state: state, size: geo.size.height < 300 ? 32 : 38, gap: 28)
                    .padding(.top, roomy ? 12 : 10)
                Group {
                    if focused {
                        DigComposer(state: state)
                    } else {
                        mainArea
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .padding(.top, 10)
                Group {
                    if state.punch > 0.04 {
                        PunchStrip(punch: state.punch, fx: state.fx)
                    } else {
                        LidResultLine(state: state)
                    }
                }
                .frame(height: 16)
                .padding(.top, 6)
                if roomy {
                    LidTimingStrip(state: state)
                        .frame(height: 8)
                        .padding(.top, 6)
                }
                LidPromptRow(state: state, narrow: true, showChips: !focused)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
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
