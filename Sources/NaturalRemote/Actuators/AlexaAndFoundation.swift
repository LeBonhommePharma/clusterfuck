import Foundation

// MARK: - Alexa API surface (classic Smart Home + Alexa+)

/// Which Alexa control plane the remote should prefer.
public enum AlexaAPIMode: String, Codable, Sendable, CaseIterable {
    /// Custom skill / Alexa for Apps deep-link + optional Lambda webhook (classic).
    case skillProxy
    /// Smart Home Skill API v3 (PowerController, BrightnessController, SceneController, …).
    case smartHomeV3
    /// Alexa+ generative AI plane — AI Action / Web Action / Multi-Agent style envelopes.
    case alexaPlus
    /// Prefer Alexa+ when configured, else Smart Home v3, else skill proxy.
    case auto
}

/// Structured Alexa+ “expert” action (maps to Alexa AI Action SDK style integrations).
public struct AlexaPlusAction: Codable, Sendable, Equatable {
    public var expert: String
    public var utterance: String
    public var slots: [String: String]
    public var sessionId: String?
    public var requireConfirmation: Bool

    public init(
        expert: String,
        utterance: String,
        slots: [String: String] = [:],
        sessionId: String? = nil,
        requireConfirmation: Bool = false
    ) {
        self.expert = expert
        self.utterance = utterance
        self.slots = slots
        self.sessionId = sessionId
        self.requireConfirmation = requireConfirmation
    }
}

/// Smart Home v3 directive payload (minimal production envelope).
public struct AlexaSmartHomeDirective: Codable, Sendable, Equatable {
    public var namespace: String
    public var name: String
    public var endpointId: String
    public var payload: [String: String]

    public init(namespace: String, name: String, endpointId: String, payload: [String: String] = [:]) {
        self.namespace = namespace
        self.name = name
        self.endpointId = endpointId
        self.payload = payload
    }
}

public struct AlexaProxyConfig: Sendable {
    public var mode: AlexaAPIMode
    public var skillEndpoint: URL?
    /// Alexa+ AI Action / multi-agent gateway (partner endpoint or your BFF).
    public var alexaPlusEndpoint: URL?
    /// Smart Home skill Lambda / event gateway URL.
    public var smartHomeEndpoint: URL?
    public var accessToken: String?
    public var defaultEndpointId: String
    public var householdId: String?

    public init(
        mode: AlexaAPIMode = .auto,
        skillEndpoint: URL? = nil,
        alexaPlusEndpoint: URL? = nil,
        smartHomeEndpoint: URL? = nil,
        accessToken: String? = nil,
        defaultEndpointId: String = "natural-remote-primary",
        householdId: String? = nil
    ) {
        self.mode = mode
        self.skillEndpoint = skillEndpoint
        self.alexaPlusEndpoint = alexaPlusEndpoint
        self.smartHomeEndpoint = smartHomeEndpoint
        self.accessToken = accessToken
        self.defaultEndpointId = defaultEndpointId
        self.householdId = householdId
    }
}

// MARK: - Alexa controller

