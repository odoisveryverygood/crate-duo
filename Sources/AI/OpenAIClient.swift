import Foundation

/// Strict-schema output of the arranger prompt (ai/openai-arrange.md).
struct Arrangement: Codable {
    struct Drum: Codable { var lane: String; var bars: [String]; var late: Double }
    struct Bass: Codable { var bar: Int; var step: Int; var len: Double; var midi: Int; var vel: Int }
    struct Chop: Codable { var bar: Int; var step: Int; var slice: Int; var len: Double }
    /// MIDI chord stab on the keys pad (C2); only for MIDI-only beats (house), else null.
    struct ChordHit: Codable { var bar: Int; var step: Int; var len: Double; var notes: [Int]; var vel: Int }
    var title: String
    var comment: String
    var bpm: Int
    var swing: Int
    var drums: [Drum]
    var bass: [Bass]
    var chops: [Chop]?
    var chords: [ChordHit]?
}

enum ArrangePart: Hashable { case drums, bass, chops, chords }

struct OpenAIError: Error, CustomStringConvertible {
    var description: String
    init(_ d: String) { description = d }
}

/// OpenAI Responses API client (gpt-6-luna arrange, gpt-6-sol flip; reasoning effort none; strict json_schema).
final class OpenAIClient: @unchecked Sendable {
    static let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    static let arrangeModel = "gpt-6-luna"
    static let flipModel = "gpt-6-sol"
    private let session: URLSession

    var available: Bool { (AppConfig.appToken != nil || AppConfig.openAIKey != nil) && !AppConfig.offline }

    init() {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 12
        cfg.waitsForConnectivity = false
        cfg.urlCache = nil
        session = URLSession(configuration: cfg)
    }

