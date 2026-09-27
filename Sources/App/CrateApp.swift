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
                .onOpenURL { Router.handle($0, state: state, hinge: hinge) }
                .onAppear { commands.start(state: state, hinge: hinge) }
                .task { await ProjectStore.shared.boot(state: state) }
        }
    }
}

