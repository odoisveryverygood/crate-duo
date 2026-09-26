import SwiftUI

/// TE-style chassis button: label bottom-left; "on" = silk fill + orange dot top-right.
struct DeckButton: View {
    let label: String
    var on = false
    /// Toggles (SHIFT, SCALE) stay light and show only the orange LED; modes invert to silk.
    var toggle = false
    var accent = false
    var id: String
    var action: () -> Void

    var body: some View {
        let dark = on && !toggle
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(dark ? Theme.silk : Theme.button)
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(dark ? Theme.silk : Theme.buttonBorder, lineWidth: 1)
                Text(label)
                    .crateLabel(8.5, tracking: 0.14)
                    .foregroundStyle(dark ? Theme.text : (accent ? Theme.orange : Theme.silk))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.leading, 6)
                    .padding(.bottom, 5)
                    .padding(.trailing, 4)
                if on {
                    Circle().fill(Theme.orange)
                        .frame(width: 6, height: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ChassisPressStyle())
        .accessibilityIdentifier(id)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Flat press feedback: a quick darken, no scale, no shadow.
struct ChassisPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.10 : 0))
                    .allowsHitTesting(false)
            )
            .animation(Theme.quick, value: configuration.isPressed)
    }
}

/// PAD BANK A–D, 2×2 with a colour tick.
struct BankGrid: View {
    let state: AppState
    var height: CGFloat = 30

    var body: some View {
        let cols = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(Bank.allCases, id: \.self) { b in
                BankButton(bank: b, selected: state.bank == b, height: height) {
                    CrateUI.shared.selectBank(b, state)
                }
            }
        }
    }
}

struct BankButton: View {
    let bank: Bank
    let selected: Bool
    var height: CGFloat = 30
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(selected ? Theme.silk : Theme.button)
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(selected ? Theme.silk : Theme.buttonBorder, lineWidth: 1)
                Text(bank.letter)
                    .font(Theme.label(12))
                    .foregroundStyle(selected ? Color.white : Theme.silk)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Rectangle().fill(Theme.bank(bank))
                    .frame(width: 14, height: 2)
                    .padding(.bottom, 3)
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChassisPressStyle())
        .accessibilityIdentifier("bank-\(bank.letter)")
        .accessibilityLabel("Bank \(bank.letter)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Vertical fader: track line, silk cap with an orange line. `fill` shows an orange level column (PUNCH).
struct FaderView: View {
    var value: Double
    var fill = false
    var id = "level-fader"
    var onChange: (Double) -> Void
    var onEnd: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { g in
            let inset: CGFloat = 12
            let capH: CGFloat = 16
            let travel = max(1, g.size.height - 2 * inset - capH)
            let v = min(1, max(0, value))
            let capY = inset + (1 - v) * travel
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.button)
                RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.buttonBorder, lineWidth: 1)
                Rectangle().fill(Theme.buttonBorder)
                    .frame(width: 2, height: max(0, g.size.height - 20))
                    .position(x: g.size.width / 2, y: g.size.height / 2)
                if fill {
                    let top = capY + capH / 2
                    let h = max(0, g.size.height - inset - top)
                    Rectangle().fill(Theme.orange)
                        .frame(width: 4, height: h)
                        .position(x: g.size.width / 2, y: top + h / 2)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: 2).fill(Theme.silk)
                    Rectangle().fill(Theme.orange).frame(height: 2).padding(.horizontal, 4)
                }
                .frame(width: g.size.width * 0.64, height: capH)
                .position(x: g.size.width / 2, y: capY + capH / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { d in
                        let y = d.location.y - inset - capH / 2
                        onChange(Double(min(1, max(0, 1 - y / travel))))
                    }
                    .onEnded { d in
                        let y = d.location.y - inset - capH / 2
                        onEnd?(Double(min(1, max(0, 1 - y / travel))))
                    }
            )
        }
        .accessibilityElement()
        .accessibilityIdentifier(id)
        .accessibilityValue("\(Int((min(1, max(0, value))) * 100)) percent")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: onChange(min(1, value + 0.1))
            case .decrement: onChange(max(0, value - 0.1))
            @unknown default: break
            }
        }
    }
}

/// ● REC  ▶ PLAY  ■ STOP. Polls the engine so it stays right even if playback is started elsewhere.
struct TransportRow: View {
    let state: AppState
    var height: CGFloat = 34

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            let playing = state.engine.isPlaying || state.isPlaying
            HStack(spacing: 6) {
                transportButton(id: "rec", on: state.isRecording, onFill: Theme.orange) {
                    Circle().fill(state.isRecording ? Color.white : Theme.orange).frame(width: 9, height: 9)
                } action: {
                    state.setRecording(!state.isRecording)
                }
                transportButton(id: "play", on: playing, onFill: Theme.silk) {
                    PlayShape().fill(Theme.orange).frame(width: 9, height: 10)
                } action: {
                    if !state.engine.isPlaying { state.togglePlay() } else { state.isPlaying = true }
                }
                transportButton(id: "stop", on: false, onFill: Theme.silk) {
                    Rectangle().fill(Theme.silk).frame(width: 9, height: 9)
                } action: {
                    if state.engine.isPlaying { state.togglePlay() } else { state.isPlaying = false }
                    if state.isRecording { state.setRecording(false) }
                }
            }
        }
    }

    private func transportButton<G: View>(id: String, on: Bool, onFill: Color,
                                          @ViewBuilder glyph: () -> G,
                                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius).fill(on ? onFill : Theme.button)
                RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(on ? onFill : Theme.buttonBorder, lineWidth: 1)
                glyph()
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChassisPressStyle())
        .accessibilityIdentifier(id)
        .accessibilityLabel(id.uppercased())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The orange ✦ DIG key.
struct DigButton: View {
    let state: AppState
    var height: CGFloat = 40

    var body: some View {
        Button {
            CrateUI.shared.digPressed(state)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.orange)
                HStack(spacing: 7) {
                    SparkShape().fill(Color.white).frame(width: 9, height: 9)
                    Text("DIG").crateLabel(10, tracking: 0.16).foregroundStyle(Color.white)
                }
                if state.isDigging {
                    DotSpinner(color: .white, dot: 2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(ChassisPressStyle())
        .accessibilityIdentifier("dig-button")
        .accessibilityLabel("Dig")
    }
}

/// Dot-matrix 3-dot spinner (each dot is a 3×3 matrix; one lights at a time).
struct DotSpinner: View {
    var color: Color = Theme.orange
    var dot: CGFloat = 2.5

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { ctx in
            let k = Int(ctx.date.timeIntervalSinceReferenceDate / 0.12) % 3
            HStack(spacing: dot * 2) {
                ForEach(0..<3, id: \.self) { i in
                    matrix(lit: i == k)
                }
            }
        }
        .accessibilityIdentifier("digging")
        .accessibilityLabel("Digging")
    }

    private func matrix(lit: Bool) -> some View {
        VStack(spacing: dot * 0.6) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: dot * 0.6) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle().fill(lit ? color : color.opacity(0.22)).frame(width: dot, height: dot)
                    }
                }
            }
        }
    }
}

struct BrandLine: View {
    var body: some View {
        Text("CRATE CR-16 · AI SAMPLER FOR IPHONE DUO")
            .crateLabel(8, tracking: 0.24)
            .foregroundStyle(Theme.mid)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
