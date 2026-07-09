import SwiftUI
import NaturalRemote

/// watchOS app entry — wrist remote for σ_irr minimization / PV session.
@main
struct ClusterFuckWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchRootView()
        }
    }
}

struct WatchRootView: View {
    @StateObject private var model = RemoteSessionViewModel()

    var body: some View {
        RemoteSessionView(model: model)
    }
}
