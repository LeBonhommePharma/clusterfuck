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
        XCTAssertNil(nested?["access_token"])
        let scalar = SecretFieldPolicy.sanitizeWatchContext([
            "tokens": "sk-live",
            "type": "ok",
        ])
        XCTAssertNil(scalar["tokens"], "scalar secret bags must still be dropped")
        XCTAssertEqual(scalar["type"] as? String, "ok")
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
        // FlexAID∆S palette v2 — key colours are bound to quantities and never move.
        XCTAssertEqual(ClusterFuckPalette.primary, 0x8B5CF6)      // ΔS
        XCTAssertEqual(ClusterFuckPalette.secondary, 0x00A2FF)    // ΔS_vib
        XCTAssertEqual(ClusterFuckPalette.accent, 0x45E0A8)       // ΔH
        XCTAssertEqual(ClusterFuckPalette.tangerine, 0xFF9300)    // ΔG
        XCTAssertEqual(ClusterFuckPalette.magnesium, 0xDCDCE4)    // baseline
        XCTAssertEqual(ClusterFuckPalette.destructive, 0xF5232B)  // T
        XCTAssertEqual(ClusterFuckPalette.warning, 0xFF2F92)      // receptor
        // Surfaces track tokens.css, including the light theme.
        XCTAssertEqual(ClusterFuckPalette.lightBackground, 0xF4F6FB)
        XCTAssertEqual(ClusterFuckPalette.darkBackground, 0x08091A)
        XCTAssertEqual(ClusterFuckPalette.lightInk, 0x1E293B)
        XCTAssertEqual(ClusterFuckPalette.darkInk, 0xE4E3F5)
        XCTAssertEqual(ClusterFuckPalette.lightMute, 0x5A6478)
        XCTAssertEqual(ClusterFuckPalette.darkMute, 0x8D8CB0)
        XCTAssertEqual(ClusterFuckPalette.failTextLight, 0xBE123C)
        XCTAssertEqual(ClusterFuckIconSize.hit, 44)
        XCTAssertNil(ClusterFuckMotion.animation(reduceMotion: true))
        XCTAssertNotNil(ClusterFuckMotion.animation(reduceMotion: false))
        _ = ClusterFuckPressStyle()
        _ = ClusterFuckLoadingRow()
        XCTAssertEqual(ClusterFuckSymbol.sigma.systemName, "waveform.path.ecg")
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.0), .closed)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.15), .settling)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(0.2), .elevated)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(.nan), .unknown)
        XCTAssertEqual(ClusterFuckSigmaBand.classify(.infinity), .unknown)
        let rgba = ClusterFuckRGBA(hex: 0x45E0A8)
        XCTAssertEqual(rgba.green, Double(0xE0) / 255, accuracy: 0.001)
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

    /// Light-mode variants may move lightness but must preserve the key colour's
    /// identity — hue and chroma. Tolerance is rounding to 8-bit sRGB.
    func testLightVariantsPreserveHueAndChroma() {
        let pairs: [(String, UInt32, UInt32)] = [
            ("ΔS violet", ClusterFuckPalette.primary, ClusterFuckPalette.primaryLight),
            ("ΔS_vib aqua", ClusterFuckPalette.secondary, ClusterFuckPalette.secondaryLight),
            ("ΔH mint", ClusterFuckPalette.accent, ClusterFuckPalette.accentLight),
            ("ΔG tangerine", ClusterFuckPalette.tangerine, ClusterFuckPalette.tangerineLight),
            ("receptor strawberry", ClusterFuckPalette.warning, ClusterFuckPalette.warningLight),
            ("baseline magnesium", ClusterFuckPalette.magnesium, ClusterFuckPalette.magnesiumLight),
        ]
        for (name, dark, light) in pairs {
            let a = ThemeContrast.hsl(dark), b = ThemeContrast.hsl(light)
            XCTAssertEqual(a.hue, b.hue, accuracy: 1.0, "\(name): hue drifted")
            XCTAssertEqual(a.saturation, b.saturation, accuracy: 0.02, "\(name): chroma drifted")
            XCTAssertLessThan(b.lightness, a.lightness, "\(name): light variant must be darker")
        }
    }

    /// Every foreground/background pair the UI actually renders must clear WCAG AA.
    func testRenderedPairsClearWCAG() {
        let darkSurface = ThemeContrast.composite(0x111226, over: 0x08091A, alpha: 0.92)
        let lightBG = ClusterFuckPalette.lightBackground
        let lightCard = ClusterFuckPalette.lightSurface

        // Body and secondary text — 4.5:1.
        let bodyText: [(String, UInt32, UInt32)] = [
            ("dark ink on surface", ClusterFuckPalette.darkInk, darkSurface),
            ("dark mute on surface", ClusterFuckPalette.darkMute, darkSurface),
            ("dark mute on bg", ClusterFuckPalette.darkMute, ClusterFuckPalette.darkBackground),
            ("dark fail-text on surface", ClusterFuckPalette.failTextDark, darkSurface),
            ("light ink on card", ClusterFuckPalette.lightInk, lightCard),
            ("light mute on card", ClusterFuckPalette.lightMute, lightCard),
            ("light mute on bg", ClusterFuckPalette.lightMute, lightBG),
            ("light fail-text on bg", ClusterFuckPalette.failTextLight, lightBG),
            ("light receptor on bg", ClusterFuckPalette.warningLight, lightBG),
            ("light ΔS_vib on bg", ClusterFuckPalette.secondaryLight, lightBG),
            ("ink on mint CTA", ClusterFuckPalette.darkBackground, ClusterFuckPalette.accent),
        ]
        for (name, fg, bg) in bodyText {
            let r = ThemeContrast.ratio(fg, bg)
            XCTAssertGreaterThanOrEqual(r, 4.5, "\(name) is \(r):1, below AA body")
        }

        // Gauge strokes and other non-text indicators — 3:1.
        let nonText: [(String, UInt32, UInt32)] = [
            ("closed band on dark surface", ClusterFuckPalette.accent, darkSurface),
            ("settling band on dark surface", ClusterFuckPalette.primary, darkSurface),
            ("elevated band on dark surface", ClusterFuckPalette.warning, darkSurface),
            ("closed band on light card", ClusterFuckPalette.accentLight, lightCard),
            ("settling band on light card", ClusterFuckPalette.primaryLight, lightCard),
            ("elevated band on light card", ClusterFuckPalette.warningLight, lightCard),
        ]
        for (name, fg, bg) in nonText {
            let r = ThemeContrast.ratio(fg, bg)
            XCTAssertGreaterThanOrEqual(r, 3.0, "\(name) is \(r):1, below AA non-text")
        }
    }

    /// Retired v1 colours must never reappear in the palette.
    func testRetiredColoursAbsent() {
        let retired: Set<UInt32> = [
            0xFBBF24, // gold
            0xFDE68A, // pale gold
            0x22D3EE, // cyan
            0xC2456F, // salmon
            0xDA2F63, // wine
            0x6E7C99, // steel
            0xFF2600, // maraschino
            0x8B1A4A, // v1 terra
        ]
        let shipped: [UInt32] = [
            ClusterFuckPalette.primary, ClusterFuckPalette.secondary, ClusterFuckPalette.accent,
            ClusterFuckPalette.tangerine, ClusterFuckPalette.magnesium,
            ClusterFuckPalette.destructive, ClusterFuckPalette.warning,
            ClusterFuckPalette.primaryLight, ClusterFuckPalette.secondaryLight,
            ClusterFuckPalette.accentLight, ClusterFuckPalette.tangerineLight,
            ClusterFuckPalette.magnesiumLight, ClusterFuckPalette.warningLight,
            ClusterFuckPalette.failTextDark, ClusterFuckPalette.failTextLight,
            ClusterFuckPalette.lightBackground, ClusterFuckPalette.lightSurface,
            ClusterFuckPalette.darkBackground, ClusterFuckPalette.darkSurface,
            ClusterFuckPalette.lightInk, ClusterFuckPalette.darkInk,
            ClusterFuckPalette.lightMute, ClusterFuckPalette.darkMute,
            ClusterFuckPalette.border,
        ]
        for colour in shipped {
            XCTAssertFalse(
                retired.contains(colour),
                "retired v1 colour 0x\(String(colour, radix: 16, uppercase: true)) is back in the palette"
            )
        }
    }

}


