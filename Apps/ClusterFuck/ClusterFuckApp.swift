import SwiftUI
import NaturalRemote

/// Multi-platform app entry for **macOS**, **iOS**, and **iPadOS**.
///
/// Drives the real NaturalRemote kernel via `RemoteSessionView` / `RemoteSessionViewModel`
/// (Crooks, RemoteControlLoop, PharmaControlSessionManager).
@main
struct ClusterFuckApp: App {
    var body: some Scene {
        WindowGroup {
            ClusterFuckRootView()
        }
        #if os(macOS)
        .defaultSize(width: 480, height: 720)
        #endif
    }
}