    /// `userMessage` is the JSON object from the prompt's user template.
    func arrange(_ userMessage: [String: Any], model: String, timeout: Double = 8) async -> Result<(Arrangement, Int), OpenAIError> {
        guard available else { return .failure(OpenAIError("offline")) }
        guard let userData = try? JSONSerialization.data(withJSONObject: userMessage, options: [.sortedKeys]),
              let userText = String(data: userData, encoding: .utf8) else { return .failure(OpenAIError("bad request")) }
        let body: [String: Any] = [
            "model": model,
            "reasoning": ["effort": "none"],
            "instructions": OpenAIPrompts.system,
            "input": userText,
            "text": ["format": ["type": "json_schema", "name": "arrangement", "strict": true, "schema": OpenAIPrompts.schema]],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return .failure(OpenAIError("bad body")) }
        var req: URLRequest
        if let token = AppConfig.appToken {                 // via our server, which holds the key
            req = URLRequest(url: AppConfig.aiBase.appendingPathComponent("openai"))
            req.setValue(token, forHTTPHeaderField: "x-crate-token")
        } else {                                             // local experiments only (env var key)
            req = URLRequest(url: Self.endpoint)
            req.setValue("Bearer \(AppConfig.openAIKey ?? "")", forHTTPHeaderField: "Authorization")
        }
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout + 1
        req.httpBody = payload
        let t0 = Date()
        let urlSession = session
        let request = req
        let result: (Data, Int)? = await withTimeout(timeout) {
            let (d, r) = try await urlSession.data(for: request)
            return (d, (r as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        guard let (data, status) = result else { return .failure(OpenAIError("timeout \(ms)ms")) }
        guard status == 200, let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(OpenAIError("HTTP \(status) " + (String(data: data.prefix(240), encoding: .utf8) ?? "")))
        }
        var text = ""
        for item in obj["output"] as? [[String: Any]] ?? [] {
            for c in item["content"] as? [[String: Any]] ?? [] where (c["type"] as? String) == "output_text" {
                text += c["text"] as? String ?? ""
            }
        }
        guard !text.isEmpty else { return .failure(OpenAIError("no output_text (status \(obj["status"] ?? "?"))")) }
        do {
            let arr = try JSONDecoder().decode(Arrangement.self, from: Data(text.utf8))
            return .success((arr, ms))
        } catch {
            return .failure(OpenAIError("decode: \(error)"))
        }
    }

    /// 16-char repair: pad with "." / truncate.
    static func repair(_ s: String) -> [Character] {
        var c = Array(s.prefix(16))
        while c.count < 16 { c.append(".") }
        return c
    }

    /// Merge an arrangement into `base`: X=118, x=92, g=44, r = ratchet 2 @86; bass folded to the pad root.
    static func pattern(from a: Arrangement, base: Pattern, bars: Int, take: Set<ArrangePart>,
                        bassPad: PadID = PadID(.c, 0), bassRoot: Int?, style: Style? = nil) -> Pattern {
        var p = base
        p.bars = bars
        let total = bars * 16
        // Template micro-timing (per pad, per step within a 2-bar cycle) is kept under GPT's notes.
        let cycle = max(16, min(32, base.bars * 16))
        var baseOffsets: [PadID: [Int: Double]] = [:]
        for (pad, hits) in base.lanes where pad.bank == .a {
            for h in hits where baseOffsets[pad]?[h.step % cycle] == nil { baseOffsets[pad, default: [:]][h.step % cycle] = h.offset }
        }
        if take.contains(.drums) {
            var lanes: [PadID: [Hit]] = [:], late: [PadID: Double] = [:]
            for d in a.drums {
                guard let pad = BankA.pad(forLane: d.lane), !d.bars.isEmpty else { continue }
                var hits: [Hit] = []
                for bar in 0..<bars {
                    for (i, ch) in repair(d.bars[bar % d.bars.count]).enumerated() {
                        let step = bar * 16 + i
                        switch ch {
                        case "X": hits.append(Hit(step: step, velocity: 118))
                        case "x": hits.append(Hit(step: step, velocity: 92))
                        case "g": hits.append(Hit(step: step, velocity: 44))
                        case "r": hits.append(Hit(step: step, velocity: 86, ratchet: 2))
                        default: break
                        }
                    }
                }
                let offs = baseOffsets[pad] ?? [:]
                let humanized = offs.values.contains { abs($0) > 0.01 }
                for i in hits.indices { hits[i].offset = offs[hits[i].step % cycle] ?? offs[(hits[i].step % 16)] ?? 0 }
                if !hits.isEmpty { lanes[pad, default: []] += hits; late[pad] = humanized ? 0 : max(-0.3, min(0.4, d.late)) }
            }
            if lanes.values.reduce(0, { $0 + $1.count }) >= 4 {
                p.lanes = p.lanes.filter { $0.key.bank != .a || $0.key.index >= 12 }
                p.late = p.late.filter { $0.key.bank != .a }
                for (k, v) in lanes { p.lanes[k] = v.sorted { $0.step < $1.step } }
                for (k, v) in late where v != 0 { p.late[k] = v }
                p.swing = Double(max(50, min(70, a.swing)))
            }
        }
        if take.contains(.bass) {
            let valid = a.bass.filter { $0.bar >= 0 && $0.bar < bars && (0..<16).contains($0.step) }
            let span = max(1, (valid.map(\.bar).max() ?? 0) + 1)
            var notes: [NoteEvent] = []
            var rep = 0
            while rep * span < bars {
                for n in valid {
                    let step = (rep * span + n.bar) * 16 + n.step
                    guard step < total else { continue }
                    let midi = Music.fold(max(28, min(52, n.midi)), near: bassRoot ?? 36)
                    notes.append(NoteEvent(step: step, length: max(0.5, min(16, n.len)), midi: midi, velocity: max(1, min(127, n.vel))))
                }
                rep += 1
            }
            notes.sort { $0.step < $1.step }
            // Warm styles: sustain very short notes toward the next one (GPT tends to write 1.5–2-step stabs).
            if let st = style, ![.house, .trap, .drill].contains(st), let first = notes.first {
                for i in notes.indices {
                    let next = i + 1 < notes.count ? notes[i + 1].step : total + first.step
                    notes[i].length = max(notes[i].length, min(Double(next - notes[i].step), 4))
                }
            }
            if !notes.isEmpty { p.notes[bassPad] = notes }
        }
        if take.contains(.chords), let chords = a.chords {
            // Key guard (Orchestrator.apply) snaps every bank-C note, chords included, into state.scaleKey.
            let notes = ChordWriter.events(from: chords, bars: bars)
            if Set(notes.map(\.step)).count >= 4 { p.notes[ChordWriter.pad] = notes }
        }
        if take.contains(.chops), let chops = a.chops {
            let valid = chops.filter { $0.bar >= 0 && $0.bar < bars && (0..<16).contains($0.step) && (0..<16).contains($0.slice) }
            if !valid.isEmpty {
                let span = max(1, (valid.map(\.bar).max() ?? 0) + 1)
                var lanes: [PadID: [Hit]] = [:]
                var rep = 0
                while rep * span < bars {
                    for c in valid {
                        let step = (rep * span + c.bar) * 16 + c.step
                        if step < total { lanes[PadID(.b, c.slice), default: []].append(Hit(step: step, velocity: 100)) }
                    }
                    rep += 1
                }
                p.lanes = p.lanes.filter { $0.key.bank != .b }
                for (k, v) in lanes { p.lanes[k] = v.sorted { $0.step < $1.step } }
            }
        }
        return p
    }
}
