import Foundation

struct LoopRequest {
    var sampleStyle: Style
    var drumStyle: Style
    var instrument: String = "any"
    var mood: String? = nil
    var bars: Int = 4
    var bpm: Double? = nil
    var excludeID: String? = nil
}

/// The chosen loop cut to the requested span and sliced into 16 bank-B pads.
struct ChopSet {
    var loop: LoopEntry
    var spanBars: Int
    var spanSec: Double
    var starts: [Double]
    var sounds: [Int: PadSound]
    /// One entry per bar of the span (nil = unknown chord).
    var chords: [ChordInfo?]
    var bassPerBeat: [Int?]
    var keyPC: Int?
    var keyMinor: Bool
    var rootNote: Int
    var chordsLabel: String
}

/// Local retrieval over the analyzed library: no model, < 5 ms, seeded for DIG AGAIN variety.
enum Retrieval {
    static func slotCategory(_ slot: String) -> String { ["kick2": "kick", "hat2": "hat", "perc2": "perc"][slot] ?? slot }

    /// Style kit target nudged by Jev/keyword scores (vintage → dust, brightness → brightness, energy → punch).
    static func kitTarget(_ lib: LibraryStore, style: Style, vintage: Double?, brightness: Double?, energy: Double?) -> KitTarget {
        var t = lib.styleInfo(style).kit
        if let v = vintage { t.dust = t.dust * 0.55 + v * 0.45 }
        if let b = brightness { t.brightness = t.brightness * 0.55 + b * 0.45 }
        if let e = energy { t.punch = t.punch * 0.55 + e * 0.45 }
        return t
    }

    static func score(_ s: OneShot, style: Style, target t: KitTarget, rand: Double) -> Double {
        1.0 * s.style(style) + 0.35 * (1 - abs(s.dust - t.dust)) + 0.25 * (1 - abs(s.brightness - t.brightness))
            + 0.2 * (1 - abs(s.punch - t.punch)) + 0.08 * rand
    }

    /// Candidates of a category ranked best-first. `words` (prompt words) boost tag/name matches.
    static func ranked(_ lib: LibraryStore, category: String, style: Style, target: KitTarget,
                       rng: inout SeededRNG, words: [String] = []) -> [OneShot] {
        var scored: [(OneShot, Double)] = []
        for s in lib.candidates(category) {
            var sc = score(s, style: style, target: target, rand: rng.unit())
            if !words.isEmpty {
                let hay = ((s.tags ?? []) + [s.name, s.source ?? ""]).joined(separator: " ").lowercased()
                for w in words where w.count >= 3 && hay.contains(w) { sc += 0.25 }
            }
            scored.append((s, sc))
        }
        scored.sort { $0.1 > $1.1 }
        return scored.map(\.0)
    }

    static func padSound(_ s: OneShot, lib: LibraryStore) -> PadSound {
        let cat = Category(rawValue: s.category) ?? .perc
        var root = s.rootNote
        if root == nil, cat == .eight08 || cat == .bass { root = 36 }
        if root == nil, cat == .keys || cat == .synth { root = 60 }
        return PadSound(id: s.id, name: s.name.uppercased(), category: cat, fileURL: lib.fileURL(s.file),
                        rootNote: root, source: s.source ?? "")
    }

    /// Bank A: one sound per BankA slot; "2" slots get the runner-up (best unused).
    static func kit(_ lib: LibraryStore, style: Style, target: KitTarget, seed: UInt64) -> [Int: PadSound] {
        var rng = SeededRNG(seed: seed)
        var used = Set<String>()
        var out: [Int: PadSound] = [:]
        for (i, slot) in BankA.slots.enumerated() {
            let list = ranked(lib, category: slotCategory(slot), style: style, target: target, rng: &rng)
            guard let pick = list.first(where: { !used.contains($0.id) }) ?? list.first else { continue }
            used.insert(pick.id)
            out[i] = padSound(pick, lib: lib)
        }
        return out
    }

