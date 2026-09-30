import Foundation
import os

/// Keys and paths: environment (macOS harness, tests) first, then Info.plist (xcconfig-injected).
enum AppConfig {
    static func string(_ key: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty, !v.hasPrefix("$(") { return v }
        return nil
    }
    /// Sample library: `CRATE_LIBRARY_PATH` (dev override) → the copy bundled in the app → the dev Mac path.
    static var libraryURL: URL {
        if let p = string("CRATE_LIBRARY_PATH") { return URL(fileURLWithPath: p, isDirectory: true) }
        if let u = Bundle.main.url(forResource: "library", withExtension: nil) { return u }
        return URL(fileURLWithPath: "/Users/shuhanzhang/duo-hack/library", isDirectory: true)
    }
    /// AI calls go through our server (site/api/ai), which holds the OpenAI / TypeSafe keys.
    static var aiBase: URL { URL(string: string("CRATE_AI_BASE") ?? "https://crateduo.vercel.app/api/ai")! }
    static var appToken: String? { string("CRATE_APP_TOKEN") }
    /// Direct keys only for local experiments via environment variables; never in the app bundle.
    static var openAIKey: String? { ProcessInfo.processInfo.environment["OPENAI_API_KEY"].flatMap { $0.isEmpty ? nil : $0 } }
    static var typesafeKey: String? { ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"].flatMap { $0.isEmpty ? nil : $0 } }

    /// Launch args like `-crateOffline 1` land in UserDefaults.
    static var offline: Bool { UserDefaults.standard.bool(forKey: "crateOffline") }
    static var debugRecord: Bool { UserDefaults.standard.bool(forKey: "crateDebugRecord") }
    static var debugLog: Bool { UserDefaults.standard.bool(forKey: "crateDebugLog") }
    /// Dev only (`-crateSilentAudio 1`): run the engine with no audio hardware (manual rendering), for layout
    /// checks when the simulator can't reach the Mac's output (lid closed → CoreAudio RPC timeouts at launch).
    static var silentAudio: Bool { UserDefaults.standard.bool(forKey: "crateSilentAudio") }
}

/// One JSON line per event (stdout + os_log) for the self-test harness. Enabled with `-crateDebugLog 1`.
enum DebugLog {
    static let logger = Logger(subsystem: "com.shuhan.crate", category: "event")
    static let enabled = AppConfig.debugLog

    static func event(_ name: String, _ fields: [String: Any] = [:]) {
        guard enabled else { return }
        var obj = fields
        obj["event"] = name
        obj["t"] = (Date().timeIntervalSince1970 * 1000).rounded() / 1000
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
              let line = String(data: data, encoding: .utf8) else { return }
        print("CRATE " + line)
        logger.info("\(line, privacy: .public)")
    }
}

enum Music {
    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static func name(_ midi: Int) -> String { noteNames[((midi % 12) + 12) % 12] + String(midi / 12 - 1) }

    /// "Am", "F#", "Ebm", "A minor", "C major" → (tonic pitch class, isMinor)
    static func parseKey(_ key: String?) -> (pc: Int, minor: Bool)? {
        guard var k = key?.trimmingCharacters(in: .whitespaces), !k.isEmpty else { return nil }
        let lower = k.lowercased()
        let minor = lower.hasSuffix("m") && !lower.hasSuffix("maj") || lower.contains("min")
        k = k.replacingOccurrences(of: " ", with: "")
        let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard let first = k.first, var pc = letters[Character(first.uppercased())] else { return nil }
        if k.count > 1 {
            let acc = k[k.index(after: k.startIndex)]
            if acc == "#" || acc == "♯" { pc += 1 } else if acc == "b" || acc == "♭" { pc -= 1 }
        }
        return ((pc + 12) % 12, minor)
    }

    /// Scale pitch classes for scale lock.
    static func scale(pc: Int, minor: Bool) -> [Int] {
        let steps = minor ? [0, 2, 3, 5, 7, 8, 10] : [0, 2, 4, 5, 7, 9, 11]
        return steps.map { (pc + $0) % 12 }
    }

    /// Nearest pitch inside the key's scale (ties resolve downward).
    static func snap(_ midi: Int, keyPC: Int, minor: Bool) -> Int {
        let pcs = Set(scale(pc: keyPC, minor: minor))
        func pc(_ m: Int) -> Int { ((m % 12) + 12) % 12 }
        if pcs.contains(pc(midi)) { return midi }
        for d in 1...6 {
            if pcs.contains(pc(midi - d)) { return midi - d }
            if pcs.contains(pc(midi + d)) { return midi + d }
        }
        return midi
    }

    /// Move `midi` by whole octaves to within ±6 semitones of `root` (keeps pitch class).
    static func fold(_ midi: Int, near root: Int) -> Int {
        var m = midi
        while m - root > 6 { m -= 12 }
        while root - m > 6 { m += 12 }
        return m
    }
}
