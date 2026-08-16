import XCTest
@testable import NaturalRemote

final class CrooksCycleControllerTests: XCTestCase {
    func testUpdateProducesFiniteNonNegativeSigmaAndRespondsToInputChange() async {
        let bus = ActuatorBus()
        bus.register(RecordingActuator(service: .appleMusic))
        bus.register(RecordingActuator(service: .spotify))
        bus.register(RecordingActuator(service: .sonos))
        bus.register(RecordingActuator(service: .diFm))
        bus.register(RecordingActuator(service: .alexa))
        bus.register(RecordingActuator(service: .airPods))
        bus.register(RecordingActuator(service: .foundationModel))
        bus.register(RecordingActuator(service: .researchKit))

        let crooks = CrooksCycleController(deltaG: -1.0, bus: bus, minimizeThreshold: 0.01)

        let calm = RemoteMultiSignalState(
            deltaHRV: 1,
            flexAIDDeltaS: 0.1,
            musicBPM: 90,
            audioEntropyBits: 0.5,
            sci: 0.8
        )
        let snap1 = await crooks.update(with: calm)
        XCTAssertTrue(snap1.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(snap1.sigmaIrr, 0)

        let hot = RemoteMultiSignalState(
            deltaHRV: 40,
            flexAIDDeltaS: 2.0,
            musicBPM: 150,
            audioEntropyBits: 4.0,
            sci: 0.1,
            alexaEntropyHint: 1.0
        )
        let snap2 = await crooks.update(with: hot)
        XCTAssertTrue(snap2.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(snap2.sigmaIrr, 0)
        // Accumulated work should move σ_irr when inputs inject more work.
        XCTAssertNotEqual(snap1.sigmaIrr, snap2.sigmaIrr, accuracy: 1e-12)

        let events = await crooks.recordedEvents()
        XCTAssertFalse(events.isEmpty, "minimization should emit actuator events when threshold exceeded")
    }

    func testMinimizeDrivesMusicAndEnvironment() async {
        let bus = ActuatorBus()
        let music = RecordingActuator(service: .appleMusic)
        let alexa = RecordingActuator(service: .alexa)
        bus.register(music)
        bus.register(RecordingActuator(service: .spotify))
        bus.register(RecordingActuator(service: .sonos))
        bus.register(RecordingActuator(service: .diFm))
        bus.register(alexa)
        bus.register(RecordingActuator(service: .airPods))
        bus.register(RecordingActuator(service: .foundationModel))
        bus.register(RecordingActuator(service: .researchKit))

        let crooks = CrooksCycleController(deltaG: -8.2, bus: bus)
        await crooks.minimizeSigma(currentBPM: 130)
        let events = await crooks.recordedEvents()
        XCTAssertTrue(events.contains { $0.service == .appleMusic })
        XCTAssertTrue(events.contains { $0.service == .alexa })
        let snap = await crooks.snapshot()
        XCTAssertFalse(snap.lastActionSummary.isEmpty)
    }

    func testDefaultDeltaGAllowsClosureAndPhaseFlip() async {
        let crooks = CrooksCycleController()
        let calm = RemoteMultiSignalState(
            deltaHRV: 1.0,
            flexAIDDeltaS: 0.05,
            musicBPM: 88,
            audioEntropyBits: 0.4,
            sci: 0.85,
            airPodsANCEngaged: true
        )
        let snap = await crooks.update(with: calm)
        XCTAssertEqual(snap.sigmaIrr, 0, accuracy: 1e-12, "calm state must reach closure (σ_irr ≈ 0) under the default ΔG")
        XCTAssertEqual(snap.phase, .reverse, "closure must flip the phase out of forward")
        XCTAssertEqual(snap.cycleCount, 1)
    }

    func testResetClearsWork() async {
        let crooks = CrooksCycleController(deltaG: -2)
        _ = await crooks.update(with: RemoteMultiSignalState(deltaHRV: 10, musicBPM: 140))
        await crooks.reset(deltaG: -2)
        let snap = await crooks.snapshot()
        XCTAssertEqual(snap.workFwd, 0, accuracy: 1e-12)
        XCTAssertEqual(snap.workRev, 0, accuracy: 1e-12)
        XCTAssertEqual(snap.cycleCount, 0)
    }

    func testBusRecordsFailureEventAndRethrows() async {
        let bus = ActuatorBus()
        bus.register(ThrowingActuator(service: .spotify))
        do {
            try await bus.execute(RemoteCommand(service: .spotify, action: "play"))
            XCTFail("expected actuator failure to propagate")
        } catch {
            // expected
        }
        let events = bus.recordedEvents()
        XCTAssertEqual(events.last?.detail, "failed")
    }
}

private enum TestError: Error { case boom }

private final class ThrowingActuator: RemoteActuator, @unchecked Sendable {
    let service: RemoteService
    init(service: RemoteService) { self.service = service }
    func execute(_ command: RemoteCommand) async throws {
        throw TestError.boom
    }
}
