import XCTest
@testable import NaturalRemote

final class HonestyContractsTests: XCTestCase {
    func testDefaultDeltaGIsSpecHalfTenth() async {
        let crooks = CrooksCycleController()
        let snap = await crooks.snapshot()
        XCTAssertEqual(snap.deltaG, 0.05, accuracy: 1e-12)
        XCTAssertEqual(CrooksMath.shouldMinimize(sigmaIrr: 0.15), false)
        XCTAssertEqual(CrooksMath.shouldMinimize(sigmaIrr: 0.151), true)
        XCTAssertEqual(CrooksMath.shouldMinimize(sigmaIrr: .nan), false)
        XCTAssertEqual(CrooksMath.closurePercent(sigmaIrr: .infinity), 0, accuracy: 1e-12)
    }

    func testMinimizeSummaryDoesNotClaimUnregisteredActuators() async {
        let crooks = CrooksCycleController()
        await crooks.minimizeSigma(currentBPM: 120)
        let summary = await crooks.snapshot().lastActionSummary
        XCTAssertTrue(summary.contains("unregistered"), summary)
        XCTAssertFalse(summary.contains("unregistered") && summary.split(separator: "+").contains(where: { $0 == "spotify" }))
        for token in ["spotify", "alexa", "airPods", "researchKit"] {
            XCTAssertTrue(summary.contains("\(token):unregistered"), summary)
        }
    }

    func testMinimizeSummaryRecordsFailureNotSuccess() async {
        let bus = ActuatorBus()
        bus.register(ThrowingActuator(service: .spotify))
        bus.register(RecordingActuator(service: .appleMusic))
        bus.register(RecordingActuator(service: .sonos))
        bus.register(RecordingActuator(service: .diFm))
        bus.register(RecordingActuator(service: .alexa))
        bus.register(RecordingActuator(service: .airPods))
        bus.register(RecordingActuator(service: .foundationModel))
        bus.register(RecordingActuator(service: .researchKit))
        let crooks = CrooksCycleController(bus: bus)
        await crooks.minimizeSigma(currentBPM: 130)
        let summary = await crooks.snapshot().lastActionSummary
        XCTAssertTrue(summary.contains("spotify:failed"), summary)
        XCTAssertFalse(summary.split(separator: "+").contains("spotify"))
    }

    func testTwoLoopsDoNotSharePharmacovigilanceRecords() async {
        let a = RemoteControlLoop()
        let b = RemoteControlLoop()
        await a.attach()
        _ = await a.logDose(DrugLog(substance: "caffeine", doseMg: 80, setAndSetting: "desk"))
        XCTAssertFalse(a.drugKit.allPharmacovigilanceRecords().isEmpty)
        XCTAssertTrue(
            b.drugKit.allPharmacovigilanceRecords().isEmpty,
            "RemoteControlLoop must not share DrugKitEngine.shared PV state"
        )
    }

    func testSurveyApplyIsIdempotentOnSCI() async {
        let loop = RemoteControlLoop()
        await loop.attach()
        _ = await loop.ingestHRV(rmssd: 40, sdnn: 50, rrIntervals: Array(repeating: 800, count: 16))
        let phys = loop.state.physiologicalSCI
        _ = await loop.ingestSurvey(instrument: .currentStateLog, rawScore: 9)
        let sci1 = loop.state.sci
        _ = await loop.ingestSurvey(instrument: .currentStateLog, rawScore: 9)
        XCTAssertEqual(loop.state.sci, sci1, accuracy: 1e-12, "second identical survey must not ratchet SCI")
        XCTAssertEqual(loop.state.physiologicalSCI, phys, accuracy: 1e-12)
        XCTAssertNotEqual(sci1, phys, accuracy: 1e-12)
    }

