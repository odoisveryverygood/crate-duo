import SwiftUI
import UIKit

/// Duo layout: lid display + deck, split at the fold (`.division` reserved region).
/// Laptop pose (horizontal fold) → lid above, deck below. Book pose (vertical fold) → lid left, deck right.
/// Flat → split along the longer axis. Compact width (outer display) → compact view.
/// iPhone → compact lid over the deck (side by side in landscape). iPad → the flat split with a hairline.
///
/// Laptop pose on the Duo simulator: rotating the device can leave the interface in landscape
/// (the fold stays "vertical" in view coordinates) while the device is physically upright.
/// We detect that mismatch and lay out lid-over-deck ourselves, counter-rotated to stay upright.
struct RootView: View {
    @Bindable var state: AppState
    let hinge: HingeFX
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    @State private var deviceOrientation = UIDevice.current.orientation
    /// Debug override: -crateTurn 90 / -90 / 0 (also `crate://rot?deg=`), 999 = automatic.
    @AppStorage("crateTurn") private var turnOverride: Double = 999
    /// Rotation in use when the hinge FX started: folding the hinge for FX must never spin the layout.
    @State private var lockedTurn: Double?

    var body: some View {
        GeometryReader { proxy in
            let fold = proxy.crateFold
            let division = fold.active
            let anyFold = fold.any
            let size = proxy.size
            // A fold means the Duo's inner screen; a hinge seen before means Duo (the outer screen has no fold).
            let duo = CrateUI.shared.isDuo || anyFold != nil
            // Apple: branch on size classes, not orientation. Outer display = compact in either orientation;
            // the inner display is regular/regular in every pose.
            let outer = duo && (hSize == .compact || vSize == .compact)
            let liveTurn = (outer || !duo) ? 0 : counterRotation(size: size)
            let turn = (state.punch > 0.04 ? lockedTurn : nil) ?? liveTurn
            ZStack {
                Color.black
                if !duo {
                    flat(size: size, insets: DeviceInfo.windowEdgeInsets)
                } else if outer {
                    compact
                } else if turn != 0 {
                    // Physically upright device, landscape interface: build the portrait (laptop) layout and rotate it.
                    let portrait = CGSize(width: size.height, height: size.width)
                    laptop(size: portrait, fold: rotatedFold(division ?? anyFold, size: size, turn: turn))
                        .frame(width: portrait.width, height: portrait.height)
                        .rotationEffect(.degrees(turn))
                        .frame(width: size.width, height: size.height)
                } else if let fold = division, fold.width > 0 || fold.height > 0 {
                    // Folded: book (vertical fold) or laptop/tent (horizontal fold) — split exactly at the fold.
                    if fold.width >= fold.height {
                        laptop(size: size, fold: (fold.minY, fold.height))
                    } else {
                        book(fold: (fold.minX, fold.width))
                    }
                } else if size.height > size.width {
                    // Flat, held upright: lid over deck, split where the fold would be.
                    laptop(size: size, fold: anyFold.map { ($0.midY - 6, 12) })
                } else {
                    // Flat, held wide: lid beside deck, split where the fold would be.
                    book(fold: anyFold.map { ($0.midX - 6, 12) } ?? (size.width / 2 - 6, 12))
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
            .onChange(of: anyFold != nil, initial: true) { _, has in if has { CrateUI.shared.markDuo() } }
            .onChange(of: size, initial: true) { _, sz in
                let w = DeviceInfo.windowInsets
                DebugLog.event("layout", ["w": sz.width, "h": sz.height, "duo": duo, "insets": [w.top, w.bottom, w.left, w.right]])
            }
            .onChange(of: turn) { _, t in DebugLog.event("layout_turn", ["turn": t, "w": size.width, "h": size.height]) }
            .onAppear { lockedTurn = liveTurn }
            .onChange(of: liveTurn) { _, t in if state.punch <= 0.04 { lockedTurn = t } }
            .onChange(of: state.punch) { _, p in if p <= 0.04 { lockedTurn = liveTurn } }
        }
        .background(KeyboardControl(state: state).frame(width: 0, height: 0))
        .background {
            // ⌘Z = UNDO (same as the chip)
            Button { Task { @MainActor in await Orchestrator.current?.undo() } } label: { EmptyView() }
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityHidden(true)
            // ⇧⌘Z = REDO
            Button { Task { @MainActor in await Orchestrator.current?.redo() } } label: { EmptyView() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear { UIDevice.current.beginGeneratingDeviceOrientationNotifications() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            // Moving the hinge makes iOS report faceUp / unknown for a moment; keep the last real orientation.
            let o = UIDevice.current.orientation
            guard o.isPortrait || o.isLandscape else { return }
            deviceOrientation = o
            DebugLog.event("device_orientation", ["raw": deviceOrientation.rawValue])
        }
        .modifier(DuoSceneHooks(state: state, hinge: hinge))
    }

    /// Lid over deck with the fold gap between them. `deckBottom` keeps the deck's keys above the home indicator.
    private func laptop(size: CGSize, fold: (y: CGFloat, height: CGFloat)?, deckBottom: CGFloat = 0) -> some View {
        let y = fold?.y ?? (size.height / 2 - 6)
        let h = fold?.height ?? 12
        return VStack(spacing: 0) {
            lid.frame(height: max(0, y))
            Color.black.frame(height: h)
            deck.padding(.bottom, deckBottom).background(Deck05.alu).frame(maxHeight: .infinity)
        }
    }

    /// Lid beside deck with the fold gap between them.
    private func book(fold: (x: CGFloat, width: CGFloat), deckBottom: CGFloat = 0) -> some View {
        HStack(spacing: 0) {
            lid.frame(width: max(0, fold.x))
            Color.black.frame(width: fold.width)
            deck.padding(.bottom, deckBottom).background(Deck05.alu).frame(maxWidth: .infinity)
        }
    }

    // MARK: iPhone / iPad (no fold, no hinge)

    /// iPad at regular width keeps the Duo's flat split (lid over deck when tall, side by side when wide) with a
    /// hairline instead of the hinge gap. A phone, or a narrow iPad window, gets the compact phone layout.
    @ViewBuilder
    private func flat(size: CGSize, insets: EdgeInsets) -> some View {
        if DeviceInfo.isPad && hSize == .regular {
            if size.height > size.width {
                laptop(size: size, fold: ((size.height - insets.bottom) / 2, 1), deckBottom: insets.bottom)
            } else {
                book(fold: (size.width / 2, 1), deckBottom: insets.bottom)
            }
        } else if size.width > size.height * 1.15 {
            phoneSide(size: size, insets: insets)
        } else {
            phoneStack(size: size, insets: insets)
        }
    }

    /// Phone portrait: the compact lid (about 40 %) over the deck; clear of the Dynamic Island and home indicator.
    private func phoneStack(size: CGSize, insets: EdgeInsets) -> some View {
        let usable = max(0, size.height - insets.top - insets.bottom)
        let lidH = (usable * 0.4).rounded()
        return VStack(spacing: 0) {
            PhoneLidView(state: state)
                .frame(height: lidH)
                .padding(.top, insets.top)
            DeckView(state: state, phone: true)
                .padding(.bottom, insets.bottom)
                .background(Deck05.alu)
        }
        .padding(.horizontal, max(insets.leading, insets.trailing))
    }

    /// Phone landscape: compact lid left, deck right.
    private func phoneSide(size: CGSize, insets: EdgeInsets) -> some View {
        let usable = max(0, size.width - insets.leading - insets.trailing)
        return HStack(spacing: 0) {
            PhoneLidView(state: state)
                .padding(.bottom, insets.bottom)
                .frame(width: (usable * 0.44).rounded())
                .padding(.leading, insets.leading)
            DeckView(state: state, phone: true)
                .padding(.bottom, insets.bottom)
                .padding(.trailing, insets.trailing)
                .background(Deck05.alu)
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
        let kind = CrateUI.shared.isDuo ? "duo" : (DeviceInfo.isPad ? "pad" : "phone")
        return "\(kind) · \(Int(size.width))x\(Int(size.height)) · \(d) · \(h) · dev \(deviceOrientation.rawValue) · turn \(Int(turn))"
    }
}

/// Duo-only scene hooks (iOS 27.1 SDK and OS): the back screen (camera accessory), an external display, and the hinge.
private struct DuoSceneHooks: ViewModifier {
    @Bindable var state: AppState
    let hinge: HingeFX

    func body(content: Content) -> some View {
        #if NO_DUO_SDK
        content
        #else
        if #available(iOS 27.1, *) {
            content
                .sceneAccessory {
                    CameraCaptureAccessory(isEnabled: $state.crowdDisplayOn) {
                        OuterCrowdHost(state: state)
                    }
                    .onAvailabilityChange { available in
                        state.outerDisplayAvailable = available
                        DebugLog.event("outer_display", ["kind": "camera", "available": available])
                    }
                    // Duo only for now: on an iPhone or iPad this would take over AirPlay / USB-C screens.
                    ExternalNonInteractiveAccessory(isEnabled: crowdOnExternal) {
                        OuterCrowdHost(state: state)
                    }
                    .onAvailabilityChange { available in
                        DebugLog.event("outer_display", ["kind": "external", "available": available])
                    }
                }
                .onHingeChange { _, context in
                    if let h = context.hinge {
                        CrateUI.shared.markDuo()
                        DebugLog.event("hinge", ["deg": (h.angle.degrees * 10).rounded() / 10, "status": "\(h.status)"])
                        if h.status == .closed { hinge.released() } else { hinge.update(angle: h.angle.degrees) }
                    } else {
                        state.hingeAngle = nil
                    }
                }
        } else {
            content
        }
        #endif
    }

    private var crowdOnExternal: Binding<Bool> {
        Binding(get: { state.crowdDisplayOn && CrateUI.shared.isDuo }, set: { state.crowdDisplayOn = $0 })
    }
}

/// Content for the Duo's outer (audience-facing) screen while the inner screen is in use.
struct OuterCrowdHost: View {
    let state: AppState
    /// The outer panel can present rotated relative to the accessory's layout; `-crateCrowdTurn 90` / `crate://crowdrot?deg=` fixes it live.
    @AppStorage("crateCrowdTurn") private var crowdTurn: Double = 0
    var body: some View {
        GeometryReader { g in
            let quarter = Int(crowdTurn) % 180 != 0
            let size = quarter ? CGSize(width: g.size.height, height: g.size.width) : g.size
            CrowdStageView(state: state)
                .frame(width: size.width, height: size.height)
                .rotationEffect(.degrees(crowdTurn))
                .frame(width: g.size.width, height: g.size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
            .onAppear { DebugLog.event("outer_display_content", ["appeared": true]) }
    }
}