    /// Loop instruments that satisfy a requested instrument (nil = no filter).
    static func instrumentSet(_ inst: String) -> Set<String>? {
        switch inst {
        case "piano", "rhodes", "keys", "ep", "vibes": return ["piano", "rhodes", "keys"]
        case "horns", "horn", "sax", "flute", "trumpet", "brass": return ["sax", "flute", "horns"]
        case "guitar": return ["guitar"]
        case "strings": return ["strings"]
        case "pad": return ["pad"]
        case "break": return ["break"]
        case "vocal": return ["vocal"]
        default: return nil
        }
    }

    static func loop(_ lib: LibraryStore, _ req: LoopRequest, seed: UInt64) -> LoopEntry? {
        rankedLoops(lib, req, seed: seed).first
    }

    /// Every candidate loop for the request, best first (the same scoring `loop` picks its winner by).
    static func rankedLoops(_ lib: LibraryStore, _ req: LoopRequest, seed: UInt64) -> [LoopEntry] {
        var rng = SeededRNG(seed: seed ^ 0xA5A5_5A5A)
        var pool = lib.loops
        if let set = instrumentSet(req.instrument) {
            let f = pool.filter { set.contains($0.instrument) }
            if !f.isEmpty { pool = f }
        } else {
            let f = pool.filter { $0.instrument != "break" } // "any" = a melodic sample, not a drum break
            if !f.isEmpty { pool = f }
        }
        if let ex = req.excludeID, pool.count > 1 { pool.removeAll { $0.id == ex } }
        let range = lib.styleInfo(req.drumStyle).bpmRange
        let hipHop: Set<Style> = [.dilla, .jazzhop, .boombap, .lofi, .vintage]
        var scored: [(LoopEntry, Double)] = []
        for l in pool {
            var s = 1.0 * l.style(req.sampleStyle)
            if let m = req.mood { s += 0.3 * ((l.moods ?? []).contains(m) ? 1 : 0) }
            let fit: Double
            if let want = req.bpm {
                fit = max(0, 1 - abs(l.bpm - want) / 12)
            } else if range.contains(l.bpm) {
                fit = 1
            } else {
                let d = l.bpm < range.lowerBound ? range.lowerBound - l.bpm : l.bpm - range.upperBound
                fit = max(0, 1 - d / 15)
            }
            s += 0.3 * fit
            if req.bpm == nil, hipHop.contains(req.drumStyle), !(80...100).contains(l.bpm) { s -= 0.2 }
            s += 0.1 * (l.keyConfidence ?? 0)
            let cpb = l.chordsPerBar ?? []
            if !cpb.isEmpty { s += 0.1 * Double(cpb.compactMap { $0 }.count) / Double(cpb.count) } // chords feed the bass + lid
            s += 0.1 * (l.bars >= req.bars ? 1 : 0)
            if l.instrument == req.instrument { s += 0.35 } // an explicitly named instrument beats its neighbours
            s += 0.08 * rng.unit()
            scored.append((l, s))
        }
        // Stable: equal scores keep pool order, so the first of them wins as before.
        return scored.enumerated().sorted { a, b in a.element.1 != b.element.1 ? a.element.1 > b.element.1 : a.offset < b.offset }
            .map { $0.element.0 }
    }

