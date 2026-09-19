import XCTest
@testable import NaturalRemote

private final class InjectedHealthSource: RemoteHealthObserving, @unchecked Sendable {
    private let stream: AsyncStream<RemoteHealthEvent>
    let continuation: AsyncStream<RemoteHealthEvent>.Continuation
    let cancelled = XCTestExpectation(description: "source cancelled")

    init() {
        let pair = AsyncStream<RemoteHealthEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
        continuation.onTermination = { [cancelled] _ in cancelled.fulfill() }
    }
    func events() -> AsyncStream<RemoteHealthEvent> { stream }
}

@MainActor
final class HealthObservationTests: XCTestCase {
    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<100 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Observation did not arrive")
    }

    func testPermissionWithoutSamplesDoesNotProduceMeasurements() async {
        let source = InjectedHealthSource()
        let model = RemoteSessionViewModel(manager: PharmaControlSessionManager(healthSource: source))
        await model.start()
        source.continuation.yield(.status(.noDataOrDenied))
        await waitUntil { model.manager.observedHealth().readings.status == .noDataOrDenied }
        model.refreshHealthReadings()
        XCTAssertNil(model.displaySCI)
        XCTAssertFalse(model.displaySigma.isFinite)
        XCTAssertTrue(model.healthStatusLabel.contains("not be granted"))
        model.stop()
        await fulfillment(of: [source.cancelled], timeout: 2)
    }

    func testRealBeatIntervalsFeedControlAndExpireWithoutFabricatedAudio() async {
        let source = InjectedHealthSource()
        let model = RemoteSessionViewModel(manager: PharmaControlSessionManager(healthSource: source))
        await model.start()
        let date = Date()
        source.continuation.yield(.heartRate(72, date))
        source.continuation.yield(.sdnn(40, date))
        await waitUntil { model.manager.observedHealth().readings.sdnn != nil }
        model.refreshHealthReadings()
        XCTAssertNil(model.displaySCI, "SDNN scalar cannot be substituted for beat intervals")
        XCTAssertTrue(model.healthMetricsLabel.contains("72 bpm"))
        source.continuation.yield(.beatIntervals([800, 810, 795, 820, 805], date))
        await waitUntil { model.manager.observedHealth().control != nil }
        model.refreshHealthReadings()
        XCTAssertEqual(model.physiologicalEvidence, .measured)
        XCTAssertEqual(model.controlEvidence, .derived)
        XCTAssertNotNil(model.displaySCI)
        XCTAssertTrue(model.displaySigma.isFinite)
        XCTAssertEqual(model.audioEvidence, .unavailable)
        XCTAssertEqual(model.musicMetricsLabel, "BPM — · H_audio —")
        model.refreshHealthReadings(at: date.addingTimeInterval(121))
        XCTAssertNil(model.displaySCI)
        XCTAssertFalse(model.displaySigma.isFinite)
        model.stop()
        source.continuation.yield(.beatIntervals([800, 810, 820, 830], Date()))
        await Task.yield()
        model.refreshHealthReadings()
        XCTAssertNil(model.displaySCI, "Callbacks after cancellation must not restore measurements")
        await fulfillment(of: [source.cancelled], timeout: 2)
    }

    func testFailureAndDeletionClearReadings() async {
        let source = InjectedHealthSource()
        let manager = PharmaControlSessionManager(healthSource: source)
        await manager.start()
        source.continuation.yield(.heartRate(80, Date()))
        await waitUntil { manager.observedHealth().readings.heartRate != nil }
        source.continuation.yield(.invalidated(.heartRate))
        await waitUntil { manager.observedHealth().readings.heartRate == nil }
        source.continuation.yield(.status(.failed("Health database locked")))
        await waitUntil { manager.observedHealth().readings.status == .failed("Health database locked") }
        XCTAssertNil(manager.observedHealth().control)
        manager.stop()
        await fulfillment(of: [source.cancelled], timeout: 2)
    }
}
