import SwiftUI

/// Audience-facing Field card. The host still owns the accessory scene and its orientation.
struct CrowdStageView: View {
    let state: AppState
    var rotate: Angle = .zero

    @State private var lastHighPunch = Date.distantPast
    @State private var dropFlashUntil = Date.distantPast

    var body: some View {
        GeometryReader { geometry in
            // Swap the layout bounds before a quarter turn so explicit rotation cannot crop the card.
            let quarterTurn = abs(sin(rotate.radians)) > 0.707
            let size = quarterTurn ? CGSize(width: geometry.size.height, height: geometry.size.width) : geometry.size
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                ZStack {
                    stage(size: size, now: timeline.date)
                    if timeline.date < dropFlashUntil {
                        Theme.orange
                        Text("DROP")
                            .font(OuterField.type(min(size.width, size.height) * 0.28, weight: 300))
                            .tracking(-4)
                            .foregroundStyle(OuterField.ink)
                            .accessibilityIdentifier("crowd-drop")
                    }
                }
                .frame(width: size.width, height: size.height)
                .rotationEffect(rotate)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .background(Color.black)
        .clipped()
        .onChange(of: state.punch) { old, new in
            if old > 0.6 { lastHighPunch = Date() }
            if new < 0.1, Date().timeIntervalSince(lastHighPunch) < 0.3 {
                dropFlashUntil = Date().addingTimeInterval(0.28)
                lastHighPunch = .distantPast
            }
        }
    }

    private func stage(size: CGSize, now: Date) -> some View {
        let wide = size.width > size.height * 1.15
        let inset = max(16, min(size.width, size.height) * 0.055)
        let frame = LiveFrame(state)
        return VStack(alignment: .leading, spacing: inset) {
            HStack {
                Text("CRATE").font(OuterField.type(14, weight: 600)).tracking(2.8)
                    .foregroundStyle(OuterField.white)
                Spacer()
                Circle().fill(frame.playing ? Theme.orange : OuterField.secondary).frame(width: 5, height: 5)
                Text(frame.playing ? "CR-16 / LIVE" : "CR-16 / READY")
                    .font(OuterField.type(9, weight: 500)).tracking(1.2)
                    .foregroundStyle(OuterField.secondary)
            }
            if wide {
                HStack(alignment: .center, spacing: inset * 1.3) {
                    NowPlayingCover(state: state)
                        .frame(width: min(size.height - inset * 3 - 18, size.width * 0.46))
                        .aspectRatio(1, contentMode: .fit)
                    details(now: now, frame: frame, titleSize: min(48, size.width * 0.065))
                }
                .frame(maxHeight: .infinity)
            } else {
                NowPlayingCover(state: state)
                    .frame(width: min(size.width - inset * 2, size.height * 0.43),
                           height: min(size.width - inset * 2, size.height * 0.43))
                    .frame(maxWidth: .infinity)
                details(now: now, frame: frame, titleSize: min(48, size.width * 0.105))
            }
        }
        .padding(inset)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func details(now: Date, frame: LiveFrame, titleSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NowPlayingDetails(state: state, titleSize: titleSize)
            NowPlayingProgress(state: state)
            HStack(alignment: .center, spacing: 24) {
                hitMatrix(now: now, frame: frame).frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text("BAR / \(frame.bars)").font(OuterField.type(8, weight: 600)).tracking(1.2)
                        .foregroundStyle(OuterField.secondary)
                    Text(frame.barBeat).font(OuterField.type(34, weight: 300)).monospacedDigit()
                        .foregroundStyle(OuterField.white)
                }
                Spacer(minLength: 0)
            }
            OuterLevelLine(level: Double(state.engine.level()))
                .frame(height: 2).accessibilityIdentifier("crowd-level")
                .accessibilityLabel("Output level")
            Text(state.lastPerform.isEmpty ? "PERFORM ▸ \(state.performOn ? "ON" : "READY")" : "PERFORM ▸ \(state.lastPerform.uppercased())")
                .font(OuterField.type(10, weight: 500)).tracking(1)
                .foregroundStyle(state.performOn ? OuterField.white : OuterField.secondary)
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityIdentifier("crowd-perform")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hitMatrix(now: Date, frame: LiveFrame) -> some View {
        let active = activePads(now: now, frame: frame)
        return VStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { column in
                        let index = (3 - row) * 4 + column
                        Circle().fill(active.contains(index) ? Theme.orange : OuterField.rule)
                    }
                }
            }
        }
        .accessibilityIdentifier("crowd-hit-matrix")
        .accessibilityLabel("Live pad activity")
    }

    private func activePads(now: Date, frame: LiveFrame) -> Set<Int> {
        var indices = Set<Int>()
        if let pad = state.lastHitPad, now.timeIntervalSince(state.lastHitTime) < 0.16 { indices.insert(pad.index) }
        // Shared sequencer timing includes swing and per-lane offsets, as on the deck.
        for pad in Set(frame.pattern.lanes.keys).union(frame.pattern.notes.keys) where frame.sequencerFlash(pad) {
            indices.insert(pad.index)
        }
        return indices
    }
}

#Preview("Crowd · portrait") {
    CrowdStageView(state: AppState(engine: MockEngine())).frame(width: 466, height: 678)
}
#Preview("Crowd · landscape") {
    CrowdStageView(state: AppState(engine: MockEngine())).frame(width: 678, height: 466)
}
#Preview("Crowd · explicit quarter turn") {
    CrowdStageView(state: AppState(engine: MockEngine()), rotate: .degrees(90)).frame(width: 678, height: 466)
}
