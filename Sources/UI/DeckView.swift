import SwiftUI

/// The chassis half, direction 05 (COLOUR-CODED): pictogram MODE keys, 4×4 pads (or the KEYS keyboard),
/// round BANK A–D keys, LEVEL/PUNCH fader with a printed scale, REC / PLAY / STOP, the black ✦ DIG key.
/// Landscape (~669×455) = the mock's three columns; portrait (~455×669) = modes on top, pads, controls below.
/// KEYS mode hides the right column so the one-octave keyboard gets the full deck width.
struct DeckView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                DeckSurface()
                if state.mode == .keys {
                    wideKeys(size)
                } else if size.height > size.width * 1.05 {
                    portrait(size)
                } else {
                    landscape(size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Deck05.alu)
        .ignoresSafeArea(.keyboard)
        .crateDeferEdgeGestures()
        .onChange(of: state.mode) { _, m in
            if m == .keys { CrateUI.shared.ensurePitchedSelection(state) }
        }
    }

    // MARK: layouts

    /// One slim control row (two in portrait) leaves the entire deck width for the one-octave keyboard.
    private func wideKeys(_ size: CGSize) -> some View {
        let tall = size.height > size.width * 1.05
        let key: CGFloat = 28
        let inset: CGFloat = tall ? 16 : 22
        return VStack(spacing: 10) {
            if tall {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(modeItems.filter(\.isMode), id: \.self) { item in
                        modeButton(item, key: 30, labelBelow: true)
                            .frame(maxWidth: .infinity)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    ForEach(modeItems.filter { !$0.isMode }, id: \.self) { item in
                        modeButton(item, key: key, labelBelow: true)
                    }
                    Spacer(minLength: 6)
                    TransportRow(state: state, height: key)
                        .frame(width: key * 3 + 12)
                    DigButton(state: state, height: key)
                        .frame(width: 64)
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(modeItems, id: \.self) { item in
                                modeButton(item, key: key, labelBelow: true)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    TransportRow(state: state, height: key)
                        .frame(width: key * 3 + 12)
                    DigButton(state: state, height: key)
                        .frame(width: 76)
                }
                .frame(height: key + 14)
            }
            KeysView(state: state)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 8) {
                BrandMark(inline: true)
                ProjectChip(state: state).padding(.leading, 10)
                Spacer(minLength: 8)
                // BOUNCE hidden from the deck (BounceControl kept in code).
            }
            .frame(height: 24)
        }
        .padding(.horizontal, inset)
        .padding(.top, inset)
        .padding(.bottom, 8)
    }

    /// The mock at 669×455: 28 | modes 80 | 18 | pads | 24 | right 102 | 26.
    private func landscape(_ size: CGSize) -> some View {
        let narrow = size.width < 600
        let left: CGFloat = narrow ? 16 : 28
        let right: CGFloat = narrow ? 14 : 26
        let top: CGFloat = min(31, max(14, size.height * 0.052))
        let bottom: CGFloat = min(31, max(12, size.height * 0.048))
        let contentH = max(200, size.height - top - bottom)
        return HStack(alignment: .top, spacing: 0) {
            leftColumn
                .frame(width: narrow ? 74 : 80, height: contentH, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 8) {
                center
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: contentH)
            .padding(.leading, narrow ? 12 : 18)
            .padding(.trailing, narrow ? 16 : 24)
            rightColumn
                .frame(width: 102, height: contentH)
        }
        .padding(.leading, left)
        .padding(.trailing, right)
        .padding(.top, top)
        .padding(.bottom, bottom)
    }

    /// Portrait: one row of mode keys, the pads, then BANK | LEVEL | transport + DIG, wordmark + BOUNCE.
    private func portrait(_ size: CGSize) -> some View {
        let inset: CGFloat = size.width < 420 ? 14 : 20
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(modeItems, id: \.self) { item in
                    modeButton(item, key: 30, labelBelow: true)
                        .frame(maxWidth: .infinity)
                }
            }
            center
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 14)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    DeckLabel("Bank")
                    BankGrid(state: state, key: 24, spacing: 10)
                        .padding(.top, 11)
                    Spacer(minLength: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    faderLabel
                    fader
                        .padding(.top, 1.5)
                }
                .frame(width: 102)
                .frame(maxWidth: .infinity)
                VStack(spacing: 0) {
                    TransportRow(state: state, height: 32)
                    Spacer(minLength: 8)
                    DigButton(state: state, height: 44)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 142)
            .padding(.top, 16)
            HStack(alignment: .bottom, spacing: 8) {
                BrandMark()
                ProjectChip(state: state).padding(.leading, 10)
                Spacer(minLength: 8)
            }
            .padding(.top, 14)
        }
        .padding(.horizontal, inset)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    /// Landscape left column: mode keys stacked (37 pt pitch, SHIFT set apart), grille + wordmark at the foot.
    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(modeItems.filter { $0 != .shift }, id: \.self) { item in
                modeButton(item, key: 26, labelBelow: false)
            }
            modeButton(.shift, key: 26, labelBelow: false)
            Spacer(minLength: 0)
            BrandMark()
            ProjectChip(state: state)
        }
    }

    /// Landscape right column, spaced as the mock (BANK 0, keys 17, LEVEL 78, transport 290, DIG 348 of 392).
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            DeckLabel("Bank")
            BankGrid(state: state)
                .padding(.top, 11)
            faderLabel
                .padding(.top, 25)
            fader
                .padding(.top, 1.5)
                .frame(maxHeight: .infinity)
            TransportRow(state: state, height: 30)
                .padding(.top, 20)
            DigButton(state: state, height: 44)
                .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var center: some View {
        switch state.mode {
        case .keys:
            KeysView(state: state)
        case .padFX:
            PadFXView(state: state)
        case .sample:
            VStack(spacing: 6) {
                SampleModePanel(state: state)
                PadGridView(state: state)
            }
        default:
            PadGridView(state: state)
        }
    }

    private var faderLabel: some View {
        DeckLabel(state.mode == .padFX ? "Punch" : "Level")
    }

    @ViewBuilder
    private var fader: some View {
        if state.mode == .padFX {
            PunchFader(state: state)
        } else {
            let pad = state.selectedPad
            let ui = CrateUI.shared
            FaderView(value: ui.level(pad), id: "level-fader") { v in
                ui.levels[pad] = v
                ui.onLevel?(pad, v)
            }
        }
    }

    // MARK: mode keys

    enum ModeItem: Hashable {
        case mode(Mode), shift, octDown, octUp, scale

        var isMode: Bool {
            if case .mode = self { return true }
            return false
        }
    }

    private var modeItems: [ModeItem] {
        if state.mode == .keys {
            return [.mode(.sample), .mode(.chop), .mode(.keys), .mode(.seq), .mode(.padFX), .octDown, .octUp, .scale]
        }
        return [.mode(.sample), .mode(.chop), .mode(.keys), .mode(.seq), .mode(.padFX), .mode(.levels16), .shift]
    }

    @ViewBuilder
    private func modeButton(_ item: ModeItem, key: CGFloat, labelBelow: Bool) -> some View {
        let ui = CrateUI.shared
        switch item {
        case .mode(let m):
            ModeKey(glyph: ModeGlyph(m), label: m.label, on: state.mode == m, key: key, labelBelow: labelBelow,
                    id: "mode-" + m.label.lowercased().replacingOccurrences(of: " ", with: "")) {
                ui.setMode(m, state)
            }
        case .shift:
            ModeKey(glyph: .shift, label: "SHIFT", on: ui.shift, key: key, labelBelow: labelBelow,
                    id: "mode-shift") { ui.shift.toggle() }
                .modifier(PadStyleSwitch())
        case .octDown:
            DeckButton(label: "OCT −", id: "oct-down") { state.keysOctave = max(-3, state.keysOctave - 1) }
                .frame(width: key + 12, height: key)
        case .octUp:
            DeckButton(label: "OCT +", id: "oct-up") { state.keysOctave = min(3, state.keysOctave + 1) }
                .frame(width: key + 12, height: key)
        case .scale:
            DeckButton(label: "SCALE", on: state.scaleLock, toggle: true, id: "scale-lock") { state.scaleLock.toggle() }
                .frame(width: key + 18, height: key)
        }
    }
}

