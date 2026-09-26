import Foundation
import Observation
import UIKit

/// A saved CRATE session: pads (by file path), pattern, tempo, labels. JSON in Documents/projects/<id>.json.
struct Project: Codable, Identifiable, Hashable {
    struct Sound: Codable, Hashable {
        var id: String
        var name: String
        var category: String
        /// Absolute path, or "~docs/<rel>" for files inside the app's Documents (container path changes per install).
        var filePath: String
        var start: Double
        var end: Double?
        var rootNote: Int?
        var gain: Float
    }

    struct PatternData: Codable, Hashable {
        var bars: Int
        var swing: Double
        var lanes: [String: [Hit]]
        var late: [String: Double]
        var notes: [String: [NoteEvent]]
    }

    var id: String
    var name: String
    var created: Date
    var updated: Date
    var bpm: Double
    var swing: Double
    var bars: Int
    var scaleKey: String?
    var styleLabel: String
    var sampleLabel: String
    var chordsLabel: String
    /// Keyed by pad, e.g. "A3" = bank A, pad 3.
    var sounds: [String: Sound]
    var pattern: PatternData
    var fxType: String?
}

// MARK: - Codable-friendly encodings

extension PadID {
    /// "A3" = bank A, pad number 3 (index 2).
    var key: String { bank.letter + String(number) }
    init?(key: String) {
        guard let first = key.first, let bank = Bank.allCases.first(where: { $0.letter == String(first).uppercased() }),
              let n = Int(key.dropFirst()), (1...16).contains(n) else { return nil }
        self.init(bank, n - 1)
    }
}

extension Project.PatternData {
    init(_ p: Pattern) {
        bars = p.bars
        swing = p.swing
        lanes = Dictionary(uniqueKeysWithValues: p.lanes.map { ($0.key.key, $0.value) })
        late = Dictionary(uniqueKeysWithValues: p.late.map { ($0.key.key, $0.value) })
        notes = Dictionary(uniqueKeysWithValues: p.notes.map { ($0.key.key, $0.value) })
    }

    var pattern: Pattern {
        var p = Pattern()
        p.bars = max(1, bars)
        p.swing = swing
        for (k, v) in lanes { if let id = PadID(key: k) { p.lanes[id] = v } }
        for (k, v) in late { if let id = PadID(key: k) { p.late[id] = v } }
        for (k, v) in notes { if let id = PadID(key: k) { p.notes[id] = v } }
        return p
    }
}

extension Project.Sound {
    static let docsPrefix = "~docs/"

    init(_ s: PadSound) {
        id = s.id; name = s.name; category = s.category.rawValue
        start = s.start; end = s.end; rootNote = s.rootNote; gain = s.gain
        let path = s.fileURL.standardizedFileURL.path
        let docs = ProjectStore.documents.standardizedFileURL.path + "/"
        filePath = path.hasPrefix(docs) ? Self.docsPrefix + String(path.dropFirst(docs.count)) : path
    }

    var padSound: PadSound {
        let url = filePath.hasPrefix(Self.docsPrefix)
            ? ProjectStore.documents.appendingPathComponent(String(filePath.dropFirst(Self.docsPrefix.count)))
            : URL(fileURLWithPath: filePath)
        return PadSound(id: id, name: name, category: Category(rawValue: category) ?? .perc, fileURL: url,
                        start: start, end: end, rootNote: rootNote, gain: gain, source: "project")
    }
}

// MARK: - Store

/// Save / list / open / new, autosave (debounced 1 s on pattern / pad / tempo changes, and on background),
/// and restore of the last project on launch (skipped with `-crateFresh 1`).
@MainActor
@Observable
final class ProjectStore {
    static let shared = ProjectStore()

    private(set) var current: Project?
    private(set) var projects: [Project] = []

    @ObservationIgnored private weak var state: AppState?
    @ObservationIgnored private var booted = false
    @ObservationIgnored private var loading = false
    @ObservationIgnored private var lastSig: Int?
    @ObservationIgnored private var savedSig: Int?
    @ObservationIgnored private var bgObserver: NSObjectProtocol?

    private static let lastKey = "crateLastProject"

