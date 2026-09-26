#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
: "${CRATE_VERIFY_DEVICE:?Set CRATE_VERIFY_DEVICE to a booted iOS 27.1 simulator}"
build_dir=$(mktemp -d /tmp/crate-outer-render.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
python3 - "$build_dir" <<'PY'
import os, pathlib, plistlib, shutil, subprocess, sys
root = pathlib.Path.cwd()
build = pathlib.Path(sys.argv[1])
app = build/'Crate.app'
app.mkdir()
(build/'PreviewApp.swift').write_text(r'''import SwiftUI
import UIKit

/// Offline visual fixture; compiled only by render.sh, never part of the app target.
@main
struct OuterPreviewApp: App {
    @State private var state = AppState(engine: MockEngine())
    var body: some Scene {
        WindowGroup {
            CompactView(state: state)
                .task { await render() }
        }
    }

    @MainActor private func render() async {
        state.styleLabel = "J DILLA"
        state.sampleLabel = "NUJ KEYS POCKET · JAZZ HOP"
        state.lastPerform = "ROLL"
        state.performOn = true
        state.addLog("KIT", "Dusty Dilla drums", ms: 3)
        state.addLog("SAMPLE", "Piano in G# · 100 BPM", ms: 120)
        for bank in Bank.allCases {
            for index in 0..<16 {
                state.sounds[PadID(bank, index)] = PadSound(id: "fixture-\(bank.letter)-\(index)", name: bank == .a ? BankA.slots[index].uppercased() : "CHOP \(index + 1)", category: bank == .a ? .kick : .chop, fileURL: URL(fileURLWithPath: "/fixture.wav"))
            }
        }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fixtures: [(String, AnyView, CGSize)] = [
            ("compact-portrait", AnyView(CompactView(state: state)), CGSize(width: 466, height: 678)),
            ("compact-landscape", AnyView(CompactView(state: state)), CGSize(width: 678, height: 466)),
            ("crowd-portrait", AnyView(CrowdStageView(state: state)), CGSize(width: 466, height: 678)),
            ("crowd-landscape", AnyView(CrowdStageView(state: state)), CGSize(width: 678, height: 466)),
            ("crowd-rotated", AnyView(CrowdStageView(state: state, rotate: .degrees(90))), CGSize(width: 678, height: 466)),
            ("now-playing", AnyView(NowPlayingCard(state: state).padding(20).background(Color.black)), CGSize(width: 466, height: 620))
        ]
        var report = [String]()
        for name in ["Inter-Light", "Inter-Regular", "Inter-Medium", "Inter-SemiBold"] {
            report.append("\(UIFont(name: name, size: 20) != nil ? "PASS" : "FAIL") font \(name)")
        }
        // UIKit hosting captures the real prompt editor too (ImageRenderer omits platform views).
        for (name, view, size) in fixtures {
            let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height).ignoresSafeArea())
            host.view.frame = CGRect(origin: .zero, size: size)
            host.view.backgroundColor = .black
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(120))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            do {
                guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: folder.appendingPathComponent(name + ".png"))
                report.append("PASS rendered \(name) \(Int(size.width))x\(Int(size.height))")
            } catch { report.append("FAIL \(name): \(error)") }
        }
        await OuterFlowChecks.run()
        try? report.joined(separator: "\n").write(to: folder.appendingPathComponent("outer-render.txt"), atomically: true, encoding: .utf8)
    }
}
''')
(build/'FlowChecks.swift').write_text(r'''import Foundation
import AVFoundation
import UniformTypeIdentifiers

@MainActor
enum OuterFlowChecks {
    static func run() async {
        var results: [String] = []
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let root = docs.appendingPathComponent("verification-\(UUID())")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            func check(_ condition: Bool, _ label: String) throws {
                if !condition { throw NSError(domain: "OuterFlowChecks", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
            }
            let fixture = root.appendingPathComponent("tone.wav")
            let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
            let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000)!
            pcm.frameLength = 48000
            for i in 0..<48000 { pcm.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 220 / 48000) * 0.2) }
            do { let file = try AVAudioFile(forWriting: fixture, settings: format.settings); try file.write(from: pcm) }
            func receive(_ url: URL, pad: PadID) async throws -> ImportedAudio {
                let provider = NSItemProvider(contentsOf: url)!
                let result: Result<ImportedAudio, Error> = await withCheckedContinuation { continuation in
                    if !AudioImport.receive([provider], at: pad, completion: { continuation.resume(returning: $0) }) {
                        continuation.resume(returning: .failure(AudioImport.ImportError.noFile))
                    }
                }
                return try result.get()
            }
            let imported = try await receive(fixture, pad: PadID(.a, 2))
            try check(imported.url != fixture && FileManager.default.fileExists(atPath: imported.url.path), "provider temporary copy persists")
            try check(FileManager.default.fileExists(atPath: fixture.path), "source preserved")
            let duplicate = try await receive(fixture, pad: PadID(.a, 2))
            try check(duplicate.url != imported.url, "unique copies")
            let invalid = root.appendingPathComponent("invalid.wav")
            try Data("not audio".utf8).write(to: invalid)
            let importDirectory = docs.appendingPathComponent("imported")
            let before = Set(try FileManager.default.contentsOfDirectory(atPath: importDirectory.path))
            var rejected = false
            do { _ = try await receive(invalid, pad: PadID(.a, 2)) } catch { rejected = true }
            try check(rejected, "invalid audio rejected")
            try check(before == Set(try FileManager.default.contentsOfDirectory(atPath: importDirectory.path)), "invalid copy removed")
            let engine = AudioEngine()
            try engine.start()
            engine.bpm = 89
            try await engine.loadBank(.a, sounds: [0: PadSound(id: "tone", name: "tone", category: .kick, fileURL: fixture)])
            let state = AppState(engine: engine)
            await AudioImport.loadOnPad(imported, state: state)
            try check(engine.sound(for: PadID(.a, 0))?.id == "tone", "neighbour pad preserved")
            try check(engine.sound(for: PadID(.a, 2))?.fileURL == imported.url, "target replaced")
            try check(engine.sound(for: PadID(.a, 2))?.rootNote == 60, "import pitch root")
            await AudioImport.chop16(imported, state: state)
            try check(state.bank == .d, "chops select bank D")
            for i in 0..<16 {
                let sound = engine.sound(for: PadID(.d, i))
                try check(sound?.start == Double(i) / 16 && sound?.end == Double(i + 1) / 16, "slice bounds and loaded pad \(i)")
                try check(!engine.waveform(PadID(.d, i), points: 16).isEmpty, "decoded slice \(i)")
            }
            results.append("PASS import: NSItemProvider copy lifetime, unique files, invalid cleanup, preserved neighbouring pad, pitch root and all 16 real-engine chops")
            let orchestrator = Orchestrator(state: state, library: LibraryStore())
            let flipReport = await orchestrator.dig("flip the sample")
            let importedEvents = engine.pattern.lanes.keys.filter { $0.bank == .d }.count + engine.pattern.notes.keys.filter { $0.bank == .d }.count
            results.append("\(importedEvents > 0 ? "PASS" : "FAIL") import → chop → flip: parsed scope \(flipReport.plan.scope), Bank D event lanes \(importedEvents); imported sounds remain \(state.sounds.keys.filter { $0.bank == .d }.count)")
            engine.stop()
            engine.bpm = 89

            var pattern = Pattern.empty
            pattern.bars = 4
            pattern.lanes[PadID(.a, 0)] = stride(from: 0, to: 64, by: 4).map { Hit(step: $0, velocity: 110) }
            engine.setPattern(pattern, timing: .now)
            engine.play()
            try await Task.sleep(for: .milliseconds(300))
            let output = try await engine.bounce(bars: 4, title: "verification")
            let file = try AVAudioFile(forReading: output)
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            try check(abs(seconds - 960.0 / 89) < 0.001, "four bars at 89 BPM, got \(seconds)")
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buffer)
            let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
            try check(peak > 0.01, "bounce not silent, peak \(peak)")
            results.append("PASS bounce: real master tap, finalized WAV, \(seconds) seconds (four bars), peak \(peak)")
            func bounceFiles() throws -> Set<String> {
                Set(try FileManager.default.contentsOfDirectory(atPath: docs.appendingPathComponent("bounces").path))
            }
            let completedFiles = try bounceFiles()
            let cancellation = Task { try await engine.bounce(title: "cancelled") }
            try await Task.sleep(for: .milliseconds(300))
            var duplicateRejected = false
            do { _ = try await engine.bounce(title: "duplicate") } catch { duplicateRejected = true }
            try check(duplicateRejected, "concurrent bounce rejected")
            cancellation.cancel()
            var cancelled = false
            do { _ = try await cancellation.value } catch { cancelled = true }
            try check(cancelled && (try bounceFiles()) == completedFiles, "cancel leaves no partial file")
            let stopped = Task { try await engine.bounce(title: "stopped") }
            try await Task.sleep(for: .seconds(3))
            engine.stop()
            var stopRejected = false
            do { _ = try await stopped.value } catch { stopRejected = true }
            try check(stopRejected && (try bounceFiles()) == completedFiles, "stop invalidates capture")
            engine.play()
            try await Task.sleep(for: .milliseconds(200))
            let tempo = Task { try await engine.bounce(title: "tempo") }
            try await Task.sleep(for: .milliseconds(200))
            engine.bpm = 120
            var tempoRejected = false
            do { _ = try await tempo.value } catch { tempoRejected = true }
            try check(tempoRejected && (try bounceFiles()) == completedFiles, "tempo invalidates capture")
            results.append("PASS bounce lifecycle: concurrent rejection, task cancellation, playback stop, tempo change; no partial exports")
            engine.stop()

        } catch { results.append("FAIL \(error)") }
        let text = results.joined(separator: "\n")
        try? text.write(to: docs.appendingPathComponent("outer-flow-checks.txt"), atomically: true, encoding: .utf8)
        print(text)
    }
}
''')
files = [str(p) for p in sorted((root/'Sources').rglob('*.swift')) if p.name != 'CrateApp.swift']
if ref := os.environ.get('CRATE_PAD_REF'):
    for name in ['PadGridView.swift','RecordPad.swift']:
        (build/name).write_bytes(subprocess.check_output(['git','show',ref + ':Sources/UI/' + name]))
    files = [p for p in files if pathlib.Path(p).name not in ['PadGridView.swift','RecordPad.swift']]
    files += [str(build/'PadGridView.swift'),str(build/'RecordPad.swift')]
subprocess.run(['xcrun','swiftc','-sdk',os.environ['SDKROOT'],'-target','arm64-apple-ios27.1-simulator','-swift-version','5','-parse-as-library',*files,str(build/'PreviewApp.swift'),str(build/'FlowChecks.swift'),'-o',str(app/'Crate')], check=True)
p = plistlib.loads((root/'Resources/Info.plist').read_bytes())
p.update(CFBundleExecutable='Crate', CFBundleIdentifier='com.shuhan.crate.outerpreview', CFBundleName='Outer Preview', CFBundleShortVersionString='0.1', CFBundleVersion='1', MinimumOSVersion='27.1', CFBundleSupportedPlatforms=['iPhoneSimulator'], UIDeviceFamily=[1])
for key in ['OPENAI_API_KEY','TYPESAFE_API_KEY','REVENUECAT_API_KEY','CRATE_LIBRARY_PATH','CFBundleURLTypes']: p.pop(key, None)
(app/'Info.plist').write_bytes(plistlib.dumps(p))
for file in (root/'Resources/Fonts').iterdir():
    if file.is_file(): shutil.copy2(file,app/file.name)
shutil.copytree(root/'Resources/DefaultKit',app/'DefaultKit')
for file in (root/'Resources/AI').iterdir():
    if file.is_file(): shutil.copy2(file,app/file.name)
subprocess.run(['codesign','--force','--sign','-',str(app)], check=True)
PY
xcrun simctl terminate "$CRATE_VERIFY_DEVICE" com.shuhan.crate.outerpreview >/dev/null 2>&1 || true
xcrun simctl install "$CRATE_VERIFY_DEVICE" "$build_dir/Crate.app"
container=$(xcrun simctl get_app_container "$CRATE_VERIFY_DEVICE" com.shuhan.crate.outerpreview data)
rm -f "$container/Documents/outer-render.txt"
xcrun simctl launch "$CRATE_VERIFY_DEVICE" com.shuhan.crate.outerpreview -crateOffline 1 -crateNoPaywall 1
for attempt in {1..60}; do
    if [[ -f "$container/Documents/outer-render.txt" ]]; then
        cat "$container/Documents/outer-render.txt"
        cat "$container/Documents/outer-flow-checks.txt"
        echo "Images: $container/Documents"
        if grep -q '^FAIL' "$container/Documents/outer-render.txt" "$container/Documents/outer-flow-checks.txt"; then exit 1; fi
        exit 0
    fi
    sleep 1
done
echo 'FAIL: render timeout' >&2
exit 1
