import AVFoundation
import Foundation

extension AudioEngine {
    /// Records four bars from the existing master-output tap, starting on the next bar.
    /// The engine keeps playing while the WAV is written.
    func bounce(bars: Int = 4, title: String) async throws -> URL {
        guard bars > 0, stateLock.withLock({ shared.running && shared.playing }) else {
            throw BounceError.notPlaying
        }
        guard bounceLock.withLock({ bounceWriter == nil }) else { throw BounceError.inProgress }

        let tempo = max(30, bpm)
        let step = position().truncatingRemainder(dividingBy: 16)
        let wait = step < 0.01 ? 0 : (16 - step) * 60 / tempo / 4
        if wait > 0 { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
        try Task.checkCancellation()

        let seconds = Double(bars) * 4 * 60 / tempo
        let files = FileManager.default
        let docs = files.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = docs.appendingPathComponent("bounces", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let slug = String(title.lowercased().map { c in c.isLetter || c.isNumber ? c : "-" })
            .split(separator: "-").joined(separator: "-")
        let base = String((slug.isEmpty ? "crate" : slug).prefix(48))
        var url = directory.appendingPathComponent(base + ".wav")
        var n = 2
        while files.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(base)-\(n).wav")
            n += 1
        }

        let sr = engine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        guard let writer = WavWriter(url: url, sampleRate: sr, maxSeconds: seconds + 0.5) else {
            throw BounceError.cannotWrite
        }
        let installed = bounceLock.withLock { () -> Bool in
            guard bounceWriter == nil else { return false }
            bounceWriter = writer
            return true
        }
        guard installed else {
            try? files.removeItem(at: url)
            throw BounceError.inProgress
        }
        DebugLog.event("bounce_start", ["bars": bars, "path": url.path])

        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        } catch {
            bounceLock.withLock { bounceWriter = nil }
            wavQueue.sync {}
            try? files.removeItem(at: url)
            throw error
        }
        bounceLock.withLock { bounceWriter = nil }
        wavQueue.sync {}
        guard writer.dataBytes > 44 else {
            try? files.removeItem(at: url)
            throw BounceError.empty
        }
        DebugLog.event("bounce_done", ["path": url.path, "bytes": writer.dataBytes])
        return url
    }

    enum BounceError: LocalizedError {
        case notPlaying, inProgress, cannotWrite, empty

        var errorDescription: String? {
            switch self {
            case .notPlaying: return "Start playback before bouncing."
            case .inProgress: return "A bounce is already running."
            case .cannotWrite: return "Could not create the WAV file."
            case .empty: return "The bounce recorded no audio."
            }
        }
    }
}
