#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun swiftc -typecheck -sdk "$sdk" -target arm64-apple-ios27.1-simulator -swift-version 5 Sources/Core/*.swift Sources/UI/Theme.swift Sources/Sampler/*.swift
xcrun swiftc -typecheck -D DEBUG -sdk "$sdk" -target arm64-apple-ios27.1-simulator -swift-version 5 Sources/Core/*.swift Sources/UI/Theme.swift Sources/Sampler/*.swift
cat > "$work/ChopperChecks.swift" <<'SWIFT'
import Foundation
import AVFoundation

@main struct ChopperChecks {
    static func main() throws {
        func checkCoverage(_ slices: [SampleSlice], duration: Double) {
            precondition(!slices.isEmpty && slices.count <= 16)
            precondition(slices.first!.start == 0 && slices.last!.end == duration)
            for slice in slices { precondition(slice.start.isFinite && slice.end > slice.start) }
            for pair in zip(slices, slices.dropFirst()) { precondition(pair.0.end == pair.1.start) }
        }
        let equal = SampleChopper.slices(rms: [], duration: 4.2, chop: .regions16)
        precondition(equal.count == 16)
        checkCoverage(equal, duration: 4.2)
        precondition(SampleChopper.slices(rms: [], duration: .nan, chop: .regions16).isEmpty)
        precondition(SampleChopper.slices(rms: [], duration: 0, chop: .threshold).isEmpty)
        let silence = SampleChopper.slices(rms: Array(repeating: 0, count: 100), duration: 1, chop: .threshold)
        precondition(silence == [SampleSlice(start: 0, end: 1)])
        var rms = Array(repeating: 0.001, count: 100)
        for index in [10, 13, 30, 60] { rms[index] = 0.7 }
        let transient = SampleChopper.slices(rms: rms, duration: 1, chop: .threshold)
        precondition(transient.map(\.start) == [0, 0.1, 0.3, 0.6])
        checkCoverage(transient, duration: 1)
        let sustained = SampleChopper.slices(rms: Array(repeating: 0.5, count: 100), duration: 1, chop: .threshold)
        precondition(sustained.count == 1)
        var many = Array(repeating: 0.0, count: 1000)
        for index in stride(from: 10, to: 990, by: 10) { many[index] = 0.9 }
        let limited = SampleChopper.slices(rms: many, duration: 10, chop: .threshold)
        precondition(limited.count == 16)
        checkCoverage(limited, duration: 10)
        let invalid = SampleChopper.slices(rms: [.nan, .infinity, -1, 0], duration: 1, chop: .threshold)
        checkCoverage(invalid, duration: 1)

        // Exercise actual WAV decoding: mono 44.1kHz, 16-bit PCM, partial final RMS window.
        let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("synthetic.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_223)!
        buffer.frameLength = 44_223
        for frame in 0..<Int(buffer.frameLength) {
            let t = Double(frame) / 44_100
            let loud = (t >= 0.2 && t < 0.23) || (t >= 0.6 && t < 0.63)
            buffer.floatChannelData![0][frame] = loud ? Float(0.8 * sin(Double(frame) * 0.31)) : 0
        }
        do {
            let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false])
            try file.write(from: buffer)
        }
        let fileRegions = try SampleChopper.analyze(url: url, chop: .regions16)
        precondition(fileRegions.slices.count == 16)
        checkCoverage(fileRegions.slices, duration: fileRegions.duration)
        let fileTransients = try SampleChopper.analyze(url: url, chop: .threshold)
        precondition(fileTransients.slices.count == 3)
        precondition(abs(fileTransients.slices[1].start - 0.2) < 0.011)
        precondition(abs(fileTransients.slices[2].start - 0.6) < 0.011)
        checkCoverage(fileTransients.slices, duration: fileTransients.duration)
        do {
            _ = try SampleChopper.analyze(url: url.appendingPathExtension("missing"), chop: .threshold)
            preconditionFailure("Missing file must fail")
        } catch { }
        print("PASS: equal regions, transient spacing, silence, sustained signal, slice cap, invalid input, real WAV decoding and missing file")
    }
}
SWIFT
xcrun swiftc -swift-version 5 Sources/Sampler/SampleChopper.swift "$work/ChopperChecks.swift" -o "$work/checks"
"$work/checks" "$work"
echo 'PASS: iOS 27.1 normal and DEBUG typechecks; no simulator or microphone used'
cat > "$work/LifecycleChecks.swift" <<'SWIFT'
import Foundation
@main struct LifecycleChecks {
    @MainActor static func main() async throws {
        var hold = SampleHoldState()
        precondition(!hold.reset())
        precondition(hold.begin())
        precondition(!hold.begin())
        precondition(hold.finish())
        precondition(!hold.reset(), "Normal release must not cancel the pending stop")
        precondition(hold.begin())
        precondition(hold.reset(), "Gesture cancellation must discard, not chop")
        precondition(!hold.finish(), "A stale end after cancellation must do nothing")
        precondition(hold.begin())
        precondition(hold.finish())
        precondition(!hold.reset())

        let engine = MockEngine()
        let state = AppState(engine: engine)
        let url = URL(fileURLWithPath: "/synthetic.wav")
        let first = PadSound(id: "rec-1", name: "REC 01", category: .chop, fileURL: url)
        let second = PadSound(id: "rec-2", name: "REC 02", category: .chop, fileURL: url)
        let old = PadSound(id: "old", name: "OLD", category: .chop, fileURL: url)
        state.sounds[PadID(.a, 0)] = old
        state.sounds[PadID(.d, 15)] = old
        let expected = [0: first, 1: second]
        try await engine.loadBank(.d, sounds: expected)
        precondition(SampleBankCommit.publish(expected, to: state))
        precondition(state.bank == .d && state.selectedPad == PadID(.d, 0))
        precondition(state.sounds[PadID(.d, 15)] == nil)
        precondition(state.sounds[PadID(.a, 0)] == old)
        // Reproduce the engine's silent partial decode: await returns, one pad is absent.
        state.bank = .b
        state.selectedPad = PadID(.b, 7)
        try await engine.loadBank(.d, sounds: [0: first])
        precondition(!SampleBankCommit.publish(expected, to: state))
        precondition(state.sounds[PadID(.d, 1)] == nil, "Must not display an unloaded chop")
        precondition(state.bank == .b && state.selectedPad == PadID(.b, 7))
        // Another bank loader supersedes this take; preserve the actual newer bank.
        try await engine.loadBank(.d, sounds: [4: old])
        precondition(!SampleBankCommit.publish(expected, to: state))
        precondition(state.sounds[PadID(.d, 4)] == old && state.sounds[PadID(.d, 0)] == nil)
        precondition(state.sounds[PadID(.a, 0)] == old)
        try await engine.loadBank(.d, sounds: [:])
        precondition(!SampleBankCommit.publish(expected, to: state))
        precondition(state.sounds.keys.allSatisfy { $0.bank != .d })
        print("PASS: release/cancellation/repeated gestures; successful, partial, empty and superseded bank loads; other banks preserved")
    }
}
SWIFT
xcrun swiftc -swift-version 5 Sources/Core/*.swift Sources/Sampler/SampleHoldState.swift Sources/Sampler/SampleBankCommit.swift "$work/LifecycleChecks.swift" -o "$work/lifecycle-checks"
"$work/lifecycle-checks"
