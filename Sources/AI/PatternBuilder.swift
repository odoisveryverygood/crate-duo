import Foundation

/// Groove templates + chops → Core.Pattern lanes. All pure and instant.
enum PatternBuilder {
    static let hipHop: Set<Style> = [.dilla, .jazzhop, .boombap, .lofi, .vintage, .rnb]

    static func defaultLaidback(_ s: Style) -> Double {
        switch s {
        case .dilla: return 0.8
        case .jazzhop, .lofi: return 0.6
        case .rnb: return 0.5
        case .boombap, .vintage: return 0.4
        case .house: return 0.2
        case .trap, .drill: return 0.1
        }
    }

    /// Template for a style; variant 0 = the style's first (canonical) groove, later digs rotate.
    static func groove(_ lib: LibraryStore, style: Style, variant: Int) -> GrooveTemplate? {
        let ids = lib.styleInfo(style).grooves
        let list = ids.compactMap { lib.grooves.groove(id: $0) }
        if !list.isEmpty { return list[abs(variant) % list.count] }
        return lib.grooves.grooves.first { $0.style == style.rawValue } ?? lib.grooves.grooves.first
    }

    static func swing(style: Style, groove: GrooveTemplate?, laidback: Double, lib: LibraryStore) -> Double {
        var s = groove?.swing ?? lib.styleInfo(style).swing
        if hipHop.contains(style) { s += (laidback - defaultLaidback(style)) * 8 }
        return min(66, max(50, s.rounded()))
    }

    /// Groove tiled to `bars`, lanes → bank-A pads, micro offsets × (0.5 + laidback).
    static func drums(_ g: GrooveTemplate, bars: Int, laidback: Double) -> [PadID: [Hit]] {
        var lanes: [PadID: [Hit]] = [:]
        let total = bars * 16
        let tSteps = max(1, g.bars) * 16
        let scale = 0.5 + max(0, min(1, laidback))
        for (lane, hits) in g.lanes {
            guard let pad = BankA.pad(forLane: lane) else { continue }
            var out: [Hit] = []
            var rep = 0
            while rep * tSteps < total {
                for h in hits where h.count >= 2 && Int(h[0]) < tSteps {
                    let step = Int(h[0]) + rep * tSteps
                    guard step < total else { continue }
                    let off = (h.count > 2 ? h[2] : 0) * scale
                    let rat = h.count > 3 ? max(1, min(4, Int(h[3]))) : 1
                    out.append(Hit(step: step, velocity: max(1, min(127, Int(h[1]))), offset: max(-0.5, min(0.5, off)), ratchet: rat))
                }
                rep += 1
            }
            if !out.isEmpty { lanes[pad] = out.sorted { $0.step < $1.step } }
        }
        return lanes
    }

    /// Chops in original order: slice i at step i·L inside each L-bar span (L = span bars), repeated to fill.
    static func chops(span: Int, bars: Int, velocity: Int = 100) -> [PadID: [Hit]] {
        var lanes: [PadID: [Hit]] = [:]
        let L = max(1, span), spanSteps = L * 16, total = bars * 16
        var rep = 0
        while rep * spanSteps < total {
            for i in 0..<16 {
                let step = rep * spanSteps + i * L
                if step < total { lanes[PadID(.b, i), default: []].append(Hit(step: step, velocity: velocity)) }
            }
            rep += 1
        }
        return lanes
    }

    /// Instant local "flip": re-sequence the 16 slices (stutters, repeats, reversed phrase halves).
    static func localFlip(span: Int, bars: Int, seed: UInt64) -> [PadID: [Hit]] {
        var rng = SeededRNG(seed: seed ^ 0xF11F)
        let motifs: [[Int]] = [[0, 0, 2, 3], [4, 4, 4, 7], [8, 9, 8, 11], [12, 12, 14, 15], [0, 3, 0, 3], [6, 7, 6, 5]]
        var order: [Int] = []
        while order.count < 16 { order += motifs[Int(rng.next() % UInt64(motifs.count))] }
        var lanes: [PadID: [Hit]] = [:]
        let L = max(1, span), total = bars * 16
        var step = 0, k = 0
        while step < total {
            let slice = order[k % 16]
            let vel = k % 4 == 0 ? 108 : 94
            lanes[PadID(.b, slice), default: []].append(Hit(step: step, velocity: vel))
            step += L; k += 1
        }
        return lanes
    }

    /// Repeat (or cut) an existing pattern to a new bar count.
    static func retile(_ p: Pattern, to bars: Int) -> Pattern {
        guard bars > 0, bars != p.bars else { return p }
        var out = p
        out.bars = bars
        let src = max(1, p.bars) * 16, total = bars * 16
        out.lanes = p.lanes.mapValues { hits in
            var r: [Hit] = []
            var rep = 0
            while rep * src < total {
                for h in hits where h.step < src && h.step + rep * src < total { var x = h; x.step += rep * src; r.append(x) }
                rep += 1
            }
            return r
        }
        out.notes = p.notes.mapValues { notes in
            var r: [NoteEvent] = []
            var rep = 0
            while rep * src < total {
                for n in notes where n.step < src && n.step + rep * src < total { var x = n; x.step += rep * src; r.append(x) }
                rep += 1
            }
            return r
        }
        return out
    }

    static func hitCount(_ p: Pattern) -> Int { p.lanes.values.reduce(0) { $0 + $1.count } }
    static func noteCount(_ p: Pattern) -> Int { p.notes.values.reduce(0) { $0 + $1.count } }

    static func kickSteps(_ lanes: [PadID: [Hit]]) -> [Hit] {
        ((lanes[PadID(.a, 0)] ?? []) + (lanes[PadID(.a, 1)] ?? [])).sorted { $0.step < $1.step }
    }

    /// Bank-A lanes as 16-char bar strings (X x g r .) for the OpenAI template.
    static func laneStrings(_ p: Pattern, maxBars: Int = 8) -> [String: [String]] {
        var out: [String: [String]] = [:]
        let bars = max(1, min(p.bars, maxBars))
        for (pad, hits) in p.lanes where pad.bank == .a && !hits.isEmpty && pad.index < 12 {
            var grid = Array(repeating: Array(repeating: Character("."), count: 16), count: bars)
            for h in hits where h.step >= 0 && h.step < bars * 16 {
                let c: Character = h.ratchet > 1 ? "r" : h.velocity >= 105 ? "X" : h.velocity >= 60 ? "x" : "g"
                grid[h.step / 16][h.step % 16] = c
            }
            out[BankA.slots[pad.index]] = grid.map { String($0) }
        }
        return out
    }
}
