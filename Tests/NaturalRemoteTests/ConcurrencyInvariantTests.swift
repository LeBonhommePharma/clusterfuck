import XCTest
@testable import NaturalRemote

/// Behavioural pins for the shared mutable state that NSLock guards.
///
/// These exist so the async-safe-scoped-locking change can be shown to
/// preserve behaviour rather than merely to silence a warning. Each asserts an
/// invariant that only holds while mutual exclusion holds, and each has been
/// demonstrated FAILING with the corresponding lock removed — a test that
/// passes both with and without the lock proves nothing about the lock.
final class ConcurrencyInvariantTests: XCTestCase {

    /// Every concurrent execute must record exactly one event. A racing
    /// `events.append` drops writes, so the count comes out short.
    func testActuatorBusRecordsEveryConcurrentExecute() async throws {
        let bus = ActuatorBus()
        bus.register(CountingActuator())
        let n = 5000
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    try? await bus.execute(
                        RemoteCommand(service: .spotify, action: "play", params: ["i": "\(i)"]))
                }
            }
        }
        XCTAssertEqual(bus.recordedEvents().count, n,
                       "lost events under concurrency — mutual exclusion is broken")
    }

    /// Registration and execution race against the same dictionary.
    func testActuatorBusSurvivesConcurrentRegistrationAndExecution() async throws {
        let bus = ActuatorBus()
        let n = 150
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<n {
                group.addTask { bus.register(CountingActuator()) }
                group.addTask {
                    try? await bus.execute(RemoteCommand(service: .spotify, action: "play"))
                }
            }
        }
        XCTAssertEqual(bus.recordedEvents().count, n,
                       "lost events while the actuator table was mutated concurrently")
    }

    /// Every concurrent dose log must land. A racing array append loses them.
    func testDrugKitLogsEveryConcurrentEntry() async throws {
        let engine = DrugKitEngine()
        let n = 300
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    engine.log(DrugLog(substance: "s\(i)", doseMg: Double(i), setAndSetting: "lab"))
                }
            }
        }
        XCTAssertEqual(engine.allLogs().count, n, "lost dose logs under concurrency")
    }

    /// Pharmacovigilance records are the audit trail; losing one is silent
    /// data loss in the thing this app exists to produce.
    func testPharmacovigilanceRecordsAreNotLost() async throws {
        let engine = DrugKitEngine()
        let n = 200
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    engine.recordPharmacovigilance(
                        PharmacovigilanceRecord(
                            substance: "s\(i)", doseMg: Double(i), setAndSetting: "lab",
                            observedDeltaHRV: 0, predictedDeltaHRV: 0, deviation: 0,
                            action: "none", sci: 0.5, pcci: 0.5, sigmaIrr: 0.01,
                            crooksPhase: "forward", closurePercent: 99, musicBPM: 90,
                            audioEntropyBits: 1, alexaLightsPercent: 40, flexAIDDeltaS: 0))
                }
            }
        }
        XCTAssertEqual(engine.allPharmacovigilanceRecords().count, n,
                       "lost pharmacovigilance records under concurrency")
    }

    /// A reader running against a concurrent writer must never observe a torn
    /// or partially-mutated array.
    func testConcurrentReadersSeeConsistentSnapshots() async throws {
        let engine = DrugKitEngine()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    engine.log(DrugLog(substance: "s\(i)", doseMg: 1, setAndSetting: ""))
                }
                group.addTask {
                    let snapshot = engine.allLogs()
                    XCTAssertTrue(snapshot.allSatisfy { $0.doseMg >= 0 },
                                  "observed a torn snapshot")
                }
            }
        }
        XCTAssertEqual(engine.allLogs().count, 200)
    }
}

private final class CountingActuator: RemoteActuator, @unchecked Sendable {
    let service: RemoteService = .spotify
    func execute(_ command: RemoteCommand) async throws {
        // A real suspension, so the bus genuinely interleaves.
        await Task.yield()
    }
}
