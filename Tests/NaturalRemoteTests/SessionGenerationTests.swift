import XCTest
@testable import NaturalRemote

private final class GateSource: RemoteHealthObserving, @unchecked Sendable {
    private let stream: AsyncStream<RemoteHealthEvent>
    let continuation: AsyncStream<RemoteHealthEvent>.Continuation
    init() {
        let pair = AsyncStream<RemoteHealthEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }
    func events() -> AsyncStream<RemoteHealthEvent> { stream }
}

/// Pins the generation re-validation in PharmaControlSessionManager.
///
/// WHAT THE COUNTER ACTUALLY PROTECTS
///
/// `receive` takes the lock, applies the event, releases, then awaits
/// `loop.ingestHRV`, then re-takes the lock and re-checks `generation` before
/// writing `healthControlSnapshot`. If `stop()` lands during that suspension
/// the second check is the only thing preventing a snapshot computed for a
/// finished session from being written into the next one. Task cancellation
/// does not cover it: the task is already inside `receive`, past the loop's
/// cancellation check.
///
/// This test exists so that converting those sites to scoped locking becomes
/// a decision with evidence rather than an argument. It is deliberately
/// written BEFORE any such conversion, and it pins behaviour that exists
/// today regardless of whether the conversion ever happens.
final class SessionGenerationTests: XCTestCase {

    /// A snapshot computed for a session that stopped mid-computation must not
    /// be written. Stressed, because the window is the `ingestHRV` suspension
    /// and a single attempt may miss it.
    func testSnapshotFromAStoppedSessionIsDiscarded() async throws {
        for attempt in 0..<120 {
            let source = GateSource()
            let manager = PharmaControlSessionManager(healthSource: source)
            await manager.start()

            source.continuation.yield(.beatIntervals([800, 810, 795, 820, 805], Date()))
            // let `receive` get as far as the ingestHRV suspension
            await Task.yield()
            manager.stop()

            for _ in 0..<8 { await Task.yield() }
            try? await Task.sleep(for: .milliseconds(2))

            XCTAssertNil(
                manager.healthControlSnapshot,
                "attempt \(attempt): a control snapshot computed for a stopped session "
                + "was written into it — the generation re-validation did not hold")
            XCTAssertFalse(manager.isRunning, "attempt \(attempt): stop() did not take effect")
        }
    }

    /// The counter must actually move, or the re-validation compares a value
    /// to itself and can never reject anything.
    func testEachStartTakesAFreshGeneration() async {
        let manager = PharmaControlSessionManager(healthSource: GateSource())
        var seen: [Int] = []
        for _ in 0..<5 {
            await manager.start()
            seen.append(manager.currentGenerationForTesting)
            manager.stop()
        }
        XCTAssertEqual(Set(seen).count, seen.count, "two sessions shared a generation: \(seen)")
        XCTAssertEqual(seen, seen.sorted(), "generations must increase monotonically: \(seen)")
    }

    /// A live session still records its own snapshot — so the test above is
    /// pinning "stale writes are rejected", not "writes never happen".
    func testLiveSessionStillRecordsItsSnapshot() async throws {
        let source = GateSource()
        let manager = PharmaControlSessionManager(healthSource: source)
        await manager.start()
        source.continuation.yield(.beatIntervals([800, 810, 795, 820, 805], Date()))
        for _ in 0..<200 {
            if manager.healthControlSnapshot != nil { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertNotNil(manager.healthControlSnapshot,
                        "a running session recorded no snapshot; the stale-write test would "
                        + "then pass for the wrong reason")
        manager.stop()
    }
}
