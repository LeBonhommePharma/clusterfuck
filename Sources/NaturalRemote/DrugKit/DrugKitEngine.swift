import Foundation
import BonhommeCore

/// DrugKit: dose logging + PCCI computation for the remote psychopharm backbone.
public final class DrugKitEngine: @unchecked Sendable {
    public static let shared = DrugKitEngine()

    private let lock = NSLock()
    private var logs: [DrugLog] = []
    private let bridge: EigenMetalBridge
    private let mapper: DeltaHRVFlexAIDMapper
    private let entropyCalc: EntropyCalculator

    public init(
        bridge: EigenMetalBridge = .shared,
        mapper: DeltaHRVFlexAIDMapper = .shared
    ) {
        self.bridge = bridge
        self.mapper = mapper
        self.entropyCalc = EntropyCalculator(binCount: 32)
    }

    public func log(_ entry: DrugLog) {
        lock.lock()
        logs.append(entry)
        lock.unlock()
    }

    public func allLogs() -> [DrugLog] {
        lock.lock(); defer { lock.unlock() }
        return logs
    }

    /// Analyze dose context with music/alexa state → PCCI.
    public func analyze(
        _ log: DrugLog,
        spotifyValence: Double,
        alexaState: Double,
        fmUncertainty: Double = 0.2
    ) -> Double {
        let vector = [
            abs(log.hrDelta) / 20.0,
            spotifyValence,
            alexaState,
            log.entropyShift,
            fmUncertainty,
            log.doseMg / 100.0,
        ]
        return bridge.computePCCI(vector)
    }

    public func predictInteraction(substance: String) -> String {
        let known: [String: String] = [
            "LSD": "5-HT2A agonist ensemble — expect elevated ΔS_config; prefer reverse-phase grounding after peak.",
            "2C-B": "Mixed 5-HT2 partial agonist — moderate entropy spike; monitor ΔHRV closely.",
            "MDMA": "SERT release — HR/HRV shift common; keep hydration + chill BPM playlist ready.",
            "psilocybin": "5-HT2A — classic configurational collapse opportunity in reverse phase.",
            "caffeine": "Adenosine antagonism — mild forward-phase exploration bias.",
        ]
        return known[substance] ?? "Unknown substance '\(substance)': log set/setting and track ΔHRV vs baseline SCI."
    }

    public func analyzeWithFlexAID(
        _ log: DrugLog,
        observedDelta: Double,
        baselineSCI: Double,
        freeAngles: [Double]? = nil,
        boundAngles: [Double]? = nil
    ) -> DeltaHRVFlexAIDPrediction {
        let deltaS: Double
        if let free = freeAngles, let bound = boundAngles, free.count >= 4, bound.count >= 4 {
            deltaS = mapper.flexAIDDeltaS(freeAngles: free, boundAngles: bound)
        } else {
            deltaS = log.entropyShift
        }
        let features = DeltaHRVFlexAIDFeatures(
            observedDeltaRMSSD: observedDelta,
            flexAIDDeltaS: deltaS,
            doseMg: log.doseMg,
            baselineSCI: baselineSCI,
            substanceID: abs(log.substance.hashValue % 10_000)
        )
        return mapper.predict(features)
    }
}

/// RemoteActuator surface for Crooks / FM routing.
public final class DrugKitActuator: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .drugKit
    public let engine: DrugKitEngine
    private let lock = NSLock()
    private var pendingPrompt = false

    public init(engine: DrugKitEngine = .shared) {
        self.engine = engine
    }

    public var isPromptPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return pendingPrompt
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "promptLog":
            lock.lock(); pendingPrompt = true; lock.unlock()
        case "log":
            let substance = command.params["substance"] ?? "unknown"
            let dose = Double(command.params["doseMg"] ?? "0") ?? 0
            engine.log(DrugLog(substance: substance, doseMg: dose, setAndSetting: command.params["set"] ?? ""))
            lock.lock(); pendingPrompt = false; lock.unlock()
        default:
            break
        }
    }
}
