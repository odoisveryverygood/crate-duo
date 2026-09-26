import SwiftUI

/// Fake, fully-populated state for previews and UI snapshots (MockEngine keeps time, so playheads move).
enum PreviewData {
    static func state(engine: SamplerEngine = MockEngine(), mode: Mode = .seq, bank: Bank = .a, playing: Bool = true,
                      digging: Bool = false, emptyLog: Bool = false) -> AppState {
        let s = AppState(engine: engine)
        let url = URL(fileURLWithPath: "/dev/null")

        let drumNames = ["VNYL KCK", "DUST KCK", "SOFT SNR", "CLN CLP", "DRY HAT", "HAT 2", "OPEN HAT", "RIM",
                         "PERC 026", "CONGA", "SOFT SHK", "CRASH", "808 C", "SOFT FX", "CLN VOX", "VINYL"]
        let drumCats: [Category] = [.kick, .kick, .snare, .clap, .hat, .hat, .openhat, .rim,
                                    .perc, .perc, .shaker, .cymbal, .eight08, .fx, .vocal, .texture]
        for i in 0..<16 {
            s.sounds[PadID(.a, i)] = PadSound(id: "A\(i)", name: drumNames[i], category: drumCats[i], fileURL: url)
        }
        var t = 0.0
        for i in 0..<16 {
            let len = 1.2 + 0.2 * Double((i * 7) % 3)
            s.sounds[PadID(.b, i)] = PadSound(id: "B\(i)", name: "NUJ JAZZ \(i + 1)", category: .chop, fileURL: url,
                                               start: t, end: t + len, rootNote: 57, source: "NUJ JAZZ")
            t += len
        }
        s.sounds[PadID(.c, 0)] = PadSound(id: "C0", name: "808 F", category: .eight08, fileURL: url, rootNote: 29,
                                           source: "Kryptic Lofi 808")
        s.sounds[PadID(.c, 1)] = PadSound(id: "C1", name: "RHODES", category: .keys, fileURL: url, rootNote: 60)
        s.sounds[PadID(.c, 2)] = PadSound(id: "C2", name: "SAW PAD", category: .synth, fileURL: url, rootNote: 60)

        // A laid-back 4-bar pattern (same idea as the mockup).
        var p = Pattern(bars: 4, swing: 56)
        let kick = PadID(.a, 0), snr = PadID(.a, 2), hat = PadID(.a, 4), rim = PadID(.a, 7)
        for bar in 0..<4 {
            let o = bar * 16
            p.lanes[kick, default: []] += [Hit(step: o, velocity: 118), Hit(step: o + 7, velocity: 92), Hit(step: o + 10, velocity: 118)]
            p.lanes[snr, default: []] += [Hit(step: o + 4, velocity: 118, offset: 0.18), Hit(step: o + 12, velocity: 118, offset: 0.18),
                                          Hit(step: o + 15, velocity: 44)]
            for k in stride(from: 0, to: 16, by: 2) {
                p.lanes[hat, default: []].append(Hit(step: o + k, velocity: k % 4 == 0 ? 104 : 86))
            }
            p.lanes[hat, default: []].append(Hit(step: o + 15, velocity: 44))
            p.lanes[rim, default: []].append(Hit(step: o + 9, velocity: 92))
            for k in 0..<4 {
                p.lanes[PadID(.b, (bar * 4 + k) % 16), default: []].append(Hit(step: o + k * 4, velocity: 110))
            }
            let roots = [33, 38, 31, 36]
            p.notes[PadID(.c, 0), default: []] += [
                NoteEvent(step: o, length: 3, midi: roots[bar], velocity: 110),
                NoteEvent(step: o + 6, length: 2, midi: roots[bar] + 7, velocity: 96),
                NoteEvent(step: o + 10, length: 3, midi: roots[bar], velocity: 104),
                NoteEvent(step: o + 14, length: 1, midi: roots[bar] + 10, velocity: 90),
            ]
        }
        p.late[snr] = 0.1
        engine.setPattern(p, timing: .now)
        engine.bpm = 89
        engine.swing = 56
        s.bpm = 89
        s.swing = 56
        s.bars = 4
        if playing { engine.play(); s.isPlaying = true }

        s.mode = mode
        s.bank = bank
        s.styleLabel = "J Dilla × Jazz Hop"
        s.sampleLabel = "NUJ KEYS"
        s.chordsLabel = "Am9 → Dm9 → G13 → Cmaj9"
        s.scaleKey = "Am"
        s.jevMs = 118
        s.gptSeconds = 2.4
        s.prompt = "4 bar loop, j dilla laid back drums + a killer nujabes piano sample"
        s.isDigging = digging
        if !emptyLog {
            s.addLog("JEV", "DILLA · JAZZHOP · 4 BARS", ms: 118, tint: .orange)
            s.addLog("KIT", "16 VINTAGE HIP HOP KITS", tint: .orange)
            s.addLog("SAMPLE", "NUJ KEYS Am", tint: .blue)
            s.addLog("BASS", "✓ GPT 2.4s walking bass under Am9–Dm9", ms: 2400, tint: .ochre)
        }
        if mode == .keys {
            s.selectedPad = PadID(.c, 0)
            s.bank = .c
            CrateUI.shared.lastMidi = 32
            CrateUI.shared.lastSemi = 3
            s.lastNoteName = Music.name(32)
        } else {
            s.selectedPad = PadID(bank, 2)
        }
        return s
    }
}

#Preview("Lid · laptop 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    LidDisplayView(state: PreviewData.state())
}

#Preview("Lid · book 455×669", traits: .fixedLayout(width: 455, height: 669)) {
    LidDisplayView(state: PreviewData.state())
}

#Preview("Lid · KEYS 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    LidDisplayView(state: PreviewData.state(mode: .keys))
}

#Preview("Lid · CHOP 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    LidDisplayView(state: PreviewData.state(mode: .chop, bank: .b))
}

#Preview("Deck · laptop 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    DeckView(state: PreviewData.state())
}

#Preview("Deck · book 455×669", traits: .fixedLayout(width: 455, height: 669)) {
    DeckView(state: PreviewData.state())
}

#Preview("Deck · KEYS 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    DeckView(state: PreviewData.state(mode: .keys))
}

#Preview("Deck · KEYS 455×669", traits: .fixedLayout(width: 455, height: 669)) {
    DeckView(state: PreviewData.state(mode: .keys))
}

#Preview("Compact 466×678", traits: .fixedLayout(width: 466, height: 678)) {
    CompactView(state: PreviewData.state())
}

#Preview("Crowd 669×455", traits: .fixedLayout(width: 669, height: 455)) {
    CrowdView(state: PreviewData.state())
}
