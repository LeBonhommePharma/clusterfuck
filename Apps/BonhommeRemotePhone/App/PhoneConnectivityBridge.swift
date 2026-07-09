import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// iPhone WatchConnectivity hub for NATURaL Remote.
///
/// Mirrors NATURaL `Bonhomme/Services/WatchConnectivity/PhoneConnectivityBridge`
/// responsibilities: activate WCSession, accept watch snapshots, push token
/// refresh notifications to the wrist when OAuth completes.
@MainActor
final class PhoneConnectivityBridge: NSObject {
    private(set) var isReachable = false
    private(set) var lastWatchPayloadType: String?
    private(set) var lastErrorDescription: String?
    private(set) var pendingTokenPayload: [String: String] = [:]

    #if canImport(WatchConnectivity)
    private var wcSession: WCSession?
    #endif

    func activateIfNeeded() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            lastErrorDescription = "WatchConnectivity unsupported"
            return
        }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
        wcSession = session
        isReachable = session.isReachable
        #else
        lastErrorDescription = "WatchConnectivity unavailable on this platform"
        #endif
    }

    /// Stores OAuth / Alexa BFF tokens for App Group + WC transfer (no secrets in source).
    func updateTokens(_ tokens: [String: String]) {
        pendingTokenPayload = tokens
        #if canImport(WatchConnectivity)
        guard let session = wcSession else { return }
        var context = session.receivedApplicationContext
        context["type"] = "token_refresh"
        context["tokens"] = tokens
        do {
            try session.updateApplicationContext(context)
        } catch {
            lastErrorDescription = error.localizedDescription
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension PhoneConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.lastErrorDescription = error?.localizedDescription
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.lastWatchPayloadType = message["type"] as? String
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.lastWatchPayloadType = applicationContext["type"] as? String
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
