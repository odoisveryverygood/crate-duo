import SwiftUI

@main
struct CrateApp: App {
    @State private var state: AppState
    private let hinge: HingeFX

    init() {
        let s = AppState(engine: MockEngine())
        _state = State(initialValue: s)
        hinge = HingeFX(state: s)
        DebugLog.event("launch", ["library": AppConfig.libraryURL.path,
                                  "libraryReadable": FileManager.default.isReadableFile(atPath: AppConfig.libraryURL.appendingPathComponent("grooves.json").path),
                                  "hasOpenAI": AppConfig.openAIKey != nil, "hasJev": AppConfig.typesafeKey != nil])
    }

    var body: some Scene {
        WindowGroup {
            RootView(state: state, hinge: hinge)
                .onOpenURL { Router.handle($0, state: state, hinge: hinge) }
        }
    }
}
