import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Pad line (lid)

/// The selected pad on the lid: bank tag, name, ‹ › (the next library sound of the same type) and EDIT.
/// While SAMPLE is armed it shows the mic; while a pad is held it shows the take; with the FX layer up, what to tap.
struct PadLine: View {
    let state: AppState

    var body: some View {
        let ui = CrateUI.shared
        HStack(spacing: 8) {
            if let pad = ui.recordingPad {
                tag("● REC", Theme.live)
                Text("\(pad.bank.letter)\(pad.number) · \(String(format: "%.1f", ui.sampler?.seconds ?? 0)) s · LET GO TO STOP")
                    .font(Theme.inter(9, 600)).tracking(0.9).foregroundStyle(Theme.lidInk).lineLimit(1)
                Spacer(minLength: 6)
                MicMeter(level: ui.sampler?.level ?? 0).frame(width: 70, height: 6)
            } else if ui.sampleArmed {
                tag("MIC", Theme.live)
                Text("HOLD A PAD TO RECORD INTO IT")
                    .font(Theme.inter(9, 600)).tracking(0.9).foregroundStyle(Theme.lidInk).lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                chip("CANCEL", id: "sample-cancel") { ui.sampleArmed = false }
            } else if ui.fxLayer {
                tag("FX", Theme.live)
                Text("TAP A PAD TO PICK AN EFFECT")
                    .font(Theme.inter(9, 600)).tracking(0.9).foregroundStyle(Theme.lidInk).lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 6)
                Text(state.fx?.label ?? "PUNCH").font(Theme.mono(8)).foregroundStyle(Theme.lidGrey1).lineLimit(1)
            } else {
                let pad = state.selectedPad
                let sound = state.sound(pad)
                tag("\(pad.bank.letter)\(pad.number)", Theme.bank(pad.bank))
                Text(sound?.name ?? "EMPTY PAD")
                    .font(Theme.inter(10, 600)).tracking(0.8)
                    .foregroundStyle(sound == nil ? Theme.lidGrey1 : Theme.lidInk)
                    .lineLimit(1).truncationMode(.tail)
                    .accessibilityIdentifier("pad-name")
                if Orchestrator.current?.canSwap(pad) == true {
                    chip("‹", id: "pad-prev") { swap(pad, -1) }
                    chip("›", id: "pad-next") { swap(pad, 1) }
                }
                Spacer(minLength: 6)
                if sound != nil {
                    chip(ui.editorOpen ? "DONE" : "EDIT", id: "pad-edit", filled: ui.editorOpen) {
                        ui.editorOpen.toggle()
                        DebugLog.event("editor", ["open": ui.editorOpen])
                    }
                }
            }
        }
        .frame(height: 22)
    }

    private func swap(_ pad: PadID, _ step: Int) {
        Task { @MainActor in await Orchestrator.current?.swapSound(pad, step: step) }
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(Theme.inter(8, 700)).tracking(0.5)
            .foregroundStyle(Color.black)
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(RoundedRectangle(cornerRadius: 3).fill(color))
            .fixedSize()
    }

    private func chip(_ label: String, id: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.inter(label.count == 1 ? 11 : 7, 600)).tracking(label.count == 1 ? 0 : 0.7)
                .foregroundStyle(filled ? Color.black : Theme.chipText)
                .frame(minWidth: label.count == 1 ? 26 : nil)
                .padding(.horizontal, label.count == 1 ? 0 : 9)
                .frame(height: 21)
                .background(RoundedRectangle(cornerRadius: 4).fill(filled ? Theme.lidInk : Color.black))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.chipStroke, lineWidth: 0.5).opacity(filled ? 0 : 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(ChipPressStyle())
        .accessibilityIdentifier(id)
        .accessibilityLabel(label == "‹" ? "Previous sound" : label == "›" ? "Next sound" : label)
    }
}

