import SwiftUI
import UniformTypeIdentifiers

private struct AudioPadDrop: ViewModifier {
    let state: AppState
    let size: CGSize
    let gap: CGFloat
    @State private var importer = AudioImportController()
    @State private var targeted = false
    @State private var showChoice = false

    func body(content: Content) -> some View {
        content
            .onDrop(of: [UTType.audio.identifier, UTType.fileURL.identifier], isTargeted: $targeted) { providers, point in
                guard !importer.isBusy, importer.pending == nil, let provider = providers.first else { return false }
                let cw = max(1, (size.width - 3 * gap) / 4)
                let ch = max(1, (size.height - 3 * gap) / 4)
                let column = min(3, max(0, Int(point.x / (cw + gap))))
                let row = min(3, max(0, Int(point.y / (ch + gap))))
                let pad = PadID(state.bank, (3 - row) * 4 + column)
                importer.isBusy = true
                AudioDropProvider.load(provider) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let audio): await importer.receive(audio, on: pad, state: state)
                        case .failure(let error): importer.isBusy = false; importer.error = error.localizedDescription
                        }
                    }
                }
                return true
            }
            .overlay {
                if targeted || importer.isBusy {
                    RoundedRectangle(cornerRadius: 6).stroke(Color.orange, lineWidth: 3)
                        .overlay(alignment: .top) {
                            Text(importer.isBusy ? "LOADING AUDIO…" : "DROP ON A PAD")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(6).background(.black).foregroundStyle(.orange)
                        }
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: importer.pending?.id) { _, id in showChoice = id != nil }
            .onChange(of: showChoice) { _, shown in if !shown && importer.pending != nil { importer.cancel() } }
            .confirmationDialog("Audio longer than 2 seconds", isPresented: $showChoice, titleVisibility: .visible) {
                Button("CHOP 16 → BANK D (replace bank)") { importer.choose(chop: true, state: state) }
                Button("Use on this pad") { importer.choose(chop: false, state: state) }
                Button("Cancel", role: .cancel) { importer.cancel() }
            } message: {
                Text(importer.pending?.name ?? "")
            }
            .alert("Audio import", isPresented: Binding(get: { importer.error != nil }, set: { if !$0 { importer.error = nil } })) {
                Button("OK") { importer.error = nil }
            } message: { Text(importer.error ?? "") }
    }

}

enum AudioDropProvider {
    static func load(_ provider: NSItemProvider, completion: @escaping (Result<ImportedAudio, Error>) -> Void) {
        if let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .audio) == true }) {
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                guard let url else { completion(.failure(error ?? AudioTransferError.invalidAudio)); return }
                completion(Result { try AudioImport.copy(url) })
            }
        } else {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                guard let url else { completion(.failure(error ?? AudioTransferError.invalidAudio)); return }
                completion(Result { try AudioImport.copy(url) })
            }
        }
    }
}

extension View {
    func audioPadDrop(state: AppState, size: CGSize, gap: CGFloat) -> some View {
        modifier(AudioPadDrop(state: state, size: size, gap: gap))
    }
}
