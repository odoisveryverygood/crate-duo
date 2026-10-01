import AVFoundation
import Foundation

/// ● REC from stop: one bar of clicks, then play + record. The click is a tiny generated WAV played by AVAudioPlayer
/// on the device clock, outside the sampler engine's graph.
@MainActor
final class CountIn {
    static let shared = CountIn()
    private var players: [AVAudioPlayer] = []
    private var task: Task<Void, Never>?
    var isCounting: Bool { task != nil }

    /// `tick(n)` on each beat (n = beats left, 4…1), then `done()` on the downbeat. Restarting cancels the last one.
    func start(bpm: Double, beats: Int = 4, tick: @escaping (Int) -> Void, done: @escaping () -> Void) {
        cancel()
        let beat = 60 / max(40, min(220, bpm))
        players = AppConfig.silentAudio ? [] : (0..<beats).compactMap { i in
            guard let url = Self.clickURL(accent: i == 0), let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
            p.volume = i == 0 ? 0.9 : 0.6
            p.prepareToPlay()
            return p
        }
        if let first = players.first {
            let t0 = first.deviceCurrentTime + 0.05
            for (i, p) in players.enumerated() { p.play(atTime: t0 + Double(i) * beat) }
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            for i in 0..<beats {
                guard !Task.isCancelled else { return }
                tick(beats - i)
                try? await Task.sleep(for: .seconds(beat))
            }
            guard !Task.isCancelled else { return }
            self?.task = nil
            done()
        }
        DebugLog.event("count_in", ["bpm": bpm, "beats": beats])
    }

    func cancel() {
        task?.cancel()
        task = nil
        players.forEach { $0.stop() }
        players = []
    }

    /// 30 ms decaying sine (2 kHz accent, 1.3 kHz otherwise), written once to Caches.
    private static func clickURL(accent: Bool) -> URL? {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(accent ? "crate-click-hi.caf" : "crate-click-lo.caf")
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let sr = 44_100.0, n = AVAudioFrameCount(sr * 0.03), f = accent ? 2000.0 : 1300.0
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n), let ch = buf.floatChannelData else { return nil }
        buf.frameLength = n
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            ch[0][i] = Float(sin(2 * .pi * f * t) * exp(-t * 140) * 0.8)
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
            try file.write(from: buf)
            return url
        } catch {
            return nil
        }
    }
}
