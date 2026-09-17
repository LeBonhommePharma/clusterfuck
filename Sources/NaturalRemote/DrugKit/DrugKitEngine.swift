import Foundation
import BonhommeCore

// MARK: - Pharmacovigilance export contract

/// One auditable PV event: exposure + outcome + prediction + control-loop context.
/// Designed so ClusterFuck can graduate to Le Bonhomme Pharma’s main PV pipeline.
public struct PharmacovigilanceRecord: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var substance: String
    public var doseMg: Double
    public var setAndSetting: String
    public var observedDeltaHRV: Double
    public var predictedDeltaHRV: Double
    public var deviation: Double
    public var action: String
    public var sci: Double
    public var pcci: Double
    public var sigmaIrr: Double
    public var crooksPhase: String
    public var closurePercent: Double
    public var musicBPM: Double
    public var audioEntropyBits: Double
    public var alexaLightsPercent: Int
    public var airPodsNoiseMode: String
    public var flexAIDDeltaS: Double
    public var sourceBuild: String

    public init(
        timestamp: Date = Date(),
        substance: String,
        doseMg: Double,
        setAndSetting: String,
        observedDeltaHRV: Double,
        predictedDeltaHRV: Double,
        deviation: Double,
        action: String,
        sci: Double,
        pcci: Double,
        sigmaIrr: Double,
        crooksPhase: String,
        closurePercent: Double,
        musicBPM: Double,
        audioEntropyBits: Double,
        alexaLightsPercent: Int,
        airPodsNoiseMode: String = "",
        flexAIDDeltaS: Double,
        sourceBuild: String = NaturalRemoteInfo.version
    ) {
        self.timestamp = timestamp
        self.substance = substance
        self.doseMg = doseMg
        self.setAndSetting = setAndSetting
        self.observedDeltaHRV = observedDeltaHRV
        self.predictedDeltaHRV = predictedDeltaHRV
        self.deviation = deviation
        self.action = action
        self.sci = sci
        self.pcci = pcci
        self.sigmaIrr = sigmaIrr
        self.crooksPhase = crooksPhase
        self.closurePercent = closurePercent
        self.musicBPM = musicBPM
        self.audioEntropyBits = audioEntropyBits
        self.alexaLightsPercent = alexaLightsPercent
        self.airPodsNoiseMode = airPodsNoiseMode
        self.flexAIDDeltaS = flexAIDDeltaS
        self.sourceBuild = sourceBuild
    }
}

/// Serializes PV records for cohort review (JSON array). Durable store is a later phase.
public enum PharmacovigilanceExporter: Sendable {
    public static func jsonData(_ records: [PharmacovigilanceRecord]) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(records)
    }

    public static func decode(_ data: Data) throws -> [PharmacovigilanceRecord] {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode([PharmacovigilanceRecord].self, from: data)
    }
}

/// DrugKit: dose logging + PCCI + pharmacovigilance record assembly for the remote backbone.
public final class DrugKitEngine: @unchecked Sendable {
    public static let shared = DrugKitEngine()

    private let lock = NSLock()
    private var logs: [DrugLog] = []
    private var pvRecords: [PharmacovigilanceRecord] = []
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

    public func allPharmacovigilanceRecords() -> [PharmacovigilanceRecord] {
        lock.lock(); defer { lock.unlock() }
        return pvRecords
    }

    /// Append a full PV record after hybrid analysis (call from control loop).
    public func recordPharmacovigilance(_ record: PharmacovigilanceRecord) {
        lock.lock()
        pvRecords.append(record)
        lock.unlock()
    }

    public func exportPharmacovigilanceJSON() throws -> Data {
        try PharmacovigilanceExporter.jsonData(allPharmacovigilanceRecords())
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

    /// Non-clinical, informational reference only. Not medical advice and never
    /// serialized into `PharmacovigilanceRecord`. Disable to suppress the demo text.
    public var nonClinicalDemoMode = true

    public func predictInteraction(substance: String) -> String {
        let known: [String: String] = [
            "LSD": "5-HT2A agonist ensemble — expect elevated ΔS_config; prefer reverse-phase grounding after peak.",
            "2C-B": "Mixed 5-HT2 partial agonist — moderate entropy spike; monitor ΔHRV closely.",
            "MDMA": "SERT release — HR/HRV shift common; keep hydration + chill BPM playlist ready.",
            "psilocybin": "5-HT2A — classic configurational collapse opportunity in reverse phase.",
            "caffeine": "Adenosine antagonism — mild forward-phase exploration bias.",
        ]
        let note = known[substance] ?? "Unknown substance '\(substance)': log set/setting and track ΔHRV vs baseline SCI."
        guard nonClinicalDemoMode else {
            return "Clinical guidance disabled — log set/setting and track ΔHRV vs baseline SCI."
        }
        return "Non-clinical demo — \(note)"
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
            substanceID: stableSubstanceID(log.substance)
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
