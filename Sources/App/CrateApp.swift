import SwiftUI

@main
struct CrateApp: App {
    @State private var state: AppState
    private let hinge: HingeFX
    private let commands = DebugCommands()
    private let orchestrator: Orchestrator

    init() {
        let engine = AudioEngine()
        try? engine.start()
        let s = AppState(engine: engine)
        _state = State(initialValue: s)
        hinge = HingeFX(state: s)
        let hingeFX = hinge
        CrateUI.shared.onPunch = { hingeFX.apply($0) }
        let library = LibraryStore()
        orchestrator = Orchestrator(state: s, library: library)
        orchestrator.wire()
        DebugLog.event("launch", ["library": AppConfig.libraryURL.path,
                                  "libraryReadable": FileManager.default.isReadableFile(atPath: AppConfig.libraryURL.appendingPathComponent("grooves.json").path),
                                  "hasOpenAI": AppConfig.openAIKey != nil, "hasJev": AppConfig.typesafeKey != nil])
    }

    var body: some Scene {
        WindowGroup {
            RootView(state: state, hinge: hinge)
                .crateIf(!AppConfig.noPaywall) { $0.paywallGate(state: state) }
                .onOpenURL { Router.handle($0, state: state, hinge: hinge) }
                .onAppear { commands.start(state: state, hinge: hinge) }
                .task { await ProjectStore.shared.boot(state: state) }
        }
    }
}

extension View {
    /// Apply a modifier only when `condition` holds (used to switch the paywall off for demos).
    @ViewBuilder func crateIf<V: View>(_ condition: Bool, _ transform: (Self) -> V) -> some View {
        if condition { transform(self) } else { self }
    }
}