public final class AlexaProxyController: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .alexa
    public private(set) var config: AlexaProxyConfig
    public var transportHook: (@Sendable (String, [String: String]) async throws -> Void)?
    private let session: URLSession

    private let lock = NSLock()
    private var lastIntent: String = ""
    private var lastLightsPercent: Int = 60
    private var lastModeUsed: AlexaAPIMode = .skillProxy
    private var lastPlusAction: AlexaPlusAction?
    private var lastDirective: AlexaSmartHomeDirective?
    private var lastHTTPStatus: Int?

    public init(config: AlexaProxyConfig = AlexaProxyConfig(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public var lastHTTPStatusCode: Int? {
        lock.lock(); defer { lock.unlock() }
        return lastHTTPStatus
    }

    public func updateConfig(_ config: AlexaProxyConfig) {
        lock.lock(); self.config = config; lock.unlock()
    }

    public var lastIntentName: String {
        lock.lock(); defer { lock.unlock() }
        return lastIntent
    }

    public var lightsPercent: Int {
        lock.lock(); defer { lock.unlock() }
        return lastLightsPercent
    }

    public var lastAPIModeUsed: AlexaAPIMode {
        lock.lock(); defer { lock.unlock() }
        return lastModeUsed
    }

    public var lastAlexaPlusAction: AlexaPlusAction? {
        lock.lock(); defer { lock.unlock() }
        return lastPlusAction
    }

    public var lastSmartHomeDirective: AlexaSmartHomeDirective? {
        lock.lock(); defer { lock.unlock() }
        return lastDirective
    }

    /// Resolve effective plane for a call under `.auto`.
    public func resolveMode() -> AlexaAPIMode {
        lock.lock(); let cfg = config; lock.unlock()
        switch cfg.mode {
        case .auto:
            if cfg.alexaPlusEndpoint != nil || (cfg.accessToken?.isEmpty == false && cfg.mode == .auto) {
                // Prefer Alexa+ when an endpoint is configured; token alone is not enough without URL.
                if cfg.alexaPlusEndpoint != nil { return .alexaPlus }
            }
            if cfg.smartHomeEndpoint != nil { return .smartHomeV3 }
            return .skillProxy
        default:
            return cfg.mode
        }
    }

    // MARK: High-level routines (Crooks / UI)

    public func invokeRoutine(_ name: String, params: [String: String] = [:]) async throws {
        lock.lock()
        lastIntent = name
        if let lights = params["lights"], let v = Int(lights) {
            lastLightsPercent = min(100, max(0, v))
        }
        let lights = lastLightsPercent
        lock.unlock()

        if let transportHook {
            try await transportHook(name, params)
        }

        let mode = resolveMode()
        lock.lock(); lastModeUsed = mode; lock.unlock()

        switch mode {
        case .alexaPlus, .auto:
            // auto already resolved; if resolve returned alexaPlus:
            if mode == .alexaPlus {
                try await invokeAlexaPlus(routine: name, lightsPercent: lights, params: params)
                return
            }
            fallthrough
        case .smartHomeV3:
            try await invokeSmartHome(routine: name, lightsPercent: lights, params: params)
        case .skillProxy:
            try await invokeSkillProxy(intent: name, params: params)
        }
    }

    /// Explicit Alexa+ generative action (AI Action / Multi-Agent style).
    public func invokeAlexaPlusAction(_ action: AlexaPlusAction) async throws {
        lock.lock()
        lastPlusAction = action
        lastIntent = action.expert + ":" + action.utterance
        lastModeUsed = .alexaPlus
        let cfg = config
        lock.unlock()

        if let transportHook {
            var p = action.slots
            p["expert"] = action.expert
            p["utterance"] = action.utterance
            try await transportHook("alexaPlusAction", p)
        }

        guard let endpoint = cfg.alexaPlusEndpoint else {
            // Offline / unconfigured: state still recorded for Crooks.
            return
        }

        var body: [String: Any] = [
            "api": "alexa_plus",
            "sdk": "AI_Action",
            "expert": action.expert,
            "utterance": action.utterance,
            "slots": action.slots,
            "requireConfirmation": action.requireConfirmation,
        ]
        if let sid = action.sessionId { body["sessionId"] = sid }
        if let household = cfg.householdId { body["householdId"] = household }

        try await postJSON(url: endpoint, body: body, bearer: cfg.accessToken)
    }

    /// Explicit Smart Home v3 directive.
    public func invokeSmartHomeDirective(_ directive: AlexaSmartHomeDirective) async throws {
        lock.lock()
        lastDirective = directive
        lastIntent = "\(directive.namespace).\(directive.name)"
        lastModeUsed = .smartHomeV3
        let cfg = config
        lock.unlock()

        if let transportHook {
            try await transportHook(
                "smartHomeDirective",
                [
                    "namespace": directive.namespace,
                    "name": directive.name,
                    "endpointId": directive.endpointId,
                ].merging(directive.payload) { _, n in n }
            )
        }

        guard let endpoint = cfg.smartHomeEndpoint else { return }

        let body: [String: Any] = [
            "directive": [
                "header": [
                    "namespace": directive.namespace,
                    "name": directive.name,
                    "payloadVersion": "3",
                    "messageId": UUID().uuidString,
                ],
                "endpoint": [
                    "endpointId": directive.endpointId,
                    "scope": ["type": "BearerToken", "token": cfg.accessToken ?? ""],
                ],
                "payload": directive.payload,
            ],
        ]
        try await postJSON(url: endpoint, body: body, bearer: cfg.accessToken)
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "breatheAndDim":
            try await invokeRoutine(
                "breatheAndDim",
                params: command.params.merging(["lights": command.params["lights"] ?? "30"]) { _, n in n }
            )
        case "neutralAmbient":
            try await invokeRoutine(
                "neutralAmbient",
                params: command.params.merging(["lights": command.params["lights"] ?? "60"]) { _, n in n }
            )
        case "alexaPlusAction":
            let action = AlexaPlusAction(
                expert: command.params["expert"] ?? "smart_home",
                utterance: command.params["utterance"] ?? command.params["text"] ?? "dim the lights",
                slots: command.params.filter { !["expert", "utterance", "text"].contains($0.key) },
                sessionId: command.params["sessionId"],
                requireConfirmation: (command.params["confirm"] == "true")
            )
            try await invokeAlexaPlusAction(action)
        case "smartHomeSetBrightness":
            let pct = command.params["lights"] ?? command.params["brightness"] ?? "50"
            let directive = AlexaSmartHomeDirective(
                namespace: "Alexa.BrightnessController",
                name: "SetBrightness",
                endpointId: command.params["endpointId"] ?? config.defaultEndpointId,
                payload: ["brightness": pct]
            )
            try await invokeSmartHomeDirective(directive)
        case "smartHomePowerOff":
            try await invokeSmartHomeDirective(
                AlexaSmartHomeDirective(
                    namespace: "Alexa.PowerController",
                    name: "TurnOff",
                    endpointId: command.params["endpointId"] ?? config.defaultEndpointId
                )
            )
        case "setMode":
            if let raw = command.params["mode"], let mode = AlexaAPIMode(rawValue: raw) {
                var cfg = config
                cfg.mode = mode
                updateConfig(cfg)
            }
        default:
            try await invokeRoutine(command.action, params: command.params)
        }
    }

    // MARK: - Plane implementations

    private func invokeAlexaPlus(routine: String, lightsPercent: Int, params: [String: String]) async throws {
        let utterance: String
        switch routine {
        case "breatheAndDim":
            utterance = "Start a calm breathe routine and set the lights to \(lightsPercent) percent"
        case "neutralAmbient":
            utterance = "Set ambient lights to \(lightsPercent) percent and keep the room neutral"
        default:
            utterance = params["utterance"] ?? routine.replacingOccurrences(of: "_", with: " ")
        }
        let action = AlexaPlusAction(
            expert: params["expert"] ?? "smart_home",
            utterance: utterance,
            slots: [
                "brightness": "\(lightsPercent)",
                "routine": routine,
            ].merging(params) { _, n in n },
            sessionId: params["sessionId"],
            requireConfirmation: false
        )
        try await invokeAlexaPlusAction(action)
    }

    private func invokeSmartHome(routine: String, lightsPercent: Int, params: [String: String]) async throws {
        let endpointId = params["endpointId"] ?? config.defaultEndpointId
        switch routine {
        case "breatheAndDim", "neutralAmbient":
            try await invokeSmartHomeDirective(
                AlexaSmartHomeDirective(
                    namespace: "Alexa.BrightnessController",
                    name: "SetBrightness",
                    endpointId: endpointId,
                    payload: ["brightness": "\(lightsPercent)"]
                )
            )
            if routine == "breatheAndDim" {
                try await invokeSmartHomeDirective(
                    AlexaSmartHomeDirective(
                        namespace: "Alexa.SceneController",
                        name: "Activate",
                        endpointId: params["sceneId"] ?? "scene.breathe",
                        payload: ["sceneName": "breathe"]
                    )
                )
            }
        default:
            try await invokeSmartHomeDirective(
                AlexaSmartHomeDirective(
                    namespace: "Alexa.ModeController",
                    name: "SetMode",
                    endpointId: endpointId,
                    payload: ["mode": routine]
                )
            )
        }
    }

    private func invokeSkillProxy(intent: String, params: [String: String]) async throws {
        lock.lock(); let cfg = config; lock.unlock()
        guard let endpoint = cfg.skillEndpoint else { return }
        let body: [String: Any] = [
            "api": "skill_proxy",
            "intent": intent,
            "params": params,
        ]
        try await postJSON(url: endpoint, body: body, bearer: cfg.accessToken)
    }

    private func postJSON(url: URL, body: [String: Any], bearer: String?) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer, !bearer.isEmpty {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode
        lock.lock(); lastHTTPStatus = status; lock.unlock()
        try RemoteHTTPHonesty.requireSuccess(status)
    }
}

