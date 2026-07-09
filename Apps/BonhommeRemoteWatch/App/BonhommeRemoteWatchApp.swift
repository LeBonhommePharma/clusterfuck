import SwiftUI
import NaturalRemote

/// watchOS entry for NATURaL Remote — Entropy Docking Edition.
///
/// Session topology mirrors NATURaL `BonhommeWatchApp` + `WatchSessionView`:
/// environment-injected managers and a single WindowGroup root.
/// Control loop UI lives in `RemoteSessionView` (NaturalRemote Session layer).
@main
struct BonhommeRemoteWatchApp: App {
    @StateObject private var sessionModel = RemoteSessionViewModel()
    @State private var connectivity = RemoteWatchConnectivityBridge()

    var body: some Scene {
        WindowGroup {
            RemoteSessionView(model: sessionModel)
                .onAppear {
                    connectivity.activateIfNeeded()
                }
        }
    }
}
