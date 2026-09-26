import Foundation
import os

/// Keys and paths: environment (macOS harness, tests) first, then Info.plist (xcconfig-injected).
enum AppConfig {
    static func string(_ key: String) -> String? {
        if let v = ProcessInfo.processInfo.environment[key], !v.isEmpty { return v }
        if let v = Bundle.main.object(forInfoDictionaryKey: key) as? String, !v.isEmpty, !v.hasPrefix("$(") { return v }
        return nil
    }
    static var libraryURL: URL {
        URL(fileURLWithPath: string("CRATE_LIBRARY_PATH") ?? "/Users/shuhanzhang/duo-hack/library", isDirectory: true)
    }
    static var openAIKey: String? { string("OPENAI_API_KEY") }
    static var typesafeKey: String? { string("TYPESAFE_API_KEY") }

    /// Launch args like `-crateOffline 1` land in UserDefaults.
    static var offline: Bool { UserDefaults.standard.bool(forKey: "crateOffline") }
    static var debugRecord: Bool { UserDefaults.standard.bool(forKey: "crateDebugRecord") }
    static var debugLog: Bool { UserDefaults.standard.bool(forKey: "crateDebugLog") }
    /// `-crateNoPaywall 1` for live demos and recordings (the RevenueCat gate otherwise opens after the 3rd DIG).
    static var noPaywall: Bool { UserDefaults.standard.bool(forKey: "crateNoPaywall") }
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

    /// Move `midi` by whole octaves to within ±6 semitones of `root` (keeps pitch class).
    static func fold(_ midi: Int, near root: Int) -> Int {
        var m = midi
        while m - root > 6 { m -= 12 }
        while root - m > 6 { m += 12 }
        return m
    }
}
