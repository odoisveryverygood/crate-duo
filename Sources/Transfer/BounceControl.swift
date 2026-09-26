import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import Observation

struct BouncedAudio: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .wav) { audio in SentTransferredFile(audio.url) }
    }
}

@MainActor
@Observable
final class BounceController {
    var isBouncing = false
    var exported: URL?
    var error: String?
    @ObservationIgnored private var capture: MasterBounce?

    func bounce(state: AppState) {
        guard !isBouncing else { return }
        guard let engine = state.engine as? AudioEngine else { error = "Bounce needs the audio engine."; return }
        isBouncing = true
        error = nil
        do {
            capture = try MasterBounce(engine: engine, title: "\(state.styleLabel) \(state.sampleLabel)") { [weak self, weak state] result in
                guard let self else { return }
                self.isBouncing = false
                self.capture = nil
                switch result {
                case .success(let url):
                    self.exported = url
                    state?.addLog("BOUNCE", "4 bars · \(url.lastPathComponent)", tint: .orange)
                    DebugLog.event("bounce", ["file": url.lastPathComponent, "bars": 4])
                case .failure(let error): self.error = error.localizedDescription
                }
            }
        } catch { isBouncing = false; self.error = error.localizedDescription }
    }
    func cancel() { capture?.cancel() }
}

struct BounceControl: View {
    let state: AppState
    @State private var controller = BounceController()

    var body: some View {
        HStack(spacing: 8) {
            if controller.isBouncing {
                ProgressView().controlSize(.mini)
                Button("CANCEL BOUNCE") { controller.cancel() }
            } else {
                Button("BOUNCE 4 BARS") { controller.bounce(state: state) }
                    .disabled(!state.isPlaying)
                    .accessibilityIdentifier("bounce-button")
            }
            if let url = controller.exported {
                let audio = BouncedAudio(url: url)
                Text("↗ \(url.lastPathComponent)")
                    .lineLimit(1).truncationMode(.middle)
                    .padding(5).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                    .draggable(audio)
                    .accessibilityIdentifier("bounce-file")
                ShareLink(item: audio, preview: SharePreview(url.lastPathComponent)) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share bounced WAV")
            }
        }
        .font(.custom("SpaceMono-Bold", size: 9))
        .foregroundStyle(.orange)
        .buttonStyle(.plain)
        .alert("Bounce", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
            Button("OK") { controller.error = nil }
        } message: { Text(controller.error ?? "") }
        .onDisappear { controller.cancel() }
    }
}
