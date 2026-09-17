import Foundation

/// WatchConnectivity / PV export must never carry credentials.
public enum SecretFieldPolicy: Sendable {
    public static let forbiddenFragments = [
        "token", "secret", "password", "bearer", "listenkey", "listen_key",
        "apikey", "api_key", "authorization", "cookie", "pkce", "verifier",
    ]

    public static func isSecretKey(_ key: String) -> Bool {
        let folded = key.lowercased().replacingOccurrences(of: "_", with: "")
        return forbiddenFragments.contains { folded.contains($0.replacingOccurrences(of: "_", with: "")) }
    }

    public static func strippingSecrets(_ params: [String: String]) -> [String: String] {
        params.filter { !isSecretKey($0.key) }
    }

    /// Application-context payloads: keep `type` only plus non-secret metadata.
    public static func sanitizeWatchContext(_ payload: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (key, value) in payload {
            if isSecretKey(key) { continue }
            if let nested = value as? [String: String] {
                let clean = strippingSecrets(nested)
                if !clean.isEmpty { out[key] = clean }
            } else if let nestedAny = value as? [String: Any] {
                let clean = sanitizeWatchContext(nestedAny)
                if !clean.isEmpty { out[key] = clean }
            } else {
                out[key] = value
            }
        }
        return out
    }
}
