import SwiftUI

@main
struct CrateApp: App {
    @State private var state = AppState(engine: MockEngine())

    var body: some Scene {
        WindowGroup {
            RootView(state: state)
        }
    }
}
