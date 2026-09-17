import Foundation
import BonhommeCore

/// Wires sensors → FeedbackEngine / analyzers → CrooksCycleController → actuators.
public final class RemoteControlLoop: @unchecked Sendable {
    public let bus: ActuatorBus
    public let crooks: CrooksCycleController
    public let feedback: FeedbackEngine
    public let music: MultiMusicRouter
    public let airPods: AirPodsDualStack
    public let alexa: AlexaProxyController
    public let foundation: FoundationModelOrchestrator
    public let drugKit: DrugKitEngine
    public let drugActuator: DrugKitActuator
    public let researchKit: ResearchKitBridge
    public let deltaHRV: DeltaHRVAnalyzer
    public let flexMapper: DeltaHRVFlexAIDMapper
    public let eigen: EigenMetalBridge

    private let lock = NSLock()
    private var _state = RemoteMultiSignalState()
    private var _snapshot: CrooksSnapshot?
    private var hrvAnalyzer = HRVAnalyzer()

    public init(
        bus: ActuatorBus = ActuatorBus(),
        crooks: CrooksCycleController? = nil,
        feedback: FeedbackEngine = FeedbackEngine()
    ) {
        self.bus = bus
        self.crooks = crooks ?? CrooksCycleController(bus: bus)
        self.feedback = feedback
        self.music = MultiMusicRouter()
        self.airPods = AirPodsDualStack()
        self.alexa = AlexaProxyController()
        self.foundation = FoundationModelOrchestrator()
        self.drugKit = DrugKitEngine()
        self.drugActuator = DrugKitActuator(engine: self.drugKit)
        self.researchKit = ResearchKitBridge(feedbackEngine: feedback)
        self.deltaHRV = DeltaHRVAnalyzer()
        self.flexMapper = DeltaHRVFlexAIDMapper.shared
        self.eigen = EigenMetalBridge.shared

        music.registerAll(on: bus)
        bus.register(airPods)
        bus.register(alexa)
        bus.register(foundation)
        bus.register(drugActuator)
        bus.register(researchKit)
        feedback.register(hrvAnalyzer)
    }

    public var state: RemoteMultiSignalState {
        lock.lock(); defer { lock.unlock() }
        return _state
    }