    /// First `bars` of the loop as 16 slices (equal over the span, snapped to onsets within 40 ms).
    static func chops(_ loop: LoopEntry, lib: LibraryStore, bars requested: Int) -> ChopSet {
        let span = max(1, min(requested, loop.bars))
        var spanSec: Double
        if span >= loop.bars {
            spanSec = loop.durationSec
        } else if let beats = loop.beatsSec, beats.count > span * 4 {
            spanSec = beats[span * 4]
        } else {
            spanSec = Double(span) * loop.secondsPerBar
        }
        spanSec = min(max(spanSec, 0.1), loop.durationSec)

        var starts: [Double]
        if span >= loop.bars, let s16 = loop.slices16Sec, s16.count == 16 {
            starts = s16
        } else {
            let onsets = loop.onsetsSec ?? []
            starts = (0..<16).map { i in
                let t = Double(i) * spanSec / 16
                if let near = onsets.min(by: { abs($0 - t) < abs($1 - t) }), abs(near - t) <= 0.04 { return near }
                return t
            }
        }
        for i in 1..<16 where starts[i] <= starts[i - 1] { starts[i] = starts[i - 1] + 0.005 }

        let key = Music.parseKey(loop.key)
        let root = 60 + (key?.pc ?? 0)
        let url = lib.fileURL(loop.file)
        let short = loop.name.split(separator: " ").first.map(String.init) ?? "CHOP"
        var sounds: [Int: PadSound] = [:]
        for i in 0..<16 {
            let end = i < 15 ? starts[i + 1] : spanSec
            sounds[i] = PadSound(id: "\(loop.id)#\(i)", name: "\(short) \(i + 1)", category: .chop, fileURL: url,
                                 start: starts[i], end: end, rootNote: root, source: loop.source ?? loop.name)
        }
        let cpb = loop.chordsPerBar ?? []
        let chords: [ChordInfo?] = (0..<span).map { b in b < cpb.count ? ChordInfo.parse(cpb[b]) : nil }
        let bpb = Array((loop.bassPerBeat ?? []).prefix(span * 4))
        var names: [String] = []
        for c in chords.compactMap({ $0?.symbol }) where names.last != c { names.append(c) }
        let label = names.isEmpty ? (loop.key ?? "") : names.joined(separator: "–")
        return ChopSet(loop: loop, spanBars: span, spanSec: spanSec, starts: starts, sounds: sounds, chords: chords,
                       bassPerBeat: bpb, keyPC: key?.pc, keyMinor: key?.minor ?? true, rootNote: root, chordsLabel: label)
    }

    /// Bank C: 0 = bass (808 for trap/drill), 1 = keys, 2 = synth, 3 = 808 alt.
    static func bankC(_ lib: LibraryStore, style: Style, target: KitTarget, seed: UInt64) -> [Int: PadSound] {
        var rng = SeededRNG(seed: seed ^ 0xC0C0_C0C0)
        var out: [Int: PadSound] = [:]
        let bassCat = (style == .trap || style == .drill) ? "808" : "bass"
        let bass = ranked(lib, category: bassCat, style: style, target: target, rng: &rng).first
            ?? ranked(lib, category: "808", style: style, target: target, rng: &rng).first
        if let b = bass { out[0] = padSound(b, lib: lib) }
        if ChordWriter.midiStyles.contains(style), let stab = chordStab(lib) {
            out[1] = stab
        } else if let k = ranked(lib, category: "keys", style: style, target: target, rng: &rng).first {
            out[1] = padSound(k, lib: lib)
        }
        if let s = ranked(lib, category: "synth", style: style, target: target, rng: &rng).first { out[2] = padSound(s, lib: lib) }
        if let alt = ranked(lib, category: "808", style: style, target: target, rng: &rng).first(where: { $0.id != bass?.id }) {
            out[3] = padSound(alt, lib: lib)
        }
        return out
    }

    /// Single-note keys one-shots for MIDI chord stabs, pitch measured offline (librosa pyin median and CQT peak agree;
    /// the pack's rootNote tag is an octave off for KY08). Chord one-shots are excluded: they'd stack into mud.
    static let chordStabs: [(id: String, root: Int)] = [("KY08", 72), ("KY06", 63)] // Rhodes C5, vibraphone Eb4

    static func chordStab(_ lib: LibraryStore) -> PadSound? {
        let pool = lib.candidates("keys") + lib.candidates("synth")
        for (id, root) in chordStabs {
            guard let s = pool.first(where: { $0.id == id }) else { continue }
            var ps = padSound(s, lib: lib)
            ps.rootNote = root
            return ps
        }
        return nil
    }

    /// Best library match for a single-sound request (category from Jev `route` or keywords).
    static func single(_ lib: LibraryStore, category: String, style: Style, prompt: String, seed: UInt64) -> PadSound? {
        var rng = SeededRNG(seed: seed ^ 0x51_51)
        let words = prompt.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let target = lib.styleInfo(style).kit
        return ranked(lib, category: category, style: style, target: target, rng: &rng, words: words).first
            .map { padSound($0, lib: lib) }
    }
}
