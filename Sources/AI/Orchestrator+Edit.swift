import Foundation

/// Undo history + direct edits (tempo, loop length, pad layout) that don't need a new beat.
/// Every DIG / flip / reorder / tempo / length change pushes a snapshot first; UNDO (chip, ⌘Z, "undo") pops one.
@MainActor
final class EditHistory {
    static let shared = EditHistory()

    struct Snapshot {
        var label: String
        var sounds: [PadID: PadSound]
        var pattern: Pattern
        var bpm: Double
        var swing: Double
        var bars: Int
        var scaleKey: String?
        var styleLabel: String
        var sampleLabel: String
        var chordsLabel: String
        var slots: [String]
        var session: Orchestrator.Session?
        var lastPattern: Pattern
    }

    private(set) var stack: [Snapshot] = []
    private(set) var redoStack: [Snapshot] = []
    /// Bumped on every push/pop so SwiftUI can re-read `canUndo` (the chip dims when empty).
    private(set) var version = 0
    var canUndo: Bool { !stack.isEmpty }

    /// A new change: goes on the undo stack and forgets anything redoable.
    func push(_ s: Snapshot, clearRedo: Bool = true) {
        stack.append(s)
        if stack.count > 30 { stack.removeFirst(stack.count - 30) }
        if clearRedo { redoStack.removeAll() }
        sync()
    }

    func pop() -> Snapshot? {
        let s = stack.popLast()
        sync()
        return s
    }

    func pushRedo(_ s: Snapshot) { redoStack.append(s); sync() }

    func popRedo() -> Snapshot? {
        let s = redoStack.popLast()
        sync()
        return s
    }

    func clear() {
        stack.removeAll()
        redoStack.removeAll()
        sync()
    }

    private func sync() {
        version += 1
        CrateUndoSignal.shared.canUndo = !stack.isEmpty
        CrateUndoSignal.shared.canRedo = !redoStack.isEmpty
    }
}

/// Observable mirror of "is there anything to undo" for the UNDO chip.
@Observable
final class CrateUndoSignal {
    static let shared = CrateUndoSignal()
    var canUndo = false
    var canRedo = false
}

extension Orchestrator {
    // MARK: Snapshots

    func snapshot(_ label: String) -> EditHistory.Snapshot {
        var sounds: [PadID: PadSound] = [:]
        for b in Bank.allCases { for i in 0..<16 { let p = PadID(b, i); if let s = state.sound(p) { sounds[p] = s } } }
        return .init(label: label, sounds: sounds, pattern: state.engine.pattern, bpm: state.bpm, swing: state.swing,
                     bars: state.bars, scaleKey: state.scaleKey, styleLabel: state.styleLabel,
                     sampleLabel: state.sampleLabel, chordsLabel: state.chordsLabel, slots: BankA.slots,
                     session: session, lastPattern: lastPattern)
    }

    /// Call before any change the user may want to take back.
    func checkpoint(_ label: String) {
        EditHistory.shared.push(snapshot(label))
    }

    func undo() async {
        guard let s = EditHistory.shared.pop() else {
            state.addLog("UNDO", "nothing to undo", tint: .grey)
            return
        }
        EditHistory.shared.pushRedo(snapshot(s.label))
        await restore(s)
        state.addLog("UNDO", s.label, tint: .orange)
        DebugLog.event("undo", ["label": s.label, "left": EditHistory.shared.stack.count])
    }

    func redo() async {
        guard let s = EditHistory.shared.popRedo() else {
            state.addLog("REDO", "nothing to redo", tint: .grey)
            return
        }
        EditHistory.shared.push(snapshot(s.label), clearRedo: false)
        await restore(s)
        state.addLog("REDO", s.label, tint: .orange)
        DebugLog.event("redo", ["label": s.label])
    }

