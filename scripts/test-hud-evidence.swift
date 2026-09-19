// Standalone, dependency-free runtime test. Full SwiftUI integration requires Xcode.
// swiftc Sources/NaturalRemote/Session/RemoteHUDEvidence.swift scripts/test-hud-evidence.swift -o /tmp/clusterfuck-hud-evidence && /tmp/clusterfuck-hud-evidence
import Foundation

@main
struct HUDEvidenceTests {
    static func main() {
        precondition(RemoteHUDEvidence.unavailable.displayValue(0.5) == nil)
        precondition(RemoteHUDEvidence.measured.displayValue(nil) == nil)
        precondition(RemoteHUDEvidence.measured.displayValue(.nan) == nil)
        precondition(RemoteHUDEvidence.simulated.displayValue(.infinity) == nil)
        precondition(RemoteHUDEvidence.measured.displayValue(0) == 0)
        precondition(RemoteHUDEvidence.simulated.displayValue(0.8) == 0.8)
        precondition(RemoteHUDEvidence.simulated.label == "Demo · simulated")
        precondition(RemoteHUDEvidence.sessionLabel(isRunning: false, evidence: [.unavailable]) == "Idle")
        precondition(RemoteHUDEvidence.sessionLabel(isRunning: true, evidence: [.unavailable]) == "Waiting for sensors")
        precondition(RemoteHUDEvidence.sessionLabel(isRunning: true, evidence: [.measured]) == "Measured")
        precondition(RemoteHUDEvidence.sessionLabel(isRunning: true, evidence: [.measured, .simulated]) == "Demo")
        precondition(RemoteHUDEvidence.sessionLabel(isRunning: false, evidence: [.simulated]) == "Demo")
        print("PASS: 12 HUD evidence runtime assertions")
    }
}