/// SAMPLE mode: the mic sampler (hold to record, release to chop into bank D) above the pads.
/// Owns one MicSampler for as long as SAMPLE mode is on screen.
@MainActor
private struct SampleModePanel: View {
    let state: AppState
    @State private var sampler: MicSampler?

    var body: some View {
        Group {
            if let sampler {
                SampleRecordButton(state: state, sampler: sampler)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .onAppear {
            if sampler == nil { sampler = MicSampler(state: state) }
        }
    }
}

/// PAD FX fallback for the hinge: PUNCH 0…1 → state.punch + engine.setPunch. Pull it from high to zero = DROP.
struct PunchFader: View {
    let state: AppState
    @State private var peak: Double = 0

    var body: some View {
        FaderView(value: state.punch, fill: true, id: "punch-fader", marks: FaderView.percentMarks, onChange: { v in
            if let hook = CrateUI.shared.onPunch { hook(v); return }
            peak = max(peak, v)
            state.punch = v
            state.engine.setPunch(v)
        }, onEnd: { v in
            if CrateUI.shared.onPunch != nil { return }
            if peak > 0.6 && v < 0.1 {
                state.punch = 0
                state.engine.drop()
                DebugLog.event("drop", ["src": "fader"])
            } else {
                DebugLog.event("punch", ["p": (v * 100).rounded() / 100])
            }
            peak = v
        })
    }
}
