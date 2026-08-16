import XCTest
@testable import NaturalRemote
import BonhommeCore

final class DeltaHRVFlexAIDTests: XCTestCase {
    func testDeltaHRVChangesAcrossWindows() {
        let analyzer = DeltaHRVAnalyzer(windowSeconds: 1000)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<10 {
            _ = analyzer.ingest(rmssd: 30, sdnn: 40, rrIntervals: Array(repeating: 800, count: 16), at: t0.addingTimeInterval(Double(i)))
        }
        let early = analyzer.latestDeltaRMSSD()
        for i in 10..<30 {
            _ = analyzer.ingest(rmssd: 80, sdnn: 90, rrIntervals: Array(repeating: 700, count: 16), at: t0.addingTimeInterval(Double(i)))
        }
        let late = analyzer.latestDeltaRMSSD()
        XCTAssertNotEqual(early, late, accuracy: 1e-9)
    }

    func testFlexAIDDeltaSUsesBonhommeEntropy() {
        let mapper = DeltaHRVFlexAIDMapper()
        // Free: broad angles; bound: tight cluster → negative ΔS
        let free = (0..<200).map { _ in Double.random(in: -180...180) }
        let bound = (0..<200).map { _ in Double.random(in: -10...10) }
        let dS = mapper.flexAIDDeltaS(freeAngles: free, boundAngles: bound)
        XCTAssertLessThan(dS, 0, "binding should reduce configurational entropy")
        let penalty = mapper.entropyPenaltyKcal(deltaSBits: dS)
        XCTAssertTrue(penalty.isFinite)
    }

    func testHybridPredictionDeviationPath() {
        // Observed Δ is not a model feature, so the prediction is independent of observed Δ.
        let mapper = DeltaHRVFlexAIDMapper(
            bias: 10,
            deviationThreshold: 0.2
        )
        let base = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: 0,
            flexAIDDeltaS: -0.5,
            doseMg: 10,
            baselineSCI: 0.7,
            substanceID: 1
        )
        let predicted = mapper.predict(base).predictedDelta
        let coherent = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: predicted,
            flexAIDDeltaS: -0.5,
            doseMg: 10,
            baselineSCI: 0.7,
            substanceID: 1
        )
        let ok = mapper.predict(coherent)
        XCTAssertEqual(ok.action, "coherent_continue")
        XCTAssertLessThan(ok.deviation, 0.2)

        let wild = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: predicted + 500,
            flexAIDDeltaS: -0.5,
            doseMg: 10,
            baselineSCI: 0.7,
            substanceID: 1
        )
        let alert = mapper.predict(wild)
        XCTAssertEqual(alert.action, "grounding_alert")
        XCTAssertTrue(alert.isGroundingAlert)
        XCTAssertGreaterThan(alert.deviation, 0.2)
    }

    func testSubstanceIDDeterministicAcrossCalls() {
        // FNV-1a is stable per-process-run, unlike String.hashValue (SipHash, per-process seed).
        XCTAssertEqual(stableSubstanceID("LSD"), 4084)
        XCTAssertEqual(stableSubstanceID("2C-B"), 1597)
        XCTAssertEqual(stableSubstanceID("psilocybin"), 4387)
        XCTAssertNotEqual(stableSubstanceID("LSD"), stableSubstanceID("MDMA"))
    }

    func testEigenMetalPCCIInUnitInterval() {
        let bridge = EigenMetalBridge()
        let pcci = bridge.computePCCI([0.8, 0.73, 0.4, 1.2, 0.9])
        XCTAssertGreaterThanOrEqual(pcci, 0)
        XCTAssertLessThanOrEqual(pcci, 1)
        let (value, ms) = bridge.benchmark(iterations: 50)
        XCTAssertTrue(value.isFinite)
        XCTAssertGreaterThanOrEqual(ms, 0)
    }

    func testDrugKitAnalyzeWithFlexAID() {
        let engine = DrugKitEngine()
        let log = DrugLog(substance: "LSD", doseMg: 0.1, hrDelta: 12, entropyShift: -0.8)
        let pred = engine.analyzeWithFlexAID(log, observedDelta: 20, baselineSCI: 0.6)
        XCTAssertTrue(pred.predictedDelta.isFinite)
        XCTAssertTrue(pred.deviation.isFinite)
        let text = engine.predictInteraction(substance: "LSD")
        XCTAssertTrue(text.contains("5-HT2A"))
    }

    func testPharmacovigilanceExportRoundTrip() throws {
        let engine = DrugKitEngine()
        let record = PharmacovigilanceRecord(
            substance: "2C-B",
            doseMg: 12,
            setAndSetting: "home / lo-fi",
            observedDeltaHRV: 18,
            predictedDeltaHRV: 12,
            deviation: 0.5,
            action: "grounding_alert",
            sci: 0.55,
            pcci: 0.7,
            sigmaIrr: 0.22,
            crooksPhase: "reverse",
            closurePercent: 40,
            musicBPM: 88,
            audioEntropyBits: 2.1,
            alexaLightsPercent: 30,
            flexAIDDeltaS: -0.6
        )
        engine.recordPharmacovigilance(record)
        let data = try engine.exportPharmacovigilanceJSON()
        let decoded = try PharmacovigilanceExporter.decode(data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].substance, "2C-B")
        XCTAssertEqual(decoded[0].action, "grounding_alert")
        XCTAssertEqual(NaturalRemoteInfo.strategicRole, "primary_pharmacovigilance_candidate")
    }
}
