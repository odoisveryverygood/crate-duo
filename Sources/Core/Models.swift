import Foundation

// Shared contract for every module (BUILD.md §4). Foundation-only so it also compiles on macOS.

enum Style: String, CaseIterable, Codable, Hashable {
    case dilla, jazzhop, boombap, lofi, vintage, house, trap, drill, rnb
}

enum Category: String, Codable, CaseIterable, Hashable {
    case kick, snare, clap, hat, openhat, rim, perc, shaker, cymbal
    case eight08 = "808"
    case bass, fx, vocal, texture, keys, synth, chop, loop

    /// Sounds that follow the key when played in KEYS mode or by a bassline.
    var isPitched: Bool { [.eight08, .bass, .keys, .synth, .chop, .loop].contains(self) }
}

/// A = drums, B = sample chops, C = bass/keys, D = free (AI one-offs, generated sounds).
enum Bank: Int, CaseIterable, Codable, Hashable {
    case a = 0, b, c, d
    var letter: String { ["A", "B", "C", "D"][rawValue] }
}

/// index 0...15, 0 = pad 1 = bottom-left (MPC order; top row = pads 13-16).
struct PadID: Hashable, Codable {
    var bank: Bank
    var index: Int
    init(_ bank: Bank, _ index: Int) { self.bank = bank; self.index = index }
    var number: Int { index + 1 }
}

/// Bank-A slot layout; groove lanes in grooves.json use these names.
enum BankA {
    /// Bottom row (pads 1-4) = kick, snare, hat, open hat, like a finger-drummer's MPC layout.
    static let defaultSlots = ["kick", "snare", "hat", "openhat", "kick2", "clap", "hat2", "rim",
                               "perc", "perc2", "shaker", "cymbal", "808", "fx", "vocal", "texture"]
    /// The user's layout ("put kick snare hat hat on the bottom row"); persisted so later kits land in the same places.
    private(set) static var slots: [String] = {
        let saved = UserDefaults.standard.stringArray(forKey: "crateBankASlots") ?? []
        return Set(saved) == Set(defaultSlots) && saved.count == defaultSlots.count ? saved : defaultSlots
    }()
    static func setSlots(_ s: [String]) {
        slots = s
        UserDefaults.standard.set(s, forKey: "crateBankASlots")
    }
    static func index(forLane lane: String) -> Int? { slots.firstIndex(of: lane) }
    static func pad(forLane lane: String) -> PadID? { index(forLane: lane).map { PadID(.a, $0) } }
}

struct PadSound: Identifiable, Hashable {
    var id: String
    var name: String
    var category: Category
    var fileURL: URL
    /// Seconds into the file; chops are slices of one loop file.
    var start: Double = 0
    var end: Double? = nil
    var rootNote: Int? = nil
    var gain: Float = 1
    var source: String = ""
}

/// offset = fraction of one 16th (+ = late); ratchet = evenly spaced repeats inside the step.
struct Hit: Hashable, Codable {
    var step: Int
    var velocity: Int
    var offset: Double = 0
    var ratchet: Int = 1
}

/// Played on a pad, pitched (midi - rootNote) semitones. length is in steps.
struct NoteEvent: Hashable, Codable {
    var step: Int
    var length: Double
    var midi: Int
    var velocity: Int
}

/// Steps are absolute: 0 ..< bars*16.
struct Pattern: Hashable {
    var bars: Int = 1
    var swing: Double = 50
    var lanes: [PadID: [Hit]] = [:]
    var late: [PadID: Double] = [:]
    var notes: [PadID: [NoteEvent]] = [:]
    var totalSteps: Int { bars * 16 }
    static let empty = Pattern()
}

/// A one-bar fill from grooves.json. hits = [step, velocity, offset, ratchet?], bar-relative steps.
struct FillOp: Codable, Hashable {
    var op: String            // "clear" | "add" | "addNextBar"
    var lanes: [String]? = nil
    var lane: String? = nil
    var fromStep: Int? = nil
    var hits: [[Double]]? = nil
}

struct FillDef: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var ops: [FillOp]
}

enum ApplyTiming { case now, nextBar }

enum Mode: String, CaseIterable {
    case sample, chop, keys, seq, padFX, levels16
    var label: String {
        switch self {
        case .sample: return "SAMPLE"
        case .chop: return "CHOP"
        case .keys: return "KEYS"
        case .seq: return "SEQ"
        case .padFX: return "PAD FX"
        case .levels16: return "16 LVL"
        }
    }
}

enum Tint: Hashable { case orange, blue, ochre, grey, red }

struct LogLine: Identifiable, Hashable {
    let id = UUID()
    var tag: String          // JEV KIT SAMPLE BASS GPT PERFORM ERR
    var text: String
    var ms: Int? = nil
    var tint: Tint = .grey
}
