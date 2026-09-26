import Foundation

/// URL commands for the self-test harness: `xcrun simctl openurl <udid> "crate://dig?q=..."`.
/// crate://dig?q=  crate://mode?m=keys  crate://bank?b=B  crate://pad?i=3[&b=A][&semi=5]
/// crate://play  crate://stop  crate://perform?on=1  crate://flip  crate://punch?p=0.7
enum Router {
    static func handle(_ url: URL, state: AppState, hinge: HingeFX) {
        guard url.scheme == "crate" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String? { items.first { $0.name == name }?.value }
        DebugLog.event("url", ["cmd": url.host ?? "", "q": url.query ?? ""])
        switch url.host {
        case "dig":
            if let text = q("q") { state.dig(text) }
        case "mode":
            if let m = q("m"), let mode = Mode.allCases.first(where: { $0.rawValue.lowercased() == m.lowercased() || $0.label.lowercased().replacingOccurrences(of: " ", with: "") == m.lowercased() }) {
                state.mode = mode
            }
        case "bank":
            if let b = q("b"), let bank = Bank.allCases.first(where: { $0.letter == b.uppercased() }) { state.bank = bank }
        case "pad":
            let bank = q("b").flatMap { b in Bank.allCases.first { $0.letter == b.uppercased() } } ?? state.bank
            if let i = q("i").flatMap(Int.init) {
                let pad = PadID(bank, max(0, min(15, i - 1)))
                state.selectedPad = pad
                state.hit(pad, velocity: q("v").flatMap(Int.init) ?? 110, semitones: q("semi").flatMap(Double.init) ?? 0)
            }
        case "play":
            if !state.engine.isPlaying { state.togglePlay() }
        case "stop":
            if state.engine.isPlaying { state.togglePlay() }
        case "perform":
            let on = q("on") != "0"
            state.performOn = on
            state.onPerformToggle?(on)
        case "flip":
            state.onFlip?()
        case "punch":
            if let p = q("p").flatMap(Double.init) { hinge.apply(p) }
        case "cam":
            CrowdCam.shared.start()
        case "rec":
            state.setRecording(q("on") != "0")
        default:
            break
        }
    }
}
