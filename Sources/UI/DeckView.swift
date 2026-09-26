import SwiftUI

/// The chassis half: MODE buttons, 4×4 pads (or the KEYS keyboard), PAD BANK, LEVEL/PUNCH fader, transport, ✦ DIG.
/// Landscape (~669×455) = the mockup's three columns; portrait (~455×669) = modes on top, pads, controls below.
struct DeckView: View {
    let state: AppState

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Theme.chassis
                if state.mode == .keys {
                    wideKeys
                } else if size.height > size.width * 1.05 {
                    portrait(size)
                } else {
                    landscape(size)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Theme.chassis)
        .ignoresSafeArea(.keyboard)
        .crateDeferEdgeGestures()
        .onChange(of: state.mode) { _, m in
            if m == .keys { CrateUI.shared.ensurePitchedSelection(state) }
        }
    }

    // MARK: layouts

    /// One slim control row leaves the entire deck width for the one-octave keyboard.
    private var wideKeys: some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(modeItems, id: \.self) { item in
                            modeButton(item).frame(width: 46, height: 32)
                        }
                    }
                }
                TransportRow(state: state, height: 32).frame(width: 106)
                DigButton(state: state, height: 32).frame(width: 62)
            }
            .frame(height: 32)
            KeysView(state: state).frame(maxWidth: .infinity, maxHeight: .infinity)
            BrandLine()
        }
        .padding(12)
    }

    private func landscape(_ size: CGSize) -> some View {
        let inset: CGFloat = size.width < 560 ? 12 : 16
        let brandH: CGFloat = 26
        let contentH = max(100, size.height - inset * 2 - brandH)
        let items = modeItems
        let btnH = min(50, max(28, (contentH - 16 - 8 * CGFloat(items.count - 1)) / CGFloat(items.count)))
        let leftW: CGFloat = size.width < 560 ? 74 : 86
        let rightW: CGFloat = size.width < 560 ? 92 : 104
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    SilkLabel("MODE").frame(height: 8)
                    ForEach(items, id: \.self) { item in
                        modeButton(item).frame(height: btnH)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: leftW, height: contentH)

                center
                    .frame(maxWidth: .infinity)
                    .frame(height: contentH)

                rightColumn
                    .frame(width: rightW, height: contentH)
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                BrandLine().frame(maxWidth: .infinity, alignment: .leading)
                BounceControl(state: state)
            }
        }
        .padding(.horizontal, inset)
        .padding(.top, inset)
        .padding(.bottom, 9)
    }

    private func portrait(_ size: CGSize) -> some View {
        let inset: CGFloat = 16
        let items = modeItems
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SilkLabel("MODE")
                Spacer(minLength: 8)
                SilkLabel(selectedInfo, color: Theme.mid)
            }
            HStack(spacing: 5) {
                ForEach(items, id: \.self) { item in
                    modeButton(item).frame(maxWidth: .infinity).frame(height: 40)
                }
            }
            center
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SilkLabel("PAD BANK").frame(height: 8)
                    BankGrid(state: state)
                }
                .frame(width: min(124, size.width * 0.28))
                VStack(alignment: .leading, spacing: 8) {
                    faderLabel
                    fader
                }
                .frame(width: state.mode == .padFX ? 84 : 62)
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    TransportRow(state: state)
                    DigButton(state: state)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 104)
            HStack(spacing: 8) {
                BrandLine().frame(maxWidth: .infinity, alignment: .leading)
                BounceControl(state: state)
            }
        }
        .padding(.horizontal, inset)
        .padding(.top, inset)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var center: some View {
        if state.mode == .keys {
            KeysView(state: state)
        } else {
            PadGridView(state: state)
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            SilkLabel("PAD BANK").frame(height: 8)
            BankGrid(state: state)
            faderLabel.padding(.top, 4)
            fader.frame(maxHeight: .infinity)
            TransportRow(state: state)
            DigButton(state: state)
        }
    }

    private var faderLabel: some View {
        SilkLabel(state.mode == .padFX ? "PUNCH" : "LEVEL",
                  color: state.mode == .padFX ? Theme.orange : Theme.silk)
            .frame(height: 8)
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

    private var selectedInfo: String {
        let p = state.selectedPad
        let name = UIHelpers.padName(state, p) ?? "EMPTY"
        return "PAD \(p.bank.letter)\(String(format: "%02d", p.number)) · \(name)"
    }

    // MARK: mode buttons

    enum ModeItem: Hashable {
        case mode(Mode), shift, octDown, octUp, scale
    }

    private var modeItems: [ModeItem] {
        if state.mode == .keys {
            return [.mode(.sample), .mode(.chop), .mode(.keys), .mode(.seq), .mode(.padFX), .octDown, .octUp, .scale]
        }
        return [.mode(.sample), .mode(.chop), .mode(.keys), .mode(.seq), .mode(.padFX), .mode(.levels16), .shift]
    }

    @ViewBuilder
    private func modeButton(_ item: ModeItem) -> some View {
        let ui = CrateUI.shared
        switch item {
        case .mode(let m):
            DeckButton(label: m.label, on: state.mode == m,
                       id: "mode-" + m.label.lowercased().replacingOccurrences(of: " ", with: "")) {
                ui.setMode(m, state)
            }
        case .shift:
            DeckButton(label: "SHIFT", on: ui.shift, toggle: true, id: "mode-shift") { ui.shift.toggle() }
        case .octDown:
            DeckButton(label: "OCT −", id: "oct-down") { state.keysOctave = max(-3, state.keysOctave - 1) }
        case .octUp:
            DeckButton(label: "OCT +", id: "oct-up") { state.keysOctave = min(3, state.keysOctave + 1) }
        case .scale:
            DeckButton(label: "SCALE", on: state.scaleLock, toggle: true, id: "scale-lock") { state.scaleLock.toggle() }
        }
    }
}

/// PAD FX fallback for the hinge: PUNCH 0…1 → state.punch + engine.setPunch. Pull it from high to zero = DROP.
struct PunchFader: View {
    let state: AppState
    @State private var peak: Double = 0

    var body: some View {
        FaderView(value: state.punch, fill: true, id: "punch-fader", onChange: { v in
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
