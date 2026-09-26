import Foundation

// CRATE Library+AI harness (macOS, not in the app). Dry-runs DIGs against the real library with MockEngine.
// Build: xcrun swiftc -swift-version 5 -target arm64-apple-macos15.0 Sources/Core/*.swift Sources/Library/*.swift \
//          Sources/AI/*.swift tools/harness/main.swift -o /tmp/crate-harness
// Run:   set -a; source ~/duo-hack/.secrets/keys.env; set +a; /tmp/crate-harness            (live Jev + OpenAI)
//        CRATE_OFFLINE=1 /tmp/crate-harness                                                   (no network)
//        CRATE_DEBUGLOG=1 ...   also print the CRATE {json} debug events;  CRATE_QUICK=1 only the two demo prompts

setvbuf(stdout, nil, _IOLBF, 0)
let env = ProcessInfo.processInfo.environment
func setArg(_ key: String, _ value: Bool) {
    var d = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    d[key] = value
    UserDefaults.standard.setVolatileDomain(d, forName: UserDefaults.argumentDomain)
}
setArg("crateDebugLog", env["CRATE_DEBUGLOG"] == "1")
setArg("crateOffline", env["CRATE_OFFLINE"] == "1")

let engine = MockEngine()
let state = AppState(engine: engine)
let library = LibraryStore()
print("LIBRARY \(library.summary) · load \(library.loadMs) ms · root \(library.root.path)")
for p in library.problems { print("  problem: \(p)") }
print("NETWORK offline=\(AppConfig.offline) jevKey=\(AppConfig.typesafeKey != nil) openAIKey=\(AppConfig.openAIKey != nil)")

// Retrieval micro-benchmark (spec: < 5 ms).
do {
    let t = Date()
    let n = 50
    for i in 0..<n {
        let target = Retrieval.kitTarget(library, style: .dilla, vintage: 0.7, brightness: nil, energy: nil)
        _ = Retrieval.kit(library, style: .dilla, target: target, seed: UInt64(i))
        if let l = Retrieval.loop(library, LoopRequest(sampleStyle: .jazzhop, drumStyle: .dilla, instrument: "piano", bars: 4), seed: UInt64(i)) {
            _ = Retrieval.chops(l, lib: library, bars: 4)
        }
        _ = Retrieval.bankC(library, style: .dilla, target: target, seed: UInt64(i))
    }
    let tp = Date()
    for _ in 0..<n { _ = KeywordParser.parse("4 bar loop, j dilla laid back drums and a killer nujabes piano sample", grooves: library.grooves) }
    print(String(format: "BENCH retrieval (kit+loop+chops+bankC) %.2f ms/dig · keyword parse %.2f ms",
                 Date().timeIntervalSince(t) * 1000 / Double(n) - Date().timeIntervalSince(tp) * 1000 / Double(n),
                 Date().timeIntervalSince(tp) * 1000 / Double(n)))
}

let orch = Orchestrator(state: state, library: library)
orch.wire()
if orch.jev.available { try? await Task.sleep(nanoseconds: 1_200_000_000) } // let the warm-up finish

@MainActor func grid(_ hits: [Hit], bar: Int) -> String {
    var g = Array(repeating: Character("."), count: 16)
    for h in hits where h.step / 16 == bar {
        g[h.step % 16] = h.ratchet > 1 ? "r" : h.velocity >= 105 ? "X" : h.velocity >= 60 ? "x" : "g"
    }
    return String(g)
}

@MainActor func dumpPattern(_ label: String) {
    let p = engine.pattern
    print("  \(label): bars \(p.bars) · swing \(p.swing) · bpm \(Int(engine.bpm)) · lanes \(p.lanes.count) · hits \(PatternBuilder.hitCount(p)) · notes \(PatternBuilder.noteCount(p))")
    for (pad, hits) in p.lanes.filter({ $0.key.bank == .a }).sorted(by: { $0.key.index < $1.key.index }) {
        let late = p.late[pad].map { String(format: " late %+.2f", $0) } ?? ""
        let offs = hits.prefix(6).map { String(format: "%+.2f", $0.offset) }.joined(separator: " ")
        print("    A\(String(format: "%02d", pad.number)) \(BankA.slots[pad.index].padding(toLength: 7, withPad: " ", startingAt: 0)) \(grid(hits, bar: 0)) \(grid(hits, bar: min(1, p.bars - 1)))\(late) · offs \(offs)")
    }
    let chopLanes = p.lanes.filter { $0.key.bank == .b }
    if !chopLanes.isEmpty {
        let order = chopLanes.flatMap { lane in lane.value.map { ($0.step, lane.key.index) } }.sorted { $0.0 < $1.0 }
        print("    B chops (step:slice) " + order.prefix(20).map { "\($0.0):\($0.1)" }.joined(separator: " "))
    }
    for (pad, notes) in p.notes {
        let root = engine.sound(for: pad)?.rootNote ?? -1
        print("    \(pad.bank.letter)\(pad.number) bass (pad root \(root)): " + notes.prefix(12).map { "\($0.step):\(Music.name($0.midi))/\(Int($0.length))" }.joined(separator: " "))
    }
}

