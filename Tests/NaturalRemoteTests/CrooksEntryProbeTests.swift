import XCTest
@testable import NaturalRemote

/// Verification probe: drives shipped CrooksCycleController with calm vs hot multi-signal states
/// and prints finite σ_irr values (captured into crooks-entry.log by the harness).
final class CrooksEntryProbeTests: XCTestCase {
    func testPrintCalmVsHotSigmaIrrFromShippedController() async {
        let bus = ActuatorBus()
        for s: RemoteService in [.appleMusic, .spotify, .sonos, .diFm, .alexa, .airPods, .foundationModel, .researchKit] {
            bus.register(RecordingActuator(service: s))
        }
        let crooks = CrooksCycleController(deltaG: -1.0, bus: bus, minimizeThreshold: 0.01)
        await crooks.reset(deltaG: -1.0)

        let calm = RemoteMultiSignalState(
            deltaHRV: 1.0,
            flexAIDDeltaS: 0.05,
            musicBPM: 88,
            audioEntropyBits: 0.4,
            sci: 0.85,
            pcci: 0.8,
            alexaEntropyHint: 0.05,
            airPodsANCEngaged: true,
            conversationAwarenessActive: false
        )
        let snapCalm = await crooks.update(with: calm)

        let hot = RemoteMultiSignalState(
            deltaHRV: 35.0,
            flexAIDDeltaS: 1.8,
            musicBPM: 148,
            audioEntropyBits: 4.2,
            sci: 0.12,
            pcci: 0.25,
            alexaEntropyHint: 1.2,
            airPodsANCEngaged: false,
            conversationAwarenessActive: true
        )
        let snapHot = await crooks.update(with: hot)

        // Required assertions on shipped path
        XCTAssertTrue(snapCalm.sigmaIrr.isFinite)
        XCTAssertTrue(snapHot.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(snapCalm.sigmaIrr, 0)
        XCTAssertGreaterThanOrEqual(snapHot.sigmaIrr, 0)
        XCTAssertNotEqual(snapCalm.sigmaIrr, snapHot.sigmaIrr, accuracy: 1e-12)

        // Machine-parseable probe lines for crooks-entry.log
        print("CROOKS_PROBE calm_sigma_irr=\(snapCalm.sigmaIrr) workFwd=\(snapCalm.workFwd) workRev=\(snapCalm.workRev) closure=\(snapCalm.closurePercent)")
        print("CROOKS_PROBE hot_sigma_irr=\(snapHot.sigmaIrr) workFwd=\(snapHot.workFwd) workRev=\(snapHot.workRev) closure=\(snapHot.closurePercent)")
        print("CROOKS_PROBE delta_sigma=\(snapHot.sigmaIrr - snapCalm.sigmaIrr)")
        fflush(stdout)
    }
}
