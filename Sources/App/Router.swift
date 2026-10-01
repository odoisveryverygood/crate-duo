import Foundation
import UIKit

/// URL commands for the self-test harness: `xcrun simctl openurl <udid> "crate://dig?q=..."`.
/// crate://dig?q=  crate://mode?m=keys  crate://bank?b=B  crate://pad?i=3[&b=A][&semi=5]
/// crate://play  crate://stop  crate://perform?on=1  crate://flip  crate://punch?p=0.7
/// crate://fx?t=lpf  crate://fxamt?v=0.7  crate://latch?on=0  crate://import?path=/abs/song.wav  crate://orient?o=landscape
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
        case "padstyle":
            if let value = q("s") { PadStyle.set(value) }
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
        case "fx":
            // crate://fx?t=lpf | repeat | half | punch … (FXType raw value or label; punch/none = default chain)
            if let t = q("t"), let parsed = FXType.parse(t) { state.selectFX(parsed) }
        case "fxamt":
            // crate://fxamt?v=0.7 — same path as the hinge / knob (DROP detection included)
            if let v = q("v").flatMap(Double.init) { hinge.apply(min(1, max(0, v))) }
        case "latch":
            state.fxLatched = q("on") != "0"
        case "cam":
            CrowdCam.shared.start()
        case "rot":
            UserDefaults.standard.set(Double(q("deg") ?? "999") ?? 999, forKey: "crateTurn")
        case "crowdrot":
            UserDefaults.standard.set(Double(q("deg") ?? "0") ?? 0, forKey: "crateCrowdTurn")
        case "import":
            // crate://import?path=/abs/file.wav — same copy → chop → auto-flip path as a Files drag-in
            if let path = q("path") { Task { @MainActor in await AudioImport.importPath(path, state: state) } }
        case "project":
            // crate://project?cmd=new|save|saveas|open&name=…
            let cmd = q("cmd") ?? "save", name = q("name")
            Task { @MainActor in await ProjectStore.shared.handle(cmd: cmd, name: name, state: state) }
        case "undo":
            Task { @MainActor in await Orchestrator.current?.undo() }
        case "redo":
            Task { @MainActor in await Orchestrator.current?.redo() }
        case "bpm":
            if let v = q("v").flatMap(Double.init) { Task { @MainActor in Orchestrator.current?.setTempo(v) } }
        case "bars":
            if let n = q("n").flatMap(Int.init) { Task { @MainActor in Orchestrator.current?.setBars(n) } }
        case "slice":
            // crate://slice?b=B&i=5&t=1.23 — same as dragging the line before slice i (1-based) on the CHOP waveform
            if let i = q("i").flatMap(Int.init), let t = q("t").flatMap(Double.init) {
                let bank = q("b").flatMap { b in Bank.allCases.first { $0.letter == b.uppercased() } } ?? .b
                Task { @MainActor in Orchestrator.current?.moveSliceBoundary(bank: bank, index: i - 1, to: t) }
            }
        case "rec":
            state.setRecording(q("on") != "0")
        // Sampling (redesign): crate://arm?on=1  crate://editor?open=1  crate://swap?dir=1  crate://trim?s=0.1&e=0.5
        // crate://recpress  crate://fxhold?on=1  crate://fxpick?i=15  crate://take?pad=A3&path=…
        case "arm":
            Task { @MainActor in
                if (q("on") != "0") != CrateUI.shared.sampleArmed { CrateUI.shared.toggleSample(state) }
            }
        case "editor":
            CrateUI.shared.editorOpen = q("open") != "0"
        case "swap":
            let step = Int(q("dir") ?? "1") ?? 1
            Task { @MainActor in await Orchestrator.current?.swapSound(state.selectedPad, step: step) }
        case "trim":
            let s = q("s").flatMap(Double.init), e = q("e").flatMap(Double.init)
            Task { @MainActor in await Orchestrator.current?.trimPad(state.selectedPad, start: s, end: e) }
        case "recpress":
            Task { @MainActor in CrateUI.shared.recPressed(state) }
        case "fxhold":
            Task { @MainActor in if q("on") != "0" { CrateUI.shared.fxDown() } else { CrateUI.shared.fxHeld = false } }
        case "fxpick":
            if let i = q("i").flatMap(Int.init), (1...16).contains(i) {
                Task { @MainActor in CrateUI.shared.pickFX(i - 1, state) }
            }
        case "take":
            // crate://take?pad=A3&path=/abs/take.wav — a finished SAMPLE take on that pad (sim mics can't record unattended)
            if let path = q("path"), let p = q("pad"), p.count >= 2,
               let bank = Bank.allCases.first(where: { $0.letter == p.prefix(1).uppercased() }),
               let n = Int(p.dropFirst()), (1...16).contains(n), let sampler = CrateUI.shared.sampler {
                Task { @MainActor in
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let dir = docs.appendingPathComponent("samples", isDirectory: true)
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let url = dir.appendingPathComponent("rec-test-\(UUID().uuidString.prefix(8)).wav")
                    do { try FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: url) } catch {
                        DebugLog.event("error", ["where": "take", "msg": error.localizedDescription]); return
                    }
                    if await sampler.placeTake(url, on: PadID(bank, n - 1)) { CrateUI.shared.editorOpen = true }
                }
            }
        case "orient":
            // crate://orient?o=portrait|landscape — rotate the interface (simulator layout checks)
            let mask: UIInterfaceOrientationMask = q("o") == "landscape" ? .landscapeRight : .portrait
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            scene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                DebugLog.event("error", ["where": "orient", "msg": error.localizedDescription])
            }
        default:
            break
        }
    }
}