@MainActor func dumpBanks() {
    for bank in [Bank.a, .b, .c] {
        let pads = (0..<16).compactMap { i in engine.sound(for: PadID(bank, i)).map { (i, $0) } }
        if bank == .b, let first = pads.first {
            let s = first.1
            print("  bank B: \(pads.count) chops of \((s.fileURL.path as NSString).lastPathComponent) · slice1 \(String(format: "%.3f–%.3f", s.start, s.end ?? -1)) s · root \(s.rootNote ?? -1)")
            continue
        }
        print("  bank \(bank.letter): " + pads.map { i, s in
            let src = (s.source as NSString).pathComponents.first ?? ""
            return "\(i + 1)=\(s.id) \(s.name)" + (bank == .a && [0, 2, 4].contains(i) ? " [\(src)]" : "")
        }.joined(separator: " · "))
    }
}

@MainActor func run(_ prompt: String, waitGPT: Bool) async {
    let r = await orch.dig(prompt)
    let p = r.plan
    func f(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "-" }
    print("\n━━ \"\(prompt)\"")
    print("  PLAN [\(p.source)] \(p.summary) · mood \(p.mood ?? "-") · laid \(f(p.laidback)) vint \(f(p.vintage)) energy \(f(p.energy)) bright \(f(p.brightness)) bass \(f(p.wantsBass))" + (p.jevOverrides.isEmpty ? "" : " · jev overrode \(p.jevOverrides)"))
    print("  TIMING total \(r.totalMs) ms · jev \(r.jevMs.map { "\($0) ms" } ?? "-") · retrieval \(r.retrievalMs) ms · load \(r.loadMs) ms")
    print("  LABELS \(state.styleLabel) · \(state.sampleLabel) · \(state.chordsLabel) · key \(state.scaleKey ?? "-") · bpm \(state.bpm) swing \(state.swing) bars \(state.bars)")
    if [.fullBeat, .drumsOnly, .sampleOnly, .singleSound].contains(p.scope) { dumpBanks() }
    dumpPattern("INSTANT")
    if waitGPT {
        let t = Date()
        await orch.waitForBackground()
        if orch.openAI.available {
            print("  GPT waited \(Int(Date().timeIntervalSince(t) * 1000)) ms · gptSeconds \(state.gptSeconds.map { String(format: "%.2f", $0) } ?? "-")")
            if let a = orch.lastArrangement {
                print("  GPT RAW \(a.title) · swing \(a.swing) · bass " + a.bass.prefix(10).map { "b\($0.bar)s\($0.step):\($0.midi)/\($0.len)" }.joined(separator: " "))
                print("  GPT RAW drums " + a.drums.map { "\($0.lane)[\($0.bars.count)] late \($0.late)" }.joined(separator: ", ") + " · chops \(a.chops?.count ?? -1)")
            }
            dumpPattern("AFTER GPT")
        }
    }
    for l in state.log.suffix(8) { print("  LOG \(l.tag.padding(toLength: 7, withPad: " ", startingAt: 0)) \(l.text)\(l.ms.map { " · \($0)ms" } ?? "")") }
    state.log.removeAll()
}

let quick = env["CRATE_QUICK"] == "1"
await run("4 bar loop, j dilla laid back drums and a killer nujabes piano sample", waitGPT: true)
await run("fill up the pads with some house drums", waitGPT: true)
if !quick {
    await run("make it more laid back", waitGPT: true)
    await run("flip it", waitGPT: true)
    await run("dusty vintage break with a sad rhodes, 8 bars", waitGPT: false)
    await run("hard trap beat with dark bells 140 bpm", waitGPT: false)
    state.selectedPad = PadID(.a, 8)
    await run("put a glass bottle perc on pad 9", waitGPT: false)
    await run("new walking bassline", waitGPT: true)

    print("\n━━ PERFORM (8 simulated bars)")
    orch.setPerform(true)
    for bar in 0..<8 {
        engine.onBar?(bar)
        try? await Task.sleep(nanoseconds: orch.jev.available ? 900_000_000 : 50_000_000)
    }
    orch.setPerform(false)
    for l in state.log { print("  LOG \(l.tag) \(l.text)\(l.ms.map { " · \($0)ms" } ?? "")") }
}
print("\nDONE")
