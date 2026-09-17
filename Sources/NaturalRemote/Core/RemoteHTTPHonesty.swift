import Foundation

/// HTTP status contract for actuator transports (Alexa, Spotify, …).
/// A 4xx/5xx must fail the bus so the audit trail cannot claim `executed`.
public enum RemoteHTTPError: Error, Equatable, Sendable {
    case missingStatus
    case status(Int)
}

public enum RemoteHTTPHonesty: Sendable {
    public static func requireSuccess(_ status: Int?) throws {
        guard let status else { throw RemoteHTTPError.missingStatus }
        guard (200..<300).contains(status) else { throw RemoteHTTPError.status(status) }
    }
}
