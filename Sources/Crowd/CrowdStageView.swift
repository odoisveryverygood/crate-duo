import SwiftUI

/// Audience-facing content for the Duo's outer display. The host owns the accessory scene.
struct CrowdStageView: View {
    let state: AppState
    var rotate: Angle = .zero

    @State private var lastHighPunch = Date.distantPast
    @State private var dropFlashUntil = Date.distantPast

    var body: some View {
        GeometryReader { geometry in
            let landscape = geometry.size.width > geometry.size.height
            let size = landscape
                ? CGSize(width: geometry.size.height, height: geometry.size.width)
                : geometry.size

            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                stage(size: size, now: timeline.date)
                    .frame(width: size.width, height: size.height)
                    .rotationEffect((landscape ? Angle.degrees(90) : .zero) + rotate)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
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
        let inset = max(20, size.width * 0.055)
        let active = activePads(now: now)
        let level = min(1, max(0, Double(state.engine.level())))

        return ZStack {
            Color.black
            VStack(alignment: .leading, spacing: max(12, size.height * 0.025)) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CRATE").font(Theme.doto(min(55, size.width * 0.13)))
                        .foregroundStyle(Theme.orange)
                    Spacer()
                    Text("CR-16  /  LIVE").font(Theme.label(max(11, size.width * 0.025)))
                        .foregroundStyle(Theme.mid)
                }

                NowPlayingCard(state: state)
                    .frame(height: min(size.width + 80, size.height * 0.52))

                Text("\(state.styleLabel.uppercased())  ×  \(state.sampleLabel.uppercased())")
                    .font(Theme.label(max(15, size.width * 0.039)))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("crowd-style-sample")

                VStack(spacing: max(5, size.width * 0.015)) {
                    ForEach(0..<4, id: \.self) { row in
                        HStack(spacing: max(5, size.width * 0.015)) {
                            ForEach(0..<4, id: \.self) { column in
                                let index = (3 - row) * 4 + column
                                Circle()
                                    .fill(active.contains(index) ? Theme.orange : Theme.dotOff)
                                    .overlay(Circle().stroke(active.contains(index) ? Theme.text.opacity(0.7) : Theme.dim, lineWidth: 1))
                            }
                        }
                    }
                }
                .frame(height: min(92, size.height * 0.13))
                .accessibilityIdentifier("crowd-hit-matrix")

                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.dim)
                        Rectangle().fill(Theme.orange).frame(width: bar.size.width * level)
                    }
                }
                .frame(height: max(5, size.height * 0.009))
                .accessibilityIdentifier("crowd-level")

                Text(state.lastPerform.isEmpty ? "PERFORM  ▸  READY" : "PERFORM  ▸  \(state.lastPerform.uppercased())")
                    .font(Theme.label(max(11, size.width * 0.028)))
                    .foregroundStyle(Theme.ochre)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier("crowd-perform")
            }
            .padding(inset)
            .frame(width: size.width, height: size.height, alignment: .topLeading)

            if now < dropFlashUntil {
                Theme.orange.opacity(0.93)
                Text("DROP")
                    .font(Theme.doto(min(size.width * 0.32, 170)))
                    .foregroundStyle(Color.black)
                    .minimumScaleFactor(0.5)
                    .accessibilityIdentifier("crowd-drop")
            }
        }
    }

    private func activePads(now: Date) -> Set<Int> {
        var indices = Set<Int>()
        if let pad = state.lastHitPad, now.timeIntervalSince(state.lastHitTime) < 0.16 {
            indices.insert(pad.index)
        }
        guard state.engine.isPlaying else { return indices }
        let pattern = state.engine.pattern
        let total = max(1, pattern.totalSteps)
        let position = state.engine.position()
        guard position.isFinite else { return indices }
        let step = ((Int(floor(position)) % total) + total) % total
        let phase = position - floor(position)
        if phase < 0.28 {
            for (pad, hits) in pattern.lanes where hits.contains(where: { $0.step == step }) {
                indices.insert(pad.index)
            }
            for (pad, notes) in pattern.notes where notes.contains(where: { $0.step == step }) {
                indices.insert(pad.index)
            }
        }
        return indices
    }
}

#Preview("Crowd · portrait") {
    CrowdStageView(state: AppState(engine: MockEngine()))
        .frame(width: 466, height: 678)
}

#Preview("Crowd · rotated") {
    CrowdStageView(state: AppState(engine: MockEngine()))
        .frame(width: 678, height: 466)
}
