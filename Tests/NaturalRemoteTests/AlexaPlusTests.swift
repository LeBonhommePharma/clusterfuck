import XCTest
@testable import NaturalRemote

final class AlexaPlusTests: XCTestCase {
    func testResolveModePrefersAlexaPlusWhenEndpointConfigured() {
        let alexa = AlexaProxyController(config: AlexaProxyConfig(
            mode: .auto,
            alexaPlusEndpoint: URL(string: "https://example.com/alexa-plus")!
        ))
        XCTAssertEqual(alexa.resolveMode(), .alexaPlus)
    }

    func testResolveModeFallsBackToSmartHomeThenProxy() {
        let sh = AlexaProxyController(config: AlexaProxyConfig(
            mode: .auto,
            smartHomeEndpoint: URL(string: "https://example.com/smarthome")!
        ))
        XCTAssertEqual(sh.resolveMode(), .smartHomeV3)

        let proxy = AlexaProxyController(config: AlexaProxyConfig(mode: .auto))
        XCTAssertEqual(proxy.resolveMode(), .skillProxy)
    }

    func testAlexaPlusActionRecordsExpertAndUtterance() async throws {
        let alexa = AlexaProxyController(config: AlexaProxyConfig(mode: .alexaPlus))
        var hooks: [String] = []
        let box = HookBox()
        alexa.transportHook = { action, params in
            await box.append("\(action):\(params["expert"] ?? "")")
        }
        try await alexa.invokeAlexaPlusAction(
            AlexaPlusAction(
                expert: "smart_home",
                utterance: "dim lights to 30 percent",
                slots: ["brightness": "30"]
            )
        )
        let recorded = await box.values()
        XCTAssertTrue(recorded.contains { $0.contains("alexaPlusAction") })
        XCTAssertEqual(alexa.lastAPIModeUsed, .alexaPlus)
        XCTAssertEqual(alexa.lastAlexaPlusAction?.expert, "smart_home")
        XCTAssertTrue(alexa.lastAlexaPlusAction?.utterance.contains("dim") == true)
        _ = hooks
    }

    func testBreatheAndDimOnAlexaPlusBuildsUtterance() async throws {
        let alexa = AlexaProxyController(config: AlexaProxyConfig(mode: .alexaPlus))
        let box = HookBox()
        alexa.transportHook = { action, params in
            await box.append(action)
            if let u = params["utterance"] { await box.append(u) }
        }
        try await alexa.invokeRoutine("breatheAndDim", params: ["lights": "30"])
        XCTAssertEqual(alexa.lightsPercent, 30)
        XCTAssertEqual(alexa.lastAPIModeUsed, .alexaPlus)
        let plus = alexa.lastAlexaPlusAction
        XCTAssertNotNil(plus)
        XCTAssertTrue(plus!.utterance.lowercased().contains("breathe") || plus!.utterance.lowercased().contains("30"))
    }

    func testSmartHomeBrightnessDirective() async throws {
        let alexa = AlexaProxyController(config: AlexaProxyConfig(mode: .smartHomeV3))
        try await alexa.execute(
            RemoteCommand(service: .alexa, action: "smartHomeSetBrightness", params: ["brightness": "40"])
        )
        XCTAssertEqual(alexa.lastAPIModeUsed, .smartHomeV3)
        XCTAssertEqual(alexa.lastSmartHomeDirective?.namespace, "Alexa.BrightnessController")
        XCTAssertEqual(alexa.lastSmartHomeDirective?.name, "SetBrightness")
        XCTAssertEqual(alexa.lastSmartHomeDirective?.payload["brightness"], "40")
    }

    func testSetModeCommandSwitchesPlane() async throws {
        let alexa = AlexaProxyController(config: AlexaProxyConfig(mode: .skillProxy))
        try await alexa.execute(RemoteCommand(service: .alexa, action: "setMode", params: ["mode": "alexaPlus"]))
        XCTAssertEqual(alexa.config.mode, .alexaPlus)
    }

    func testFoundationModelEmitsAlexaPlusCommandOnChill() async {
        let fm = FoundationModelOrchestrator()
        let cmds = await fm.parseVoice("chill music and dim lights", currentSCI: 0.4, sigmaIrr: 0.2, phase: .reverse)
        XCTAssertTrue(cmds.contains { $0.service == .alexa && $0.action == "alexaPlusAction" })
        XCTAssertTrue(cmds.contains { $0.service == .alexa && $0.action == "breatheAndDim" })
    }
}

/// Actor-safe hook accumulator for async transport hooks under Swift 6.
private actor HookBox {
    private var items: [String] = []
    func append(_ s: String) { items.append(s) }
    func values() -> [String] { items }
}
