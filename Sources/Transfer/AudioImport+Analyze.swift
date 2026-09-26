import Foundation

/// Non-demo imports: on-device analysis (AudioAnalyzer, Sources/Library) → bpm/key/16 slices for the auto-flip.
extension AudioImport {
    /// Analysis as a synthetic demo entry (flip tempo = analyzed bpm folded into 84–100) + the end of the chopped window.
    @MainActor static func analyzed(_ audio: ImportedAudio, state: AppState) async -> (sample: DemoSample, end: Double)? {
        let t0 = Date()
        let url = audio.url
        // Long files: the first ~10 s (a 4-bar window at most tempos); short loops: the whole file.
        let window: Double? = audio.duration > 12 ? 10 : nil
        let result = await Task.detached(priority: .userInitiated) { () -> (Double?, String?, [Double]?)? in
            guard let a = try? AudioAnalyzer.analyze(url: url, start: 0, duration: window) else { return nil }
            let bpm: Double? = a.bpm
            let key: String? = a.key
            let slices: [Double]? = a.slices16Sec
            return (bpm, key, slices)
        }.value
        guard let (bpmValue, key, rawSlices) = result, let slices = rawSlices, slices.count >= 16 else { return nil }
        let end = min(audio.duration, window ?? audio.duration)
        let starts = Array(slices.prefix(16)).filter { $0 >= 0 && $0 < end }
        guard starts.count == 16 else { return nil }
        let bpm = (bpmValue ?? 90).isFinite && (bpmValue ?? 0) > 0 ? bpmValue! : 90
        var flip = bpm
        while flip > 100 { flip /= 2 }
        while flip < 84, flip * 2 <= 100 { flip *= 2 }
        flip = min(100, max(84, flip))
        let ms = Int((Date().timeIntervalSince(t0) * 1000).rounded())
        state.addLog("ANALYZE", "▸ \(Int(bpm.rounded())) BPM · \(key ?? "?") · 16 slices (\(ms) ms)", ms: ms, tint: .blue)
        DebugLog.event("analyze", ["bpm": bpm, "key": key ?? "", "flipBpm": flip, "ms": ms, "window": window ?? audio.duration])
        return (DemoSample(match: "", name: audio.name, bpm: bpm, key: key, bars: 4, durationSec: end, slicesSec: starts,
                           flipBpm: flip.rounded(), chords: nil), end)
    }
}
