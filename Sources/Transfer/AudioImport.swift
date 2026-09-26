import Foundation
import AVFoundation
import Observation

struct ImportedAudio: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let duration: Double
}

enum AudioTransferError: LocalizedError {
    case invalidAudio, tooLarge, busy, loadFailed, playbackRequired, interrupted, timedOut
    var errorDescription: String? {
        switch self {
        case .invalidAudio: return "Choose a readable local audio file."
        case .tooLarge: return "Use an audio file under 100 MB and five minutes."
        case .busy: return "An audio transfer is already in progress."
        case .loadFailed: return "The audio engine couldn’t load this sample."
        case .playbackRequired: return "Start playback before bouncing four bars."
        case .interrupted: return "Bounce cancelled because playback, tempo, or the audio route changed."
        case .timedOut: return "No audio arrived. Start playback and try again."
        }
    }
}

enum AudioImport {
    /// Must run inside the provider callback: its temporary URL expires when the callback returns.
    static func copy(_ source: URL, directory: URL? = nil) throws -> ImportedAudio {
        guard source.isFileURL else { throw AudioTransferError.invalidAudio }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw AudioTransferError.invalidAudio }
        guard (values.fileSize ?? 0) <= 100 * 1024 * 1024 else { throw AudioTransferError.tooLarge }
        let directory = try directory ?? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("imported", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = source.pathExtension.isEmpty ? "wav" : source.pathExtension
        let destination = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        try FileManager.default.copyItem(at: source, to: destination)
        do {
            let file = try AVAudioFile(forReading: destination)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            guard duration.isFinite, duration > 0, file.processingFormat.channelCount > 0 else { throw AudioTransferError.invalidAudio }
            guard duration <= 300 else { throw AudioTransferError.tooLarge }
            return ImportedAudio(url: destination, name: source.deletingPathExtension().lastPathComponent, duration: duration)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    static func sounds(_ audio: ImportedAudio, pad: PadID, chop: Bool) -> (Bank, [Int: PadSound]) {
        if chop {
            let sounds = Dictionary(uniqueKeysWithValues: (0..<16).map { i in
                (i, PadSound(id: "\(audio.id)-\(i)", name: String(format: "CHOP %02d", i + 1), category: .chop,
                             fileURL: audio.url, start: audio.duration * Double(i) / 16,
                             end: audio.duration * Double(i + 1) / 16, rootNote: 60, source: audio.name))
            })
            return (.d, sounds)
        }
        return (pad.bank, [pad.index: PadSound(id: audio.id.uuidString, name: audio.name, category: .chop,
                                              fileURL: audio.url, rootNote: 60, source: "dropped")])
    }
}

@MainActor
@Observable
final class AudioImportController {
    var pending: ImportedAudio?
    var isBusy = false
    var error: String?
    private var target = PadID(.d, 0)

    func receive(_ audio: ImportedAudio, on pad: PadID, state: AppState) async {
        target = pad
        if audio.duration > 2 { pending = audio; isBusy = false }
        else { await install(audio, chop: false, state: state) }
    }

    func choose(chop: Bool, state: AppState) {
        guard let audio = pending else { return }
        pending = nil
        isBusy = true
        Task { await install(audio, chop: chop, state: state) }
    }

    func cancel() {
        if let audio = pending { try? FileManager.default.removeItem(at: audio.url) }
        pending = nil
        isBusy = false
    }

    func install(_ audio: ImportedAudio, chop: Bool, state: AppState) async {
        isBusy = true
        defer { isBusy = false }
        let (bank, replacement) = AudioImport.sounds(audio, pad: target, chop: chop)
        var sounds: [Int: PadSound] = [:]
        // loadBank replaces the WHOLE bank. Keep every other pad on a one-shot import.
        if !chop {
            for i in 0..<16 { sounds[i] = state.engine.sound(for: PadID(bank, i)) ?? state.sounds[PadID(bank, i)] }
        }
        sounds.merge(replacement) { _, new in new }
        do {
            try await state.engine.loadBank(bank, sounds: sounds)
            guard replacement.allSatisfy({ state.engine.sound(for: PadID(bank, $0.key))?.id == $0.value.id }) else {
                throw AudioTransferError.loadFailed
            }
            state.sounds = state.sounds.filter { $0.key.bank != bank }
            for (i, sound) in sounds { state.sounds[PadID(bank, i)] = sound }
            state.bank = bank
            state.selectedPad = PadID(bank, chop ? 0 : target.index)
            state.addLog("SAMPLE", "dropped \(audio.name)\(chop ? " · CHOP 16 → D" : "")", tint: .grey)
            DebugLog.event("sample_drop", ["name": audio.name, "sec": audio.duration, "chops": chop ? 16 : 1])
        } catch {
            self.error = error.localizedDescription
            state.addLog("ERR", "Import: \(error.localizedDescription)", tint: .red)
            // Keep the owned file if another load raced us; the engine may still reference it.
        }
    }
}
