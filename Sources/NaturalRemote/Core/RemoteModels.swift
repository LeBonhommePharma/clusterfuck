import Foundation

// MARK: - Cycle phase & remote services

/// Forward = heating / exploration (raise entropy work).
/// Reverse = cooling / binding / grounding (collapse entropy work).
public enum CrooksCyclePhase: String, Codable, Sendable, CaseIterable {
    case forward
    case reverse
}

/// Actuator / music service identity used by structured commands.
public enum RemoteService: String, Codable, Sendable, CaseIterable {
    case appleMusic
    case spotify
    case sonos
    case diFm
    case alexa
    case airPods
    case foundationModel
    case healthKit
    case researchKit
    case drugKit
}

/// Structured command produced by Foundation Models or UI and routed by the control loop.
public struct RemoteCommand: Codable, Sendable, Equatable {
    public var service: RemoteService
    public var action: String
    public var params: [String: String]

    public init(service: RemoteService, action: String, params: [String: String] = [:]) {
        self.service = service
        self.action = action
        self.params = params
    }
}

/// Live multi-scale state vector fed into Crooks σ_irr updates.
public struct RemoteMultiSignalState: Codable, Sendable, Equatable {
    public var deltaHRV: Double
    public var flexAIDDeltaS: Double
    public var musicBPM: Double
    public var audioEntropyBits: Double
    public var sci: Double
    public var pcci: Double
    public var alexaEntropyHint: Double
    /// Last ResearchKit/subjective survey work contribution (idempotent; never accumulate across ticks).
    public var subjectiveWorkHint: Double
    public var airPodsANCEngaged: Bool
    public var conversationAwarenessActive: Bool
    public var doseMg: Double
    public var substanceID: Int

    public init(
        deltaHRV: Double = 0,
        flexAIDDeltaS: Double = 0,
        musicBPM: Double = 120,
        audioEntropyBits: Double = 0,
        sci: Double = 0.5,
        pcci: Double = 0.5,
        alexaEntropyHint: Double = 0,
        subjectiveWorkHint: Double = 0,
        airPodsANCEngaged: Bool = false,
        conversationAwarenessActive: Bool = false,
        doseMg: Double = 0,
        substanceID: Int = 0
    ) {
        self.deltaHRV = deltaHRV
        self.flexAIDDeltaS = flexAIDDeltaS
        self.musicBPM = musicBPM
        self.audioEntropyBits = audioEntropyBits
        self.sci = sci
        self.pcci = pcci
        self.alexaEntropyHint = alexaEntropyHint
        self.subjectiveWorkHint = subjectiveWorkHint
        self.airPodsANCEngaged = airPodsANCEngaged
        self.conversationAwarenessActive = conversationAwarenessActive
        self.doseMg = doseMg
        self.substanceID = substanceID
    }
}

/// Snapshot published to UI after each Crooks update.
public struct CrooksSnapshot: Codable, Sendable, Equatable {
    public var phase: CrooksCyclePhase
    public var workFwd: Double
    public var workRev: Double
    public var deltaG: Double
    public var sigmaIrr: Double
    public var closurePercent: Double
    public var cycleCount: Int
    public var lastActionSummary: String
    public var timestamp: Date

    public init(
        phase: CrooksCyclePhase,
        workFwd: Double,
        workRev: Double,
        deltaG: Double,
        sigmaIrr: Double,
        closurePercent: Double,
        cycleCount: Int,
        lastActionSummary: String,
        timestamp: Date = Date()
    ) {
        self.phase = phase
        self.workFwd = workFwd
        self.workRev = workRev
        self.deltaG = deltaG
        self.sigmaIrr = sigmaIrr
        self.closurePercent = closurePercent
        self.cycleCount = cycleCount
        self.lastActionSummary = lastActionSummary
        self.timestamp = timestamp
    }
}

/// Drug dose log for DrugKit + ResearchKit bridge.
public struct DrugLog: Codable, Sendable, Equatable {
    public var substance: String
    public var doseMg: Double
    public var setAndSetting: String
    public var toleranceFlag: Bool
    public var hrDelta: Double
    public var entropyShift: Double
    public var timestamp: Date

    public init(
        substance: String,
        doseMg: Double,
        setAndSetting: String = "",
        toleranceFlag: Bool = false,
        hrDelta: Double = 0,
        entropyShift: Double = 0,
        timestamp: Date = Date()
    ) {
        self.substance = substance
        self.doseMg = doseMg
        self.setAndSetting = setAndSetting
        self.toleranceFlag = toleranceFlag
        self.hrDelta = hrDelta
        self.entropyShift = entropyShift
        self.timestamp = timestamp
    }
}

/// Audio feature vector from AVAudioEngine spectral analysis.
public struct AudioFeatureFrame: Codable, Sendable, Equatable {
    public var bpm: Double
    public var spectralCentroidHz: Double
    public var spectralFlux: Double
    public var audioEntropyBits: Double
    public var rmsEnergy: Double
    public var timestamp: Date

    public init(
        bpm: Double,
        spectralCentroidHz: Double,
        spectralFlux: Double,
        audioEntropyBits: Double,
        rmsEnergy: Double,
        timestamp: Date = Date()
    ) {
        self.bpm = bpm
        self.spectralCentroidHz = spectralCentroidHz
        self.spectralFlux = spectralFlux
        self.audioEntropyBits = audioEntropyBits
        self.rmsEnergy = rmsEnergy
        self.timestamp = timestamp
    }
}

/// Actuator side-effect record (for tests and audit logs).
public struct ActuatorEvent: Codable, Sendable, Equatable {
    public var service: RemoteService
    public var action: String
    public var detail: String
    public var timestamp: Date

    public init(service: RemoteService, action: String, detail: String, timestamp: Date = Date()) {
        self.service = service
        self.action = action
        self.detail = detail
        self.timestamp = timestamp
    }
}
