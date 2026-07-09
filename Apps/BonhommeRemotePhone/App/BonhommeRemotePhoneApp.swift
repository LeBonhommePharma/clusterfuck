import SwiftUI
import NaturalRemote

/// iOS companion (“liver”) for NATURaL Remote.
///
/// Hosts OAuth/token refresh for Spotify and Alexa BFF (Sessions 2/5),
/// heavy REST, and WatchConnectivity. UI reuses `RemoteSessionView` so phone
/// and watch share one control plane.
@main
struct BonhommeRemotePhoneApp: App {
    @StateObject private var sessionModel = RemoteSessionViewModel()
    @State private var connectivity = PhoneConnectivityBridge()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                VStack(spacing: 16) {
                    Text(NaturalRemoteInfo.name)
                        .font(.headline)
                    Text("v\(NaturalRemoteInfo.version) · \(NaturalRemoteInfo.codename)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    RemoteSessionView(model: sessionModel)
                }
                .padding()
                .navigationTitle("Remote")
            }
            .onAppear {
                connectivity.activateIfNeeded()
            }
        }
    }
}