    func testObservedDeltaIsNotAPredictorFeature() {
        let mapper = DeltaHRVFlexAIDMapper(weights: [4, 0.02, -8, 0.01], bias: 2)
        let low = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: 0,
            flexAIDDeltaS: -0.5,
            doseMg: 10,
            baselineSCI: 0.7,
            substanceID: 1
        )
        let high = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: 500,
            flexAIDDeltaS: -0.5,
            doseMg: 10,
            baselineSCI: 0.7,
            substanceID: 1
        )
        XCTAssertEqual(mapper.predict(low).predictedDelta, mapper.predict(high).predictedDelta, accuracy: 1e-12)
        XCTAssertFalse(low.vector.contains(500))
        XCTAssertEqual(low.vector.count, 4)
    }

    func testHTTPHonestyRejectsNonSuccess() {
        XCTAssertThrowsError(try RemoteHTTPHonesty.requireSuccess(nil))
        XCTAssertThrowsError(try RemoteHTTPHonesty.requireSuccess(500))
        XCTAssertThrowsError(try RemoteHTTPHonesty.requireSuccess(404))
        XCTAssertNoThrow(try RemoteHTTPHonesty.requireSuccess(200))
        XCTAssertNoThrow(try RemoteHTTPHonesty.requireSuccess(204))
    }

    func testSecretPolicyStripsTokensFromWatchContext() {
        let dirty: [String: Any] = [
            "type": "token_refresh",
            "accessToken": "sk-secret",
            "tokens": ["access_token": "abc", "refresh_token": "def", "device": "watch"],
        ]
        let clean = SecretFieldPolicy.sanitizeWatchContext(dirty)
        XCTAssertEqual(clean["type"] as? String, "token_refresh")
        XCTAssertNil(clean["accessToken"])
        let nested = clean["tokens"] as? [String: String]
        XCTAssertEqual(nested, ["device": "watch"])
        XCTAssertTrue(SecretFieldPolicy.isSecretKey("listen_key"))
        XCTAssertFalse(SecretFieldPolicy.isSecretKey("substance"))
    }

    func testVoiceWhatsUpDoesNotExplore() async {
        let fm = FoundationModelOrchestrator()
        let cmds = await fm.parseVoice("what's up", currentSCI: 0.8, sigmaIrr: 0.01, phase: .forward)
        XCTAssertFalse(cmds.contains { $0.action == "preferProgressiveChannel" })
        XCTAssertFalse(cmds.contains { $0.action == "transparency" })
        let explore = await fm.parseVoice("explore energy", currentSCI: 0.8, sigmaIrr: 0.01, phase: .forward)
        XCTAssertTrue(explore.contains { $0.action == "preferProgressiveChannel" })
    }

    func testDoseExportIncludesAirPodsNoiseMode() async throws {
        let loop = RemoteControlLoop()
        await loop.attach()
        try await loop.bus.execute(RemoteCommand(service: .airPods, action: "enableANC"))
        _ = await loop.logDose(DrugLog(substance: "caffeine", doseMg: 50, setAndSetting: "lab"))
        let rec = try XCTUnwrap(loop.drugKit.allPharmacovigilanceRecords().last)
        XCTAssertEqual(rec.airPodsNoiseMode, NoiseControlMode.noiseCancellation.rawValue)
        let json = try loop.drugKit.exportPharmacovigilanceJSON()
        let decoded = try PharmacovigilanceExporter.decode(json)
        XCTAssertEqual(decoded.last?.airPodsNoiseMode, rec.airPodsNoiseMode)
    }

    func testThemeTokensMatchMASTER() {
        XCTAssertEqual(ClusterFuckPalette.primary, 0x0284C7)
        XCTAssertEqual(ClusterFuckPalette.secondary, 0x0891B2)
        XCTAssertEqual(ClusterFuckPalette.accent, 0x16A34A)
        XCTAssertEqual(ClusterFuckPalette.lightBackground, 0xF0F9FF)
        XCTAssertEqual(ClusterFuckPalette.darkBackground, 0x0F0F23)
        XCTAssertEqual(ClusterFuckPalette.destructive, 0xDC2626)
        XCTAssertEqual(ClusterFuckPalette.warning, 0xF97316)
        XCTAssertEqual(ClusterFuckIconSize.hit, 44)
        XCTAssertNil(ClusterFuckMotion.animation(reduceMotion: true))
        XCTAssertNotNil(ClusterFuckMotion.animation(reduceMotion: false))
        XCTAssertEqual(ClusterFuckSymbol.sigma.systemName, "waveform.path.ecg")
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.0), .closed)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.15), .settling)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.2), .elevated)
        let rgba = ClusterFuckRGBA(hex: 0x0284C7)
        XCTAssertEqual(rgba.red, Double(0x02) / 255, accuracy: 0.001)
        XCTAssertEqual(rgba.alpha, 1)
    }

    func testNonClinicalDemoFlagHidesPsychedelicCopy() {
        let engine = DrugKitEngine()
        engine.nonClinicalDemoMode = false
        let text = engine.predictInteraction(substance: "LSD")
        XCTAssertFalse(text.contains("5-HT2A"))
        XCTAssertTrue(text.contains("Clinical guidance disabled"))
    }
}

private enum HonestyTestError: Error { case boom }

private final class ThrowingActuator: RemoteActuator, @unchecked Sendable {
    let service: RemoteService
    init(service: RemoteService) { self.service = service }
    func execute(_ command: RemoteCommand) async throws { throw HonestyTestError.boom }
}
