import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// WatchConnectivity bridge for NATURaL Remote.
///
/// Shape mirrors NATURaL `BonhommeWatch/App/WatchConnectivityBridge.swift`:
/// activate once, throttle application-context updates, carry Codable snapshots
/// as base64 JSON for the iPhone “liver” (OAuth / Alexa / Spotify tokens).
@MainActor
final class RemoteWatchConnectivityBridge: NSObject {
    private(set) var isReachable = false
    private(set) var lastSyncDate: Date?
    private(set) var lastErrorDescription: String?

    #if canImport(WatchConnectivity)
    private var wcSession: WCSession?
    #endif

    private let encoder = JSONEncoder()
    private let sendInterval: TimeInterval = 2.0
    private var lastSendDate: Date = .distantPast

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

    /// Sends a JSON-encodable payload to the paired phone (throttled).
    func sendSnapshot<T: Encodable>(_ snapshot: T, type: String = "crooks_snapshot") {
        let now = Date()
        guard now.timeIntervalSince(lastSendDate) >= sendInterval else { return }
        lastSendDate = now

        guard let data = try? encoder.encode(snapshot) else {
            lastErrorDescription = "encode failed"
            return
        }

        #if canImport(WatchConnectivity)
        guard let session = wcSession else { return }
        let message: [String: Any] = [
            "type": type,
            "data": data.base64EncodedString(),
        ]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.lastErrorDescription = error.localizedDescription
                    self?.updateApplicationContext(message)
                }
            }
            lastSyncDate = now
        } else {
            updateApplicationContext(message)
        }
        #endif
    }

    #if canImport(WatchConnectivity)
    private func updateApplicationContext(_ message: [String: Any]) {
        guard let session = wcSession else { return }
        do {
            try session.updateApplicationContext(message)
            lastSyncDate = Date()
        } catch {
            lastErrorDescription = error.localizedDescription
        }
    }
    #endif
}

#if canImport(WatchConnectivity)
extension RemoteWatchConnectivityBridge: WCSessionDelegate {
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

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
#endif