/// WCAG 2.1 relative luminance and HSL, so the palette contract is computed
/// rather than transcribed.
enum ThemeContrast {
    static func channels(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
        (Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }

    static func composite(_ top: UInt32, over bottom: UInt32, alpha: Double) -> UInt32 {
        let t = channels(top), b = channels(bottom)
        func mix(_ x: Double, _ y: Double) -> UInt32 {
            UInt32((x * alpha + y * (1 - alpha)) * 255 + 0.5)
        }
        return (mix(t.r, b.r) << 16) | (mix(t.g, b.g) << 8) | mix(t.b, b.b)
    }

    static func luminance(_ hex: UInt32) -> Double {
        let c = channels(hex)
        func f(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func hsl(_ hex: UInt32) -> (hue: Double, saturation: Double, lightness: Double) {
        let c = channels(hex)
        let maxV = max(c.r, c.g, c.b), minV = min(c.r, c.g, c.b)
        let delta = maxV - minV
        let lightness = (maxV + minV) / 2
        guard delta > 0 else { return (0, 0, lightness) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        var hue: Double
        if maxV == c.r {
            hue = 60 * (((c.g - c.b) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxV == c.g {
            hue = 60 * ((c.b - c.r) / delta + 2)
        } else {
            hue = 60 * ((c.r - c.g) / delta + 4)
        }
        if hue < 0 { hue += 360 }
        return (hue, saturation, lightness)
    }
}
