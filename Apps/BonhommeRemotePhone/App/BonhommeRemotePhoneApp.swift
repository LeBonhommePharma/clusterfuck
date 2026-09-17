import SwiftUI
import NaturalRemote

/// iOS companion (“liver”) for NATURaL Remote.
///
/// Hosts OAuth/token refresh for Spotify and Alexa BFF (Sessions 2/5),
/// heavy REST, and WatchConnectivity. UI reuses `ClusterFuckRootView` so phone
/// and watch share one Crooks HUD.
@main
struct BonhommeRemotePhoneApp: App {
    @State private var connectivity = PhoneConnectivityBridge()

    var body: some Scene {
        WindowGroup {
            ClusterFuckRootView()
                .onAppear {
                    connectivity.activateIfNeeded()
                }
        }
    }
}