    private func restore(_ s: EditHistory.Snapshot) async {
        // Anything still in flight (GPT arrangement) belongs to the state being left.
        digSerial += 1
        gptTask?.cancel()
        gptTask = nil
        state.isDigging = false

        let e = state.engine
        // Reload only the banks whose pads differ, so untouched banks don't click.
        for b in Bank.allCases {
            var now: [Int: PadSound] = [:], then: [Int: PadSound] = [:]
            for i in 0..<16 {
                if let x = state.sound(PadID(b, i)) { now[i] = x }
                if let x = s.sounds[PadID(b, i)] { then[i] = x }
            }
            if now != then { try? await e.loadBank(b, sounds: then) }
        }
        state.sounds = s.sounds
        BankA.setSlots(s.slots)
        e.bpm = s.bpm; state.bpm = s.bpm
        e.swing = s.swing; state.swing = s.swing
        e.setPattern(s.pattern, timing: .now)
        state.bars = s.bars
        state.scaleKey = s.scaleKey
        state.styleLabel = s.styleLabel
        state.sampleLabel = s.sampleLabel
        state.chordsLabel = s.chordsLabel
        session = s.session
        lastPattern = s.lastPattern
    }

    // MARK: Direct edits

    func setTempo(_ bpm: Double, checkpoint cp: Bool = true) {
        let v = min(200, max(50, bpm.rounded()))
        guard v != state.bpm || v != state.engine.bpm else { return }
        if cp { checkpoint("tempo \(Int(state.bpm)) BPM") }
        state.engine.bpm = v
        state.bpm = v
        DebugLog.event("tempo", ["bpm": v])
    }

    /// Loop length: longer repeats the current loop, shorter keeps the first bars.
    func setBars(_ n: Int) {
        let n = min(16, max(1, n))
        var p = state.engine.pattern
        let empty = p.lanes.isEmpty && p.notes.isEmpty
        let old = max(1, empty ? state.bars : p.bars)
        guard n != old || state.bars != n else { return }
        checkpoint("loop \(old) bar\(old == 1 ? "" : "s")")
        let oldSteps = old * 16, newSteps = n * 16
        func stretch<T>(_ items: [T], step: (T) -> Int, move: (T, Int) -> T) -> [T] {
            let base = items.filter { step($0) < oldSteps }
            if n <= old { return base.filter { step($0) < newSteps } }
            var out: [T] = []
            var k = 0
            while k * oldSteps < newSteps {
                for it in base where step(it) + k * oldSteps < newSteps { out.append(move(it, step(it) + k * oldSteps)) }
                k += 1
            }
            return out
        }
        p.lanes = p.lanes.mapValues { stretch($0, step: \.step, move: { var h = $0; h.step = $1; return h }) }
        p.notes = p.notes.mapValues { stretch($0, step: \.step, move: { var x = $0; x.step = $1; return x }) }
        p.bars = n
        state.engine.setPattern(p, timing: state.engine.isPlaying ? .nextBar : .now)
        lastPattern = p
        state.bars = n
        session?.bars = n
        state.addLog("LOOP", "\(n) bar\(n == 1 ? "" : "s")", tint: .orange)
        DebugLog.event("bars", ["bars": n])
    }

    // MARK: Sequencer edits

    /// A hand edit wins over a GPT rewrite still in flight.
    private func takeOverPattern() {
        digSerial += 1
        gptTask?.cancel()
        gptTask = nil
    }

    /// Removes a lane (or the merged CHOP lane) from the beat.
    func clearLane(_ pads: [PadID], label: String) {
        var p = state.engine.pattern
        guard pads.contains(where: { !(p.lanes[$0]?.isEmpty ?? true) || !(p.notes[$0]?.isEmpty ?? true) }) else { return }
        checkpoint("remove \(label)")
        takeOverPattern()
        for pad in pads { p.lanes[pad] = nil; p.notes[pad] = nil; p.late[pad] = nil }
        state.engine.setPattern(p, timing: .now)
        lastPattern = p
        state.addLog("SEQ", "removed \(label) · undo brings it back", tint: .orange)
        DebugLog.event("seq_clear", ["lane": label])
    }

