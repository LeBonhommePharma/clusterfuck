import XCTest
@testable import NaturalRemote

/// App-layer tests: same `RemoteSessionViewModel` the UI uses, driving real control path.
@MainActor
final class AppSessionFacadeTests: XCTestCase {
    func testViewModelStartAndSyntheticMultiSignalChangesSigmaIrr() async {
        let model = RemoteSessionViewModel()
        await model.start()
        XCTAssertTrue(model.isSessionRunning)

        let calm = await model.applySyntheticMultiSignal(
            deltaHRV: 1.0,
            musicBPM: 88,
            audioEntropy: 0.4,
            sci: 0.85
        )
        XCTAssertTrue(calm.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(calm.sigmaIrr, 0)
        XCTAssertTrue(model.sigmaIrr.isFinite)

        let hot = await model.applySyntheticMultiSignal(
            deltaHRV: 35.0,
            musicBPM: 148,
            audioEntropy: 4.2,
            sci: 0.12
        )
        XCTAssertTrue(hot.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(hot.sigmaIrr, 0)
        XCTAssertNotEqual(calm.sigmaIrr, hot.sigmaIrr, accuracy: 1e-12)
        XCTAssertEqual(model.sigmaIrr, hot.sigmaIrr, accuracy: 1e-12)
        XCTAssertEqual(model.musicBPM, 148, accuracy: 1e-9)
        XCTAssertEqual(model.manager.loop.state.musicBPM, 148, accuracy: 1e-9)
        XCTAssertEqual(model.manager.loop.state.physiologicalSCI, 0.12, accuracy: 1e-9)

        model.stop()
        XCTAssertFalse(model.isSessionRunning)
    }

    func testViewModelMinimizesThroughActuatorBus() async {
        let model = RemoteSessionViewModel()
        await model.start()
        _ = await model.applySyntheticMultiSignal(
            deltaHRV: 20,
            musicBPM: 140,
            audioEntropy: 3,
            sci: 0.2
        )
        await model.forceMinimize()
        let events = await model.manager.loop.crooks.recordedEvents()
        XCTAssertFalse(events.isEmpty, "minimize must hit the real actuator bus")
        XCTAssertFalse(model.lastAction.isEmpty)
    }

    func testHealthKitGateRefusesBundleWithoutUsageDescription() {
        let bundle = Bundle(for: AppSessionFacadeTests.self)
        XCTAssertNil(
            bundle.object(forInfoDictionaryKey: "NSHealthShareUsageDescription"),
            "SPM test bundle must not pretend to be a HealthKit host"
        )
        XCTAssertFalse(
            HealthKitAuthorizationGate.canRequestReadAuthorization(in: bundle),
            "requestAuthorization without NSHealthShareUsageDescription aborts the process"
        )
    }

    func testSessionStartCompletesWithoutHealthKitPlist() async {
        let manager = PharmaControlSessionManager()
        await manager.start()
        XCTAssertTrue(manager.isRunning)
        XCTAssertNotNil(manager.startedAt)
        manager.stop()
        XCTAssertFalse(manager.isRunning)
    }
}