    nonisolated static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    nonisolated static var folder: URL {
        let u = documents.appendingPathComponent("projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    nonisolated static func url(_ id: String) -> URL { folder.appendingPathComponent(id + ".json") }

    var currentName: String { current?.name ?? "UNTITLED" }

    // MARK: Boot

    /// Call once at launch: restore the last project, then start the autosave watcher.
    func boot(state: AppState) async {
        guard !booted else { return }
        booted = true
        self.state = state
        refresh()
        if !UserDefaults.standard.bool(forKey: "crateFresh"),
           let id = UserDefaults.standard.string(forKey: Self.lastKey),
           let p = projects.first(where: { $0.id == id }) {
            await load(p, into: state)
        }
        bgObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.autosaveNow() }
        }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.tick()
            }
        }
    }

    /// Debounce: save once the signature has been stable for ≥ 1 s (two consecutive 0.5 s ticks) and differs from the saved one.
    private func tick() {
        guard let state, !loading else { return }
        let sig = signature(state)
        defer { lastSig = sig }
        guard sig == lastSig, sig != savedSig else { return }
        if current == nil && isEmpty(state) { return }
        save(state: state)
    }

    private func autosaveNow() {
        guard let state, !loading else { return }
        if current == nil && isEmpty(state) { return }
        if signature(state) != savedSig { save(state: state) }
    }

    private func isEmpty(_ s: AppState) -> Bool { pads(s).isEmpty && s.engine.pattern.lanes.isEmpty && s.engine.pattern.notes.isEmpty }

    private func signature(_ s: AppState) -> Int {
        var h = Hasher()
        h.combine(s.engine.pattern)
        h.combine(s.bpm); h.combine(s.swing); h.combine(s.fxType); h.combine(s.scaleKey)
        h.combine(s.styleLabel); h.combine(s.sampleLabel)
        for (k, v) in pads(s).sorted(by: { $0.key < $1.key }) { h.combine(k); h.combine(v) }
        return h.finalize()
    }

    private func pads(_ s: AppState) -> [String: PadSound] {
        var out: [String: PadSound] = [:]
        for bank in Bank.allCases {
            for i in 0..<16 {
                let pad = PadID(bank, i)
                if let snd = s.sound(pad) { out[pad.key] = snd }
            }
        }
        return out
    }

    // MARK: API

    func list() -> [Project] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? dec.decode(Project.self, from: Data(contentsOf: $0)) }
            .sorted { $0.updated > $1.updated }
    }

    func refresh() { projects = list() }

    /// Saves the state into the current project (creating one if there is none). `asNew` forks a new project.
    @discardableResult
    func save(state: AppState, name: String? = nil, asNew: Bool = false) -> Project {
        let now = Date()
        var p: Project
        if let c = current, !asNew {
            p = c
        } else {
            p = Project(id: UUID().uuidString, name: name ?? autoName(state), created: now, updated: now,
                        bpm: 90, swing: 50, bars: 1, scaleKey: nil, styleLabel: "", sampleLabel: "", chordsLabel: "",
                        sounds: [:], pattern: .init(.empty), fxType: nil)
        }
        if let name, !name.isEmpty { p.name = name }
        let pattern = state.engine.pattern
        p.updated = now
        p.bpm = state.bpm; p.swing = state.swing; p.bars = pattern.bars
        p.scaleKey = state.scaleKey
        p.styleLabel = state.styleLabel; p.sampleLabel = state.sampleLabel; p.chordsLabel = state.chordsLabel
        p.sounds = pads(state).mapValues(Project.Sound.init)
        p.pattern = .init(pattern)
        p.fxType = state.fxType
        write(p)
        current = p
        savedSig = signature(state)
        UserDefaults.standard.set(p.id, forKey: Self.lastKey)
        refresh()
        DebugLog.event("project_save", ["id": p.id, "name": p.name, "pads": p.sounds.count])
        return p
    }

    func load(_ p: Project, into state: AppState) async {
        loading = true
        defer { loading = false }
        let e = state.engine
        var byBank: [Bank: [Int: PadSound]] = [:]
        for (k, snd) in p.sounds {
            guard let pad = PadID(key: k) else { continue }
            byBank[pad.bank, default: [:]][pad.index] = snd.padSound
        }
        // Every bank reloads (empty = cleared) so the previous project's pads don't linger.
        if e is MockEngine {
            for b in Bank.allCases { try? await e.loadBank(b, sounds: byBank[b] ?? [:]) }
        } else {
            await withTaskGroup(of: Void.self) { g in
                for b in Bank.allCases {
                    let snd = byBank[b] ?? [:]
                    g.addTask { try? await e.loadBank(b, sounds: snd) }
                }
            }
        }
        var sounds: [PadID: PadSound] = [:]
        for (b, m) in byBank { for (i, s) in m { sounds[PadID(b, i)] = s } }
        state.sounds = sounds
        e.bpm = p.bpm; state.bpm = p.bpm
        e.swing = p.swing; state.swing = p.swing
        let pattern = p.pattern.pattern
        e.setPattern(pattern, timing: .now)
        Orchestrator.current?.lastPattern = pattern
        Orchestrator.current?.session = nil
        state.bars = pattern.bars
        state.scaleKey = p.scaleKey
        state.styleLabel = p.styleLabel.isEmpty ? "CRATE" : p.styleLabel
        state.sampleLabel = p.sampleLabel
        state.chordsLabel = p.chordsLabel
        state.selectFX(p.fxType.flatMap(FXType.init(rawValue:)))
        current = p
        UserDefaults.standard.set(p.id, forKey: Self.lastKey)
        savedSig = signature(state)
        lastSig = savedSig
        state.addLog("PROJECT", "open \(p.name)", tint: .grey)
        DebugLog.event("project_open", ["id": p.id, "name": p.name, "pads": p.sounds.count])
    }

    /// Stop, clear the pattern and banks B–D (bank A's drum kit stays), 90 BPM, then start a fresh project.
    func newProject(state: AppState) async {
        let e = state.engine
        loading = true
        if e.isPlaying { e.stop() }
        state.isPlaying = false
        if state.isRecording { state.setRecording(false) }
        e.setPattern(Pattern(bars: 4, swing: 50), timing: .now)
        Orchestrator.current?.lastPattern = .empty
        Orchestrator.current?.session = nil
        for b in [Bank.b, .c, .d] { try? await e.loadBank(b, sounds: [:]) }
        state.sounds = state.sounds.filter { $0.key.bank == .a }
        e.bpm = 90; state.bpm = 90
        e.swing = 50; state.swing = 50
        state.bars = 4
        state.styleLabel = "CRATE"; state.sampleLabel = ""; state.chordsLabel = ""; state.scaleKey = nil
        state.selectFX(nil)
        current = nil
        loading = false
        save(state: state, asNew: true)
        state.addLog("PROJECT", "new \(currentName)", tint: .grey)
    }

    func delete(_ p: Project) {
        try? FileManager.default.removeItem(at: Self.url(p.id))
        if current?.id == p.id {
            current = nil
            savedSig = nil
            UserDefaults.standard.removeObject(forKey: Self.lastKey)
        }
        refresh()
    }

    /// "CRATE 03 · J DILLA"
    func autoName(_ state: AppState) -> String {
        let n = String(format: "%02d", list().count + 1)
        let style = state.styleLabel.trimmingCharacters(in: .whitespaces).uppercased()
        return style.isEmpty || style == "CRATE" ? "CRATE \(n)" : "CRATE \(n) · \(style)"
    }

    private func write(_ p: Project) {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do { try enc.encode(p).write(to: Self.url(p.id), options: .atomic) } catch {
            DebugLog.event("error", ["where": "project_save", "msg": "\(error)"])
        }
    }

    // MARK: Router  crate://project?cmd=new|save|open&name=…

    func handle(cmd: String, name: String?, state: AppState) async {
        switch cmd {
        case "new": await newProject(state: state)
        case "save", "saveas":
            save(state: state, name: name, asNew: cmd == "saveas" || (name != nil && name != current?.name))
        case "open":
            let all = list()
            let p = name.flatMap { n in all.first { $0.name.lowercased() == n.lowercased() || $0.id == n } } ?? all.first
            if let p { await load(p, into: state) }
        default: break
        }
    }
}