    public var lastSnapshot: CrooksSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return _snapshot
    }

    /// Bootstrap actuator bus on the crooks actor.
    public func attach() async {
        await crooks.setActuatorBus(bus)
    }

    /// Ingest HRV sample, update ΔHRV + SCI, run Crooks step.
    @discardableResult
    public func ingestHRV(rmssd: Double, sdnn: Double, rrIntervals: [Double]) async -> CrooksSnapshot {
        let delta = deltaHRV.ingest(rmssd: rmssd, sdnn: sdnn, rrIntervals: rrIntervals)
        feedback.ingest(HRVSignal(timestamp: Date(), sdnn: sdnn, rmssd: rmssd, rrIntervals: rrIntervals))
        _ = feedback.analyze(for: .heartRateVariability)

        lock.lock()
        _state.deltaHRV = delta.deltaRMSSD
        _state.sci = delta.sci
        _state.physiologicalSCI = delta.sci
        var local = _state
        lock.unlock()

        airPods.proH2.apply(to: &local)
        researchKit.apply(to: &local)
        let snap = await crooks.update(with: local)
        lock.lock()
        _state = local
        _snapshot = snap
        lock.unlock()
        return snap
    }

    /// ResearchKit / subjective survey path → FeedbackEngine + Crooks.
    @discardableResult
    public func ingestSurvey(
        instrument: ResearchKitInstrument,
        rawScore: Double,
        responses: [String: String] = [:]
    ) async -> (result: ResearchKitSurveyResult, snapshot: CrooksSnapshot) {
        let result = researchKit.injectSurvey(
            instrument: instrument,
            rawScore: rawScore,
            responses: responses
        )
        _ = feedback.analyze(for: .survey)
        lock.lock()
        var local = _state
        lock.unlock()
        researchKit.apply(to: &local)
        let snap = await crooks.update(with: local)
        lock.lock()
        _state = local
        _snapshot = snap
        lock.unlock()
        return (result, snap)
    }

    /// Push spectral audio features into state and Crooks.
    @discardableResult
    public func ingestAudio(samples: [Float], sampleRate: Double) async -> CrooksSnapshot {
        let frame = music.spectral.process(samples: samples, sampleRate: sampleRate)
        lock.lock()
        music.applySpectral(frame, to: &_state)
        var local = _state
        lock.unlock()
        let snap = await crooks.update(with: local)
        lock.lock(); _snapshot = snap; lock.unlock()
        return snap
    }

    /// Log dose and run hybrid FlexAID path; may fire grounding via Crooks.
    @discardableResult
    public func logDose(_ log: DrugLog, freeAngles: [Double]? = nil, boundAngles: [Double]? = nil) async -> (pcci: Double, prediction: DeltaHRVFlexAIDPrediction, snapshot: CrooksSnapshot) {
        drugKit.log(log)
        lock.lock()
        let observed = _state.deltaHRV
        let sci = _state.sci
        lock.unlock()

        let prediction = drugKit.analyzeWithFlexAID(
            log,
            observedDelta: observed,
            baselineSCI: sci,
            freeAngles: freeAngles,
            boundAngles: boundAngles
        )
        let pcci = drugKit.analyze(log, spotifyValence: 0.5, alexaState: Double(alexa.lightsPercent) / 100.0)

        lock.lock()
        _state.flexAIDDeltaS = prediction.flexAIDDeltaS
        _state.pcci = pcci
        _state.doseMg = log.doseMg
        _state.substanceID = stableSubstanceID(log.substance)
        if prediction.isGroundingAlert {
            _state.musicBPM = min(_state.musicBPM, 90)
        }
        var local = _state
        lock.unlock()

        let snap = await crooks.update(with: local)
        if prediction.isGroundingAlert {
            await crooks.minimizeSigma(currentBPM: local.musicBPM)
        }
        // Pharmacovigilance: always record exposure + prediction + control context.
        let pv = PharmacovigilanceRecord(
            substance: log.substance,
            doseMg: log.doseMg,
            setAndSetting: log.setAndSetting,
            observedDeltaHRV: observed,
            predictedDeltaHRV: prediction.predictedDelta,
            deviation: prediction.deviation,
            action: prediction.action,
            sci: sci,
            pcci: pcci,
            sigmaIrr: snap.sigmaIrr,
            crooksPhase: snap.phase.rawValue,
            closurePercent: snap.closurePercent,
            musicBPM: local.musicBPM,
            audioEntropyBits: local.audioEntropyBits,
            alexaLightsPercent: alexa.lightsPercent,
            airPodsNoiseMode: airPods.activeTelemetry().noiseMode.rawValue,
            flexAIDDeltaS: prediction.flexAIDDeltaS
        )
        drugKit.recordPharmacovigilance(pv)
        lock.lock(); _snapshot = snap; lock.unlock()
        return (pcci, prediction, snap)
    }

    /// Voice path through FoundationModelOrchestrator then bus.
    public func handleVoice(_ text: String) async {
        let snap = await crooks.snapshot()
        lock.lock(); let sci = _state.sci; lock.unlock()
        let commands = await foundation.parseVoice(
            text,
            currentSCI: sci,
            sigmaIrr: snap.sigmaIrr,
            phase: snap.phase
        )
        for cmd in commands {
            try? await bus.execute(cmd)
        }
    }

    /// Test/UI override of the live multi-signal vector (does not bypass Crooks).
    public func replaceState(_ state: RemoteMultiSignalState) {
        lock.lock()
        _state = state
        lock.unlock()
    }
}