    /// Toggles step `col` of the shown bar in every bar of the loop: on → off everywhere, off → on everywhere.
    func toggleStep(_ pads: [PadID], col: Int, bar: Int, label: String) {
        var p = state.engine.pattern
        let bars = max(1, p.bars)
        let steps = Set((0..<bars).map { $0 * 16 + col })
        let barStep = (bar % bars) * 16 + col
        let isOn = pads.contains { pad in
            (p.lanes[pad] ?? []).contains { $0.step == barStep } || (p.notes[pad] ?? []).contains { $0.step == barStep }
        }
        checkpoint("\(label) step \(col + 1)")
        takeOverPattern()
        if isOn {
            for pad in pads {
                p.lanes[pad] = p.lanes[pad].map { $0.filter { !steps.contains($0.step) } }
                p.notes[pad] = p.notes[pad].map { $0.filter { !steps.contains($0.step) } }
            }
        } else if let pad = pads.first {
            if let notes = p.notes[pad], let ref = notes.first {
                // melodic lane: repeat its first note's pitch
                p.notes[pad] = notes + steps.sorted().map { NoteEvent(step: $0, length: 1, midi: ref.midi, velocity: ref.velocity) }
            } else {
                let vel = (p.lanes[pad] ?? []).map(\.velocity).max() ?? 100
                p.lanes[pad, default: []] += steps.sorted().map { Hit(step: $0, velocity: min(118, vel)) }
                p.lanes[pad]?.sort { $0.step < $1.step }
            }
        }
        state.engine.setPattern(p, timing: .now)
        lastPattern = p
        DebugLog.event("seq_toggle", ["lane": label, "step": col + 1, "on": !isOn])
    }

    // MARK: Prompt commands

    /// "undo", "bpm 100", "8 bars", "reset pads", pad layout requests. Returns true when handled (no new beat).
    func handleCommand(_ prompt: String) async -> Bool {
        let p = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
        let words = p.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let nums = words.compactMap(Int.init)

        if ["undo", "undo that", "go back", "take that back", "revert"].contains(p) {
            await undo()
            return true
        }
        if ["redo", "redo that", "put it back", "bring it back"].contains(p) {
            await redo()
            return true
        }
        if ["reset pads", "reset the pads", "default layout", "reset layout", "reset pad layout", "default pads"].contains(p) {
            if BankA.slots != BankA.defaultSlots { checkpoint("pad layout") }
            await applyPadOrder(BankA.defaultSlots)
            return true
        }
        // Tempo: "bpm 100", "100 bpm", "tempo 110", "set the tempo to 96", "faster" / "slower"
        let tempoWords = words.contains("bpm") || words.contains("tempo")
        if tempoWords, nums.count == 1, words.count <= 6, let v = nums.first, (50...200).contains(v) {
            setTempo(Double(v))
            state.addLog("TEMPO", "\(v) BPM", tint: .orange)
            return true
        }
        if ["faster", "speed up", "speed it up"].contains(p) { setTempo(state.bpm + 5); state.addLog("TEMPO", "\(Int(state.bpm)) BPM", tint: .orange); return true }
        if ["slower", "slow down", "slow it down"].contains(p) { setTempo(state.bpm - 5); state.addLog("TEMPO", "\(Int(state.bpm)) BPM", tint: .orange); return true }
        // Loop length: "8 bars", "make it 2 bars", "loop 4 bars" (a whole new beat prompt has more words than this)
        if words.contains(where: { $0 == "bar" || $0 == "bars" }), nums.count == 1, words.count <= 5,
           let n = nums.first, [1, 2, 4, 8, 16].contains(n) {
            setBars(n)
            return true
        }
        if let order = Self.reorderRequest(prompt) {
            checkpoint("pad layout")
            await applyPadOrder(order)
            return true
        }
        return false
    }
}
