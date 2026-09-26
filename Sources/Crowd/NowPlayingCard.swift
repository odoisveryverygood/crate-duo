import SwiftUI

/// Reusable closed-pose card. CrowdStage composes the same cover/details in a wider layout.
struct NowPlayingCard: View {
    let state: AppState

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let cover = max(0, min(size.width, size.height - 116))
            VStack(alignment: .leading, spacing: 16) {
                NowPlayingCover(state: state)
                    .frame(width: cover, height: cover)
                    .frame(maxWidth: .infinity)
                NowPlayingDetails(state: state, titleSize: min(42, size.width * 0.1))
                NowPlayingProgress(state: state)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }
}

struct NowPlayingDetails: View {
    let state: AppState
    var titleSize: CGFloat = 42

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(OuterField.type(titleSize, weight: 300))
                .tracking(-titleSize * 0.04)
                .foregroundStyle(OuterField.white)
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .accessibilityIdentifier("now-playing-title")
            Text("CRATE · \(artist)")
                .font(OuterField.type(11, weight: 500))
                .tracking(1.1)
                .foregroundStyle(OuterField.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("crowd-style-sample")
        }
    }

    private var title: String {
        // Core has no arrangement-title field. Preserve the existing sample/style fallback.
        let sample = state.sampleLabel.split(separator: "·", maxSplits: 1).first
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""
        return (sample.isEmpty ? (state.styleLabel.isEmpty ? "CRATE" : state.styleLabel) : sample).uppercased()
    }

    private var artist: String {
        [state.styleLabel, state.sampleLabel].filter { !$0.isEmpty }.joined(separator: " × ").uppercased()
    }
}

struct NowPlayingProgress: View {
    let state: AppState
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { _ in
            let frame = LiveFrame(state)
            OuterLevelLine(level: frame.playing ? frame.local / Double(frame.total) : 0,
                           color: OuterField.white)
        }
        .frame(height: 2)
        .accessibilityLabel("Loop progress")
    }
}

/// Seeded kit artwork: a white keypad with small bank tabs, matching direction 05.
struct NowPlayingCover: View {
    let state: AppState

    var body: some View {
        let seed = kitSeed
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let frame = LiveFrame(state)
            Canvas { context, size in
                let side = min(size.width, size.height)
                let inset = side * 0.065
                let gap = side * 0.014
                let cell = max(0, (side - inset * 2 - gap * 3) / 4)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OuterField.aluminium))
                for index in 0..<16 {
                    let rect = CGRect(x: inset + CGFloat(index % 4) * (cell + gap),
                                      y: inset + CGFloat(index / 4) * (cell + gap), width: cell, height: cell)
                    let value = mixed(seed, index)
                    let bank = Bank(rawValue: Int(value % 4)) ?? .a
                    let pad = PadID(bank, (3 - index / 4) * 4 + index % 4)
                    let live = state.lastHitPad == pad && timeline.date.timeIntervalSince(state.lastHitTime) < Theme.flash
                    let lit = live || frame.sequencerFlash(pad)
                    context.fill(Path(roundedRect: rect, cornerRadius: side * 0.012),
                                 with: .color(lit ? OuterField.keyDown : OuterField.key))
                    // Static colour is only a small bank marker. The full edge appears on a live hit.
                    let tab = CGRect(x: rect.minX + cell * 0.15, y: rect.maxY - cell * 0.14,
                                     width: cell * 0.24, height: max(1, side * 0.006))
                    context.fill(Path(tab), with: .color(OuterField.bank(bank)))
                    let dot = cell * (value.isMultiple(of: 5) ? 0.5 : 0.22)
                    context.fill(Path(ellipseIn: CGRect(x: rect.midX - dot / 2, y: rect.midY - dot / 2,
                                                       width: dot, height: dot)), with: .color(OuterField.ink))
                    if lit {
                        context.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: cell, height: max(2, side * 0.008))),
                                     with: .color(Theme.orange))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityLabel("Cover artwork generated from the current kit")
    }

    private var kitSeed: UInt64 {
        let ids = state.sounds.sorted {
            $0.key.bank.rawValue == $1.key.bank.rawValue
                ? $0.key.index < $1.key.index : $0.key.bank.rawValue < $1.key.bank.rawValue
        }.map { $0.value.id }.joined(separator: "|")
        return ids.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    private func mixed(_ seed: UInt64, _ index: Int) -> UInt64 {
        var x = seed &+ UInt64(index + 1) &* 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        return x ^ (x >> 31)
    }
}

#Preview("Now Playing · Field") {
    NowPlayingCard(state: AppState(engine: MockEngine()))
        .frame(width: 426, height: 570).padding(20).background(Color.black)
}