/// The mic input level while SAMPLE records (orange cells, red at the top).
struct MicMeter: View {
    var level: Double
    var body: some View {
        GeometryReader { g in
            let cells = 14
            let lit = Int((pow(min(1, max(0, level)), 0.5) * Double(cells)).rounded())
            HStack(spacing: 2) {
                ForEach(0..<cells, id: \.self) { i in
                    Rectangle().fill(i < lit ? (i > cells - 3 ? Theme.red : Theme.live) : Theme.lidGrey3)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

// MARK: - Pad editor (lid main area)

/// EDIT: the selected pad's sound, big. Drag its two edges. A slice of a song is
/// shown in context with its neighbours; moving its edge moves theirs (they share the line). DONE on the pad line closes.
struct PadEditorView: View {
    let state: AppState
    @State private var dragging: DragEdge? = nil
    enum DragEdge { case start, end }

    var body: some View {
        let ui = CrateUI.shared
        let pad = state.selectedPad
        if let s = state.sound(pad), let orch = Orchestrator.current {
            let dur = max(0.01, orch.sourceDuration(s))
            let start = ui.editPreviewStart ?? s.start
            let end = ui.editPreviewEnd ?? (s.end ?? dur)
            let edges = orch.sharedEdges(pad)
            let slice = edges.prev != nil || edges.next != nil
            let win = Self.window(start: s.start, end: s.end ?? dur, duration: dur, slice: slice)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(String(format: "%.2f – %.2f s", start, end))
                        .font(Theme.mono(11)).monospacedDigit().foregroundStyle(Theme.lidInk)
                    Text(slice ? "SLICE \(pad.number) · DRAG THE EDGES" : "DRAG THE EDGES")
                        .fieldLabel().foregroundStyle(Theme.lidGrey1).lineLimit(1)
                    Spacer(minLength: 0)
                }
                GeometryReader { geo in
                    let inset: CGFloat = 9   // the edge grips stay whole at the very start / end of the sound
                    let w = geo.size.width - inset * 2
                    let x = { (t: Double) -> CGFloat in
                        inset + CGFloat((t - win.lowerBound) / max(0.001, win.upperBound - win.lowerBound)) * w
                    }
                    let t = { (px: CGFloat) -> Double in
                        win.lowerBound + Double((px - inset) / max(1, w)) * (win.upperBound - win.lowerBound)
                    }
                    ZStack(alignment: .topLeading) {
                        FileWaveCanvas(url: s.fileURL, window: win, duration: dur, start: start, end: end,
                                       tint: Theme.bank(pad.bank), marks: slice ? sliceMarks(pad) : [])
                            .padding(.horizontal, inset)
                        handle(at: x(start), height: geo.size.height, color: Theme.bank(pad.bank))
                        handle(at: x(end), height: geo.size.height, color: Theme.bank(pad.bank))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                if dragging == nil {
                                    let ds = abs(g.startLocation.x - x(start)), de = abs(g.startLocation.x - x(end))
                                    guard min(ds, de) < 44 else { return }
                                    dragging = ds <= de ? .start : .end
                                }
                                let v = min(win.upperBound, max(win.lowerBound, t(g.location.x)))
                                if dragging == .start { ui.editPreviewStart = min(v, end - 0.02) }
                                else { ui.editPreviewEnd = max(v, start + 0.02) }
                            }
                            .onEnded { g in
                                let edge = dragging
                                dragging = nil
                                if edge == nil, abs(g.translation.width) < 4 { state.hit(pad); return }
                                commit(pad)
                            }
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("pad-editor")
                .accessibilityLabel("Pad editor")
                .accessibilityValue(String(format: "start %.2f seconds, end %.2f seconds", start, end))
            }
        } else {
            Text("EMPTY PAD · TAP SAMPLE AND HOLD A PAD, OR ＋ A SONG")
                .fieldLabel().foregroundStyle(Theme.lidGrey1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// What the editor shows: a slice in context (it and about a slice either side), a one-shot or take whole.
    static func window(start: Double, end: Double, duration: Double, slice: Bool) -> ClosedRange<Double> {
        guard slice else { return 0...duration }
        let len = max(0.05, end - start)
        let lo = max(0, start - len * 1.2), hi = min(duration, end + len * 1.2)
        return lo...max(lo + 0.1, hi)
    }

    private func sliceMarks(_ pad: PadID) -> [Double] {
        guard let s = state.sound(pad) else { return [] }
        return (0..<16).compactMap { i in
            guard let x = state.sound(PadID(pad.bank, i)), x.fileURL == s.fileURL else { return nil }
            return x.start
        }
    }

    private func commit(_ pad: PadID) {
        let ui = CrateUI.shared
        let s = ui.editPreviewStart, e = ui.editPreviewEnd
        Task { @MainActor in
            await Orchestrator.current?.trimPad(pad, start: s, end: e)
            ui.editPreviewStart = nil
            ui.editPreviewEnd = nil
        }
    }

    private func handle(at x: CGFloat, height: CGFloat, color: Color) -> some View {
        ZStack {
            Rectangle().fill(color).frame(width: 3, height: height)
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 30)
        }
        .frame(width: 16, height: height)
        .offset(x: x - 8)
        .allowsHitTesting(false)
    }
}

/// The source file's waveform across `window`; the kept region bright, the rest dim; slice lines for chops.
struct FileWaveCanvas: View {
    let url: URL
    let window: ClosedRange<Double>
    let duration: Double
    let start: Double
    let end: Double
    let tint: Color
    var marks: [Double] = []
    @State private var env: [Float] = []

    var body: some View {
        Canvas { g, size in
            let cy = size.height / 2
            g.fill(Path(CGRect(x: 0, y: cy - 0.25, width: size.width, height: 0.5)), with: .color(Theme.lidGrey3))
            let span = max(0.001, window.upperBound - window.lowerBound)
            func x(_ t: Double) -> CGFloat { CGFloat((t - window.lowerBound) / span) * size.width }
            g.fill(Path(CGRect(x: x(start), y: 0, width: max(1, x(end) - x(start)), height: size.height)),
                   with: .color(tint.opacity(0.12)))
            if !env.isEmpty {
                let cols = max(2, Int(size.width / 2.5))
                for c in 0..<cols {
                    let t = window.lowerBound + span * (Double(c) + 0.5) / Double(cols)
                    let i = min(env.count - 1, max(0, Int(t / max(0.001, duration) * Double(env.count))))
                    let a = CGFloat(min(1, max(0, env[i]))) * (size.height / 2 - 4)
                    let px = CGFloat(c) / CGFloat(cols) * size.width
                    let inside = t >= start && t <= end
                    g.fill(Path(CGRect(x: px, y: cy - max(0.5, a), width: 1.5, height: max(1, a * 2))),
                           with: .color(inside ? Theme.lidInk : Theme.lidInk.opacity(0.28)))
                }
            }
            for m in marks where m > window.lowerBound && m < window.upperBound {
                g.fill(Path(CGRect(x: x(m), y: 0, width: 1, height: size.height)), with: .color(Theme.lidGrey2))
            }
        }
        .task(id: url) { env = await FileWave.envelope(url) }
    }
}

/// Peak envelopes of whole source files (2048 points), computed off the main thread and cached.
enum FileWave {
    @MainActor private static var cache: [URL: [Float]] = [:]

    @MainActor static func envelope(_ url: URL) async -> [Float] {
        if let e = cache[url] { return e }
        let e = await Task.detached(priority: .userInitiated) { compute(url) }.value
        if !e.isEmpty { cache[url] = e }
        return e
    }

    private static func compute(_ url: URL, points: Int = 2048) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return [] }
        let fmt = file.processingFormat
        let per = max(1, Int(file.length) / points)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(per)) else { return [] }
        var out: [Float] = []
        out.reserveCapacity(points)
        while file.framePosition < file.length, out.count < points {
            let n = AVAudioFrameCount(min(AVAudioFramePosition(per), file.length - file.framePosition))
            guard (try? file.read(into: buf, frameCount: n)) != nil, let ch = buf.floatChannelData else { break }
            var peak: Float = 0
            for c in 0..<Int(fmt.channelCount) {
                for f in 0..<Int(buf.frameLength) { peak = max(peak, abs(ch[c][f])) }
            }
            out.append(peak)
        }
        let top = max(0.05, out.max() ?? 1)
        return out.map { min(1, $0 / top) }
    }
}

// MARK: - ＋ (bring a song)

/// ＋ next to the prompt: pick a song (it becomes 16 chops on bank D) or a short sound (it lands on the selected pad).
struct ImportButton: View {
    let state: AppState
    @State private var picking = false

    var body: some View {
        Button { picking = true } label: {
            Text("+")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Theme.lidInk)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(CrateUI.shared.flipHint ? Theme.lidGrey2 : Theme.chipStroke, lineWidth: 0.6))
                .contentShape(Circle())
        }
        .buttonStyle(ChipPressStyle())
        .accessibilityIdentifier("import-button")
        .accessibilityLabel("Bring a song")
        .fileImporter(isPresented: $picking, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { @MainActor in await AudioImport.importPicked(url, state: state) }
        }
    }
}
