import SwiftUI
import UIKit

/// Duo layout: lid display + deck, split at the fold (`.division` reserved region).
/// Laptop pose (horizontal fold) → lid above, deck below. Book pose (vertical fold) → lid left, deck right.
/// Flat → split along the longer axis. Compact width (outer display) → compact view.
///
/// Laptop pose on the Duo simulator: rotating the device can leave the interface in landscape
/// (the fold stays "vertical" in view coordinates) while the device is physically upright.
/// We detect that mismatch and lay out lid-over-deck ourselves, counter-rotated to stay upright.
struct RootView: View {
    @Bindable var state: AppState
    let hinge: HingeFX
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var deviceOrientation = UIDevice.current.orientation
    /// Debug override: -crateTurn 90 / -90 / 0 (also `crate://rot?deg=`), 999 = automatic.
    @AppStorage("crateTurn") private var turnOverride: Double = 999

    var body: some View {
        GeometryReader { proxy in
            let division = proxy.reservedRegions(kind: .division).map(\.frame).first
            let size = proxy.size
            let turn = counterRotation(size: size)
            ZStack {
                Color.black
                if turn != 0 {
                    // Physically upright device, landscape interface: build the portrait (laptop) layout and rotate it.
                    let portrait = CGSize(width: size.height, height: size.width)
                    laptop(size: portrait, fold: rotatedFold(division, size: size, turn: turn))
                        .frame(width: portrait.width, height: portrait.height)
                        .rotationEffect(.degrees(turn))
                        .frame(width: size.width, height: size.height)
                } else if let fold = division, fold.width > 0 || fold.height > 0 {
                    if fold.width >= fold.height {
                        laptop(size: size, fold: (fold.minY, fold.height))
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
                if AppConfig.debugLog {
                    Text(debugLine(division: division, size: size, turn: turn))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.gray)
                        .padding(4)
                }
            }
            .onChange(of: turn) { _, t in DebugLog.event("layout_turn", ["turn": t, "w": size.width, "h": size.height]) }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            deviceOrientation = UIDevice.current.orientation
            DebugLog.event("device_orientation", ["raw": deviceOrientation.rawValue])
        }
        .sceneAccessory {
            CameraCaptureAccessory(isEnabled: $state.crowdDisplayOn) {
                OuterCrowdHost(state: state)
            }
            .onAvailabilityChange { available in
                state.outerDisplayAvailable = available
                DebugLog.event("outer_display", ["kind": "camera", "available": available])
            }
            ExternalNonInteractiveAccessory(isEnabled: $state.crowdDisplayOn) {
                OuterCrowdHost(state: state)
            }
            .onAvailabilityChange { available in
                DebugLog.event("outer_display", ["kind": "external", "available": available])
            }
        }
        .onHingeChange { _, context in
            if let h = context.hinge {
                DebugLog.event("hinge", ["deg": (h.angle.degrees * 10).rounded() / 10, "status": "\(h.status)"])
                hinge.update(angle: h.angle.degrees)
            } else {
                state.hingeAngle = nil
            }
        }
    }

    /// Lid over deck with the fold gap between them.
    private func laptop(size: CGSize, fold: (y: CGFloat, height: CGFloat)?) -> some View {
        let y = fold?.y ?? (size.height / 2 - 6)
        let h = fold?.height ?? 12
        return VStack(spacing: 0) {
            lid.frame(height: max(0, y))
            Color.black.frame(height: h)
            deck.frame(maxHeight: .infinity)
        }
    }

    /// A vertical fold at x in landscape view space becomes a horizontal fold in the rotated portrait layout.
    private func rotatedFold(_ fold: CGRect?, size: CGSize, turn: Double) -> (y: CGFloat, height: CGFloat)? {
        guard let f = fold, f.width > 0 else { return nil }
        // turn -90: content top ↔ view left; turn +90: content top ↔ view right.
        return turn < 0 ? (f.minX, f.width) : (size.width - f.maxX, f.width)
    }

    /// Degrees to rotate the portrait layout so it stays upright, or 0 when the system already matches.
    private func counterRotation(size: CGSize) -> Double {
        if turnOverride != 999 { return turnOverride }
        guard size.width > size.height,
              deviceOrientation == .portrait || deviceOrientation == .portraitUpsideDown else { return 0 }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let iface = scene?.effectiveGeometry.interfaceOrientation ?? .landscapeRight
        let base: Double = (iface == .landscapeLeft) ? 90 : -90
        return deviceOrientation == .portrait ? base : -base
    }

    private var lid: some View { LidDisplayView(state: state) }
    private var deck: some View { DeckView(state: state) }
    private var compact: some View { CompactView(state: state) }

    private func debugLine(division: CGRect?, size: CGSize, turn: Double) -> String {
        let d = division.map { "div \(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))x\(Int($0.height))" } ?? "div none"
        let h = state.hingeAngle.map { "hinge \(Int($0))°" } ?? "hinge nil"
        return "\(Int(size.width))x\(Int(size.height)) · \(d) · \(h) · dev \(deviceOrientation.rawValue) · turn \(Int(turn))"
    }
}

/// Content for the Duo's outer (audience-facing) screen while the inner screen is in use.
struct OuterCrowdHost: View {
    let state: AppState
    var body: some View {
        CrowdStageView(state: state)
            .ignoresSafeArea()
            .onAppear { DebugLog.event("outer_display_content", ["appeared": true]) }
    }
}
