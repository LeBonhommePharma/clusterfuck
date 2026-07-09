import Foundation

/// Central σ_irr minimization engine for NATURaL Remote — Entropy Docking Edition.
///
/// Continuously accumulates forward/reverse work from multi-scale signals and
/// drives music, environment, and AirPods actuators to push σ_irr → 0.
public actor CrooksCycleController {
    public static let shared = CrooksCycleController()

    private var phase: CrooksCyclePhase = .forward
    private var workFwd: Double = 0
    private var workRev: Double = 0
    private var deltaG: Double
    private var sigmaIrr: Double = 0
    private var cycleCount: Int = 0
    private var lastActionSummary: String = "idle"
    private var bus: ActuatorBus
    private var minimizeThreshold: Double
    private var flipThreshold: Double

    public init(
        deltaG: Double = -8.2,
        bus: ActuatorBus = ActuatorBus(),
        minimizeThreshold: Double = 0.15,
        flipThreshold: Double = 0.03
    ) {
        self.deltaG = deltaG
        self.bus = bus
        self.minimizeThreshold = minimizeThreshold
        self.flipThreshold = flipThreshold
    }

    public func setActuatorBus(_ bus: ActuatorBus) {
        self.bus = bus
    }

    public func setDeltaG(_ value: Double) {
        self.deltaG = value
        recomputeSigma()
    }

    /// Primary entry: update with a multi-signal state sample and optionally minimize.
    @discardableResult
    public func update(with state: RemoteMultiSignalState) async -> CrooksSnapshot {
        let sample = CrooksMath.instantaneousWork(from: state)
        let acc = CrooksMath.accumulateWork(
            phase: phase,
            workFwd: workFwd,
            workRev: workRev,
            sampleWork: sample
        )
        workFwd = acc.workFwd
        workRev = acc.workRev
        recomputeSigma()

        if CrooksMath.shouldMinimize(sigmaIrr: sigmaIrr, threshold: minimizeThreshold) {
            await minimizeSigma(currentBPM: state.musicBPM)
        }

        if CrooksMath.shouldFlipPhase(
            sigmaIrr: sigmaIrr,
            cycleCount: cycleCount,
            sigmaThreshold: flipThreshold
        ) {
            flipPhase()
        }

        return snapshot()
    }

    /// Explicit minimization pass (also invoked when σ_irr exceeds threshold).
    public func minimizeSigma(currentBPM: Double) async {
        let target = CrooksMath.targetBPM(phase: phase, currentBPM: currentBPM, sigmaIrr: sigmaIrr)
        var actions: [String] = []

        // Music tempo / grounding selection
        let musicService: RemoteService = .appleMusic
        try? await bus.execute(RemoteCommand(
            service: musicService,
            action: "setTargetBPM",
            params: ["bpm": String(format: "%.1f", target), "phase": phase.rawValue]
        ))
        actions.append("musicBPM→\(String(format: "%.0f", target))")

        try? await bus.execute(RemoteCommand(
            service: .spotify,
            action: phase == .reverse ? "queueGrounding" : "allowExploration",
            params: ["sigmaIrr": String(format: "%.4f", sigmaIrr)]
        ))
        actions.append("spotify")

        try? await bus.execute(RemoteCommand(
            service: .sonos,
            action: "setVolumeCurve",
            params: ["mode": phase == .reverse ? "dim" : "neutral"]
        ))

        try? await bus.execute(RemoteCommand(
            service: .diFm,
            action: phase == .reverse ? "preferChillChannel" : "preferProgressiveChannel",
            params: [:]
        ))

        // Environment
        try? await bus.execute(RemoteCommand(
            service: .alexa,
            action: phase == .reverse ? "breatheAndDim" : "neutralAmbient",
            params: ["lights": phase == .reverse ? "30" : "60"]
        ))
        actions.append("alexa")

        // AirPods acoustic gate
        try? await bus.execute(RemoteCommand(
            service: .airPods,
            action: phase == .reverse ? "enableANC" : "transparency",
            params: [:]
        ))
        actions.append("airPods")

        // Foundation model suggestion context
        try? await bus.execute(RemoteCommand(
            service: .foundationModel,
            action: "suggestToReduceSigma",
            params: [
                "sigmaIrr": String(format: "%.4f", sigmaIrr),
                "phase": phase.rawValue,
            ]
        ))

        // Subjective PV check-in when entropy production is elevated
        try? await bus.execute(RemoteCommand(
            service: .researchKit,
            action: "promptCurrentState",
            params: ["sigmaIrr": String(format: "%.4f", sigmaIrr)]
        ))
        actions.append("researchKit")

        lastActionSummary = actions.joined(separator: "+")
    }

    public func snapshot() -> CrooksSnapshot {
        CrooksSnapshot(
            phase: phase,
            workFwd: workFwd,
            workRev: workRev,
            deltaG: deltaG,
            sigmaIrr: sigmaIrr,
            closurePercent: CrooksMath.closurePercent(sigmaIrr: sigmaIrr),
            cycleCount: cycleCount,
            lastActionSummary: lastActionSummary
        )
    }

    public func reset(deltaG: Double? = nil) {
        phase = .forward
        workFwd = 0
        workRev = 0
        if let deltaG { self.deltaG = deltaG }
        sigmaIrr = 0
        cycleCount = 0
        lastActionSummary = "reset"
        bus.resetEvents()
    }

    public func recordedEvents() -> [ActuatorEvent] {
        bus.recordedEvents()
    }

    // MARK: - Private

    private func recomputeSigma() {
        sigmaIrr = CrooksMath.sigmaIrr(workFwd: workFwd, workRev: workRev, deltaG: deltaG)
    }

    private func flipPhase() {
        phase = phase == .forward ? .reverse : .forward
        cycleCount += 1
        lastActionSummary = "phaseFlip→\(phase.rawValue)"
    }
}
