import Foundation

/// Maps the hinge angle to the punch-in FX amount; snapping the hinge open fires the DROP.
/// Laptop/book rest angle ≈ 110°+ → no FX. Folding toward 25° ramps filter/crush/reverb up to a breakdown.
final class HingeFX {
    private let state: AppState
    var restAngle: Double = 110
    var closedAngle: Double = 25
    private var recent: [(t: Date, p: Double)] = []
    private var lastDrop = Date.distantPast

    init(state: AppState) { self.state = state }

    func update(angle: Double) {
        state.hingeAngle = angle
        let p = min(1, max(0, (restAngle - angle) / (restAngle - closedAngle)))
        apply(p)
    }

    /// Also used by the PAD FX slider fallback on non-hinge devices.
    func apply(_ p: Double) {
        let now = Date()
        recent.append((now, p))
        recent.removeAll { now.timeIntervalSince($0.t) > 0.45 }
        let peak = recent.map(\.p).max() ?? 0
        if p < 0.1, peak > 0.6, now.timeIntervalSince(lastDrop) > 1.0 {
            lastDrop = now
            state.punch = 0
            state.engine.drop()
            state.addLog("DROP", "snap open", tint: .orange)
            DebugLog.event("drop", ["from": peak])
            recent.removeAll()
            return
        }
        guard abs(p - state.punch) > 0.005 || p == 0 || p == 1 else { return }
        state.punch = p
        state.engine.setPunch(p)
    }
}
