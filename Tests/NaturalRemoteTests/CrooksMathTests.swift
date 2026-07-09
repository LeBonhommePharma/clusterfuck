import XCTest
@testable import NaturalRemote

final class CrooksMathTests: XCTestCase {
    func testSigmaIrrNonNegativeAndFormula() {
        let s = CrooksMath.sigmaIrr(workFwd: 10, workRev: 4, deltaG: -8.2)
        // 10 + 4 - 2*(-8.2) = 14 + 16.4 = 30.4
        XCTAssertEqual(s, 30.4, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(s, 0)
    }

    func testSigmaIrrClampedAtZero() {
        let s = CrooksMath.sigmaIrr(workFwd: 0.01, workRev: 0.01, deltaG: 5)
        XCTAssertEqual(s, 0, accuracy: 1e-12)
    }

    func testClosurePercentMonotoneInSigma() {
        let high = CrooksMath.closurePercent(sigmaIrr: 0.01)
        let low = CrooksMath.closurePercent(sigmaIrr: 1.0)
        XCTAssertGreaterThan(high, low)
        XCTAssertLessThanOrEqual(high, 100)
        XCTAssertGreaterThanOrEqual(low, 0)
    }

    func testInstantaneousWorkChangesWithBPM() {
        var a = RemoteMultiSignalState(musicBPM: 80, audioEntropyBits: 1)
        var b = RemoteMultiSignalState(musicBPM: 140, audioEntropyBits: 1)
        let wa = CrooksMath.instantaneousWork(from: a)
        let wb = CrooksMath.instantaneousWork(from: b)
        XCTAssertNotEqual(wa, wb, accuracy: 1e-12)
        XCTAssertGreaterThan(wb, wa)
    }

    func testAccumulateWorkByPhase() {
        let f = CrooksMath.accumulateWork(phase: .forward, workFwd: 1, workRev: 2, sampleWork: 0.5)
        XCTAssertEqual(f.workFwd, 1.5, accuracy: 1e-12)
        XCTAssertEqual(f.workRev, 2, accuracy: 1e-12)
        let r = CrooksMath.accumulateWork(phase: .reverse, workFwd: 1, workRev: 2, sampleWork: 0.5)
        XCTAssertEqual(r.workFwd, 1, accuracy: 1e-12)
        XCTAssertEqual(r.workRev, 2.5, accuracy: 1e-12)
    }

    func testTargetBPMReversePullsDown() {
        let bpm = CrooksMath.targetBPM(phase: .reverse, currentBPM: 140, sigmaIrr: 0.5)
        XCTAssertLessThan(bpm, 140)
        XCTAssertGreaterThanOrEqual(bpm, 72)
    }
}
