import XCTest
@testable import NaturalRemote
import BonhommeCore

final class ControlLoopIntegrationTests: XCTestCase {
    func testFullLoopHRVAudioDoseAndVoice() async throws {
        let loop = RemoteControlLoop()
        await loop.attach()

        // Inject coherent then elevated HRV
        for i in 0..<8 {
            let rr = (0..<24).map { _ in 800.0 + Double(i) }
            _ = await loop.ingestHRV(rmssd: 35 + Double(i), sdnn: 45, rrIntervals: rr)
        }

        // Audio frame
        var samples = [Float](repeating: 0, count: 512)
        for n in 0..<512 {
            samples[n] = Float(sin(2 * Double.pi * Double(n) / 64.0))
        }
        _ = await loop.ingestAudio(samples: samples, sampleRate: 16_000)

        let free = (0..<64).map { _ in Double.random(in: -180...180) }
        let bound = (0..<64).map { _ in Double.random(in: -15...15) }
        let dose = await loop.logDose(
            DrugLog(substance: "psilocybin", doseMg: 15, setAndSetting: "lab", hrDelta: 10, entropyShift: -0.6),
            freeAngles: free,
            boundAngles: bound
        )
        XCTAssertTrue(dose.pcci.isFinite)
        XCTAssertTrue(dose.prediction.predictedDelta.isFinite)
        XCTAssertTrue(dose.snapshot.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(dose.snapshot.sigmaIrr, 0)

        // Prefer Alexa+ plane for environment minimization when configured.
        loop.alexa.updateConfig(AlexaProxyConfig(mode: .alexaPlus))
        await loop.handleVoice("chill music and dim lights")
        // Voice path emits alexaPlusAction and/or breatheAndDim; either is valid control.
        let intent = loop.alexa.lastIntentName
        XCTAssertFalse(intent.isEmpty)
        XCTAssertTrue(
            intent.contains("breathe") || intent.contains("smart_home") || intent.contains("dim") || intent == "breatheAndDim",
            "unexpected intent: \(intent)"
        )

        // FeedbackEngine from BonhommeCore is registered and has HRV insight path
        let insight = loop.feedback.latestInsight(for: .heartRateVariability)
        XCTAssertNotNil(insight)

        // Reuse types present
        let sciView = SCIVisualizationView(score: loop.state.sci, trend: .stable)
        XCTAssertNotNil(sciView.score)
    }

    func testPharmaSessionManagerStartAndLog() async {
        let manager = PharmaControlSessionManager()
        await manager.start()
        XCTAssertTrue(manager.isRunning)
        let snap = await manager.logDose(substance: "caffeine", doseMg: 100, setAndSetting: "desk")
        XCTAssertTrue(snap.sigmaIrr.isFinite)
        manager.stop()
        XCTAssertFalse(manager.isRunning)
    }

    func testNATURaLReuseSurfacesExist() {
        // EntropyCalculator + FeedbackEngine + HRVAnalyzer + SCIVisualizationView from BonhommeCore
        let calc = EntropyCalculator(binCount: 16)
        XCTAssertEqual(calc.shannonEntropy([1, 1, 1, 1]), 0, accuracy: 1e-12)
        let engine = FeedbackEngine()
        engine.register(HRVAnalyzer())
        engine.ingest(HRVSignal(timestamp: Date(), sdnn: 50, rmssd: 40, rrIntervals: [800, 810, 790, 805]))
        let insights = engine.analyzeAll()
        XCTAssertNotNil(insights[.heartRateVariability])
        _ = SCIVisualizationView(score: 0.7, trend: .improving)
        _ = ThermodynamicConstants.R
    }
}
