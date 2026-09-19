import Foundation

/// Provenance is independent of session lifecycle and numeric kernel defaults.
/// A real sensor adapter must explicitly supply measured evidence; permission alone is insufficient.
public enum RemoteHUDEvidence: String, Sendable, Equatable {
    case unavailable
    case simulated
    case measured
    case derived

    public func displayValue(_ value: Double?) -> Double? {
        guard self != .unavailable, let value, value.isFinite else { return nil }
        return value
    }

    public var label: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .simulated: return "Demo · simulated"
        case .measured: return "Measured"
        case .derived: return "Model estimate · Health input"
        }
    }

    public static func sessionLabel(isRunning: Bool, evidence: [Self]) -> String {
        // A stopped demo preview remains explicitly a demo, never a live session.
        if evidence.contains(.simulated) { return "Demo" }
        guard isRunning else { return "Idle" }
        return (evidence.contains(.measured) || evidence.contains(.derived)) ? "Measured" : "Waiting for sensors"
    }
}