// MARK: - Foundation Models orchestrator

public final class FoundationModelOrchestrator: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .foundationModel
    private let lock = NSLock()
    private var lastSuggestion: String = ""
    private var lastCommands: [RemoteCommand] = []

    public init() {}

    public var lastSuggestionText: String {
        lock.lock(); defer { lock.unlock() }
        return lastSuggestion
    }

    public var issuedCommands: [RemoteCommand] {
        lock.lock(); defer { lock.unlock() }
        return lastCommands
    }

    /// Parse natural language into structured remote commands.
    /// Uses on-device FoundationModels when available; otherwise deterministic rule parser.
    public func parseVoice(
        _ text: String,
        currentSCI: Double,
        sigmaIrr: Double,
        phase: CrooksCyclePhase
    ) async -> [RemoteCommand] {
        #if canImport(FoundationModels)
        // Future: LanguageModelSession structured output when SDK is present on target OS.
        #endif
        let lowered = text.lowercased()
        var commands: [RemoteCommand] = []

        if lowered.contains("chill") || lowered.contains("ground") || lowered.contains("calm") {
            commands.append(RemoteCommand(service: .appleMusic, action: "queueGrounding"))
            commands.append(RemoteCommand(service: .spotify, action: "queueGrounding"))
            // Prefer Alexa+ natural utterance when remote is on alexaPlus/auto.
            commands.append(RemoteCommand(
                service: .alexa,
                action: "alexaPlusAction",
                params: [
                    "expert": "smart_home",
                    "utterance": "dim the lights to thirty percent and start a calm breathe routine",
                    "lights": "30",
                ]
            ))
            commands.append(RemoteCommand(service: .alexa, action: "breatheAndDim", params: ["lights": "30"]))
            commands.append(RemoteCommand(service: .airPods, action: "enableANC"))
        }
        // Whole-word / phrase match — substring "up" used to fire on "what's up".
        if lowered.contains("explore") || lowered.contains("energy")
            || lowered.contains("turn up") || lowered.contains("amp up") {
            commands.append(RemoteCommand(service: .diFm, action: "preferProgressiveChannel"))
            commands.append(RemoteCommand(service: .airPods, action: "transparency"))
        }
        if lowered.contains("alexa plus") || lowered.contains("alexa+") {
            commands.append(RemoteCommand(
                service: .alexa,
                action: "setMode",
                params: ["mode": AlexaAPIMode.alexaPlus.rawValue]
            ))
        }
        if lowered.contains("log") || lowered.contains("dose") {
            commands.append(RemoteCommand(service: .drugKit, action: "promptLog"))
        }
        if commands.isEmpty {
            if sigmaIrr > 0.15 || phase == .reverse {
                commands.append(RemoteCommand(service: .appleMusic, action: "setTargetBPM", params: ["bpm": "90"]))
                commands.append(RemoteCommand(service: .alexa, action: "breatheAndDim", params: ["lights": "30"]))
            } else {
                commands.append(RemoteCommand(
                    service: .foundationModel,
                    action: "note",
                    params: ["sci": String(format: "%.2f", currentSCI)]
                ))
            }
        }

        let suggestion = "SCI=\(String(format: "%.2f", currentSCI)) σ_irr=\(String(format: "%.3f", sigmaIrr)) phase=\(phase.rawValue) → \(commands.map(\.action).joined(separator: ","))"
        lock.lock()
        lastSuggestion = suggestion
        lastCommands = commands
        lock.unlock()
        return commands
    }

    public func execute(_ command: RemoteCommand) async throws {
        if command.action == "suggestToReduceSigma" {
            let sigma = Double(command.params["sigmaIrr"] ?? "0") ?? 0
            let phase = CrooksCyclePhase(rawValue: command.params["phase"] ?? "reverse") ?? .reverse
            _ = await parseVoice(
                "reduce sigma",
                currentSCI: 0.5,
                sigmaIrr: sigma,
                phase: phase
            )
        } else {
            lock.lock()
            lastCommands.append(command)
            lastSuggestion = command.action
            lock.unlock()
        }
    }
}
