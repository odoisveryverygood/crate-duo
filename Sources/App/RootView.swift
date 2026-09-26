import SwiftUI

/// Duo layout: lid display + deck, split at the fold (`.division` reserved region).
/// Laptop pose (horizontal fold) → lid above, deck below. Book pose (vertical fold) → lid left, deck right.
/// Flat → split along the longer axis. Compact width (outer display) → compact view.
struct RootView: View {
    @Bindable var state: AppState
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.reservedRegions(kind: .division).map(\.frame).first
            let size = proxy.size
            ZStack {
                Color.black
                if let fold = division, fold.width > 0 || fold.height > 0 {
                    // Fold is horizontal when it spans the width.
                    if fold.width >= fold.height {
                        VStack(spacing: 0) {
                            lid.frame(height: fold.minY)
                            Color.black.frame(height: fold.height)
                            deck.frame(maxHeight: .infinity)
                        }
                    } else {
                        HStack(spacing: 0) {
                            lid.frame(width: fold.minX)
                            Color.black.frame(width: fold.width)
                            deck.frame(maxWidth: .infinity)
                        }
                    }
                } else if hSize == .compact && size.width < 520 {
                    compact
                } else if size.height >= size.width {
                    VStack(spacing: 6) { lid; deck }
                } else {
                    HStack(spacing: 6) { lid; deck }
                }
            }
            .overlay(alignment: .topTrailing) {
                Text(debugLine(division: division, size: size))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(4)
            }
        }
        .ignoresSafeArea()
        .onHingeChange { _, context in
            if let hinge = context.hinge {
                state.hingeAngle = hinge.angle.degrees
            } else {
                state.hingeAngle = nil
            }
        }
    }

    private var lid: some View {
        ZStack { Color.black; Text("LID").foregroundStyle(.white) }
    }
    private var deck: some View {
        ZStack { Color(white: 0.79); Text("DECK").foregroundStyle(.black) }
    }
    private var compact: some View {
        ZStack { Color(white: 0.2); Text("COMPACT").foregroundStyle(.white) }
    }

    private func debugLine(division: CGRect?, size: CGSize) -> String {
        let d = division.map { "div \(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "div none"
        let h = state.hingeAngle.map { "hinge \(Int($0))°" } ?? "hinge nil"
        return "\(Int(size.width))x\(Int(size.height)) · \(d) · \(h)"
    }
}
