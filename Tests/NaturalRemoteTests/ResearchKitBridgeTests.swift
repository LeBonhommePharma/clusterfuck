import XCTest
@testable import NaturalRemote
import BonhommeCore

final class ResearchKitBridgeTests: XCTestCase {
    func testInjectSurveyNormalizesAndIngestsFeedbackEngine() {
        let engine = FeedbackEngine()
        let bridge = ResearchKitBridge(feedbackEngine: engine)

        let pain = bridge.injectSurvey(instrument: .painVAS, rawScore: 8)
        XCTAssertEqual(pain.instrument, .painVAS)
        XCTAssertLessThan(pain.normalizedScore, 0.5, "high pain → low wellness normalized")
        XCTAssertGreaterThan(pain.crooksSubjectiveWorkHint, 0)

        let mood = bridge.injectSurvey(instrument: .moodLikert, rawScore: 5)
        XCTAssertGreaterThan(mood.normalizedScore, 0.9)

        // Survey signals are in FeedbackEngine (BonhommeCore SurveySignal path)
        engine.ingest(SurveySignal(
            timestamp: Date(),
            instrumentId: ResearchKitInstrument.doseEffectRating.rawValue,
            normalizedScore: 0.5,
            responses: ["score": "3"]
        ))
        // Bridge itself already ingested on inject; buffer should be non-empty via re-analyze path
        XCTAssertEqual(bridge.latestSurveyResults.count, 2)
        XCTAssertEqual(bridge.lastNormalizedScore ?? -1, mood.normalizedScore, accuracy: 1e-12)
    }

    func testResearchKitActuatorBusRegistration() async throws {
        let bus = ActuatorBus()
        let bridge = ResearchKitBridge()
        bus.register(bridge)
        try await bus.execute(RemoteCommand(
            service: .researchKit,
            action: "inject",
            params: ["instrument": "dose-effect-rating", "score": "4"]
        ))
        XCTAssertEqual(bridge.latestSurveyResults.last?.instrument, .doseEffectRating)
        XCTAssertEqual(bridge.latestSurveyResults.last?.rawScore ?? -1, 4, accuracy: 1e-12)
        let events = bus.recordedEvents()
        XCTAssertTrue(events.contains { $0.service == .researchKit })
    }

    func testControlLoopSurveyFeedsCrooks() async {
        let loop = RemoteControlLoop()
        await loop.attach()
        let before = await loop.crooks.snapshot()
        let (_, afterSnap) = await loop.ingestSurvey(instrument: .currentStateLog, rawScore: 9)
        XCTAssertTrue(afterSnap.sigmaIrr.isFinite)
        XCTAssertGreaterThanOrEqual(afterSnap.sigmaIrr, 0)
        // High intensity survey should move work / sigma relative to empty controller start
        XCTAssertNotEqual(before.workFwd + before.workRev, afterSnap.workFwd + afterSnap.workRev, accuracy: 1e-12)
        XCTAssertFalse(loop.researchKit.latestSurveyResults.isEmpty)
    }

    func testDescriptorCatalogComplete() {
        for inst in ResearchKitInstrument.allCases {
            let d = ResearchKitBridge().descriptor(for: inst)
            XCTAssertFalse(d.title.isEmpty)
            XCTAssertFalse(d.question.isEmpty)
            XCTAssertEqual(d.instrument, inst)
        }
    }

    func testMinimizePromptsResearchKit() async {
        let bus = ActuatorBus()
        let rk = ResearchKitBridge()
        bus.register(rk)
        bus.register(RecordingActuator(service: .appleMusic))
        bus.register(RecordingActuator(service: .spotify))
        bus.register(RecordingActuator(service: .sonos))
        bus.register(RecordingActuator(service: .diFm))
        bus.register(RecordingActuator(service: .alexa))
        bus.register(RecordingActuator(service: .airPods))
        bus.register(RecordingActuator(service: .foundationModel))
        let crooks = CrooksCycleController(deltaG: -8.2, bus: bus)
        await crooks.minimizeSigma(currentBPM: 120)
        XCTAssertTrue(rk.isPromptPending)
        let events = await crooks.recordedEvents()
        XCTAssertTrue(events.contains { $0.service == .researchKit })
    }

    /// Regression: one survey + two HRV ingests must not double subjective / alexa entropy hints.
    func testSurveyOnceTwoHRVDoesNotDoubleSubjectiveHint() async {
        let loop = RemoteControlLoop()
        await loop.attach()

        // High intensity survey once
        _ = await loop.ingestSurvey(instrument: .currentStateLog, rawScore: 9)
        let afterSurvey = loop.state
        let hintAfterSurvey = afterSurvey.subjectiveWorkHint
        let alexaAfterSurvey = afterSurvey.alexaEntropyHint
        XCTAssertGreaterThan(hintAfterSurvey, 0, "survey should set subjectiveWorkHint")
        XCTAssertEqual(alexaAfterSurvey, 0, accuracy: 1e-12, "survey must not mutate alexaEntropyHint")

        // Two HRV ticks (each path calls researchKit.apply)
        let rr = Array(repeating: 800.0, count: 16)
        _ = await loop.ingestHRV(rmssd: 40, sdnn: 50, rrIntervals: rr)
        let afterHRV1 = loop.state
        _ = await loop.ingestHRV(rmssd: 42, sdnn: 51, rrIntervals: rr)
        let afterHRV2 = loop.state

        XCTAssertEqual(
            afterHRV1.subjectiveWorkHint,
            hintAfterSurvey,
            accuracy: 1e-12,
            "first HRV re-apply must not grow subjectiveWorkHint"
        )
        XCTAssertEqual(
            afterHRV2.subjectiveWorkHint,
            afterHRV1.subjectiveWorkHint,
            accuracy: 1e-12,
            "second HRV re-apply must not grow subjectiveWorkHint"
        )
        XCTAssertEqual(afterHRV2.alexaEntropyHint, alexaAfterSurvey, accuracy: 1e-12)
        XCTAssertEqual(
            afterHRV2.subjectiveWorkHint,
            loop.researchKit.lastSubjectiveWorkHint,
            accuracy: 1e-12,
            "state field must equal last survey recompute, not a running sum"
        )
    }
}
