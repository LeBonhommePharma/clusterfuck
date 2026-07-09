import SwiftUI
import BonhommeCore

/// Watch/iOS remote UI reusing NATURaL `SCIVisualizationView` patterns and vertical session paging.
///
/// Extends the BonhommeWatch SessionView topology: multi-page TabView with biofeedback + controls,
/// now centered on σ_irr minimization rather than yoga pose flow.
public struct RemoteSessionView: View {
    @ObservedObject private var model: RemoteSessionViewModel

    public init(model: RemoteSessionViewModel) {
        self.model = model
    }

    public var body: some View {
        TabView(selection: $model.selectedTab) {
            sigmaTab.tag(0)
            musicTab.tag(1)
            doseTab.tag(2)
            environmentTab.tag(3)
        }
        #if os(watchOS)
        .tabViewStyle(.verticalPage)
        #endif
        .task {
            await model.start()
        }
    }

    private var sigmaTab: some View {
        VStack(spacing: 10) {
            // Reuse NATURaL SCIVisualizationView for coherence ring.
            SCIVisualizationView(score: model.sciScore, trend: model.sciTrend)
            Text(String(format: "σ_irr: %.3f", model.sigmaIrr))
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.sigmaIrr < 0.05 ? .green : .orange)
            Text(String(format: "Closure: %.0f%% · %@", model.closurePercent, model.phaseLabel))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.lastAction)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button(model.isSessionRunning ? "Stop" : "Start") {
                    Task {
                        if model.isSessionRunning { model.stop() }
                        else { await model.start() }
                    }
                }
                .buttonStyle(.bordered)
                Button("Minimize σ") {
                    Task { await model.forceMinimize() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private var musicTab: some View {
        VStack(spacing: 8) {
            Text("Music Stack").font(.headline)
            Text(String(format: "BPM %.0f · H_audio %.2f bit", model.musicBPM, model.audioEntropy))
                .font(.caption)
                .monospacedDigit()
            HStack {
                Button("Ground") { Task { await model.groundMusic() } }
                Button("Explore") { Task { await model.exploreMusic() } }
            }
            Text("Apple Music · Spotify · Sonos · DI.fm")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var doseTab: some View {
        VStack(spacing: 8) {
            Text("DrugKit").font(.headline)
            Text(String(format: "PCCI %.2f · ΔHRV %.1f", model.pcci, model.deltaHRV))
                .font(.caption)
                .monospacedDigit()
            Button("Log demo dose") {
                Task { await model.logDemoDose() }
            }
            if model.groundingAlert {
                Text("grounding_alert")
                    .foregroundStyle(.red)
                    .font(.caption.bold())
            }
        }
        .padding()
    }

    private var environmentTab: some View {
        VStack(spacing: 8) {
            Text("Environment").font(.headline)
            Text("Alexa lights: \(model.alexaLights)%")
                .font(.caption)
            HStack {
                Button("ANC") { Task { await model.setANC() } }
                Button("Transparency") { Task { await model.setTransparency() } }
            }
            Button("Voice: chill + dim") {
                Task { await model.voiceChill() }
            }
        }
        .padding()
    }
}

@MainActor
public final class RemoteSessionViewModel: ObservableObject {
    @Published public var selectedTab = 0
    @Published public var sigmaIrr: Double = 0
    @Published public var closurePercent: Double = 0
    @Published public var phaseLabel: String = CrooksCyclePhase.forward.rawValue
    @Published public var lastAction: String = "idle"
    @Published public var sciScore: Double? = 0.5
    @Published public var sciTrend: SCITrend = .stable
    @Published public var musicBPM: Double = 120
    @Published public var audioEntropy: Double = 0
    @Published public var pcci: Double = 0
    @Published public var deltaHRV: Double = 0
    @Published public var groundingAlert = false
    @Published public var alexaLights: Int = 60

    public let manager: PharmaControlSessionManager

    public init(manager: PharmaControlSessionManager = PharmaControlSessionManager()) {
        self.manager = manager
    }

    public func start() async {
        await manager.start()
        refreshFromLoop()
    }

    /// Stop the pharmacovigilance / remote session.
    public func stop() {
        manager.stop()
        lastAction = "session_stopped"
        refreshFromLoop()
    }

    public var isSessionRunning: Bool { manager.isRunning }

    /// Drive multi-signal update through the **shipped** control path (app UI + tests).
    @discardableResult
    public func applySyntheticMultiSignal(
        deltaHRV: Double,
        musicBPM: Double,
        audioEntropy: Double,
        sci: Double
    ) async -> CrooksSnapshot {
        if !manager.isRunning {
            await manager.start()
        }
        let rr = (0..<24).map { _ in 800.0 + Double.random(in: -20...20) }
        _ = await manager.loop.ingestHRV(rmssd: 40 + abs(deltaHRV), sdnn: 50, rrIntervals: rr)
        var samples = [Float](repeating: 0, count: 512)
        let freq = max(1.0, musicBPM / 60.0)
        for n in 0..<512 {
            samples[n] = Float(sin(2 * Double.pi * freq * Double(n) / 64.0) * (0.3 + audioEntropy * 0.1))
        }
        _ = await manager.loop.ingestAudio(samples: samples, sampleRate: 16_000)
        var state = manager.loop.state
        state.deltaHRV = deltaHRV
        state.musicBPM = musicBPM
        state.audioEntropyBits = audioEntropy
        state.sci = sci
        let snap = await manager.loop.crooks.update(with: state)
        self.sigmaIrr = snap.sigmaIrr
        self.closurePercent = snap.closurePercent
        self.phaseLabel = snap.phase.rawValue
        self.lastAction = snap.lastActionSummary
        self.musicBPM = musicBPM
        self.audioEntropy = audioEntropy
        self.deltaHRV = deltaHRV
        self.sciScore = sci
        return snap
    }

    public func forceMinimize() async {
        await manager.loop.crooks.minimizeSigma(currentBPM: musicBPM)
        refreshFromLoop()
    }

    public func groundMusic() async {
        try? await manager.loop.bus.execute(RemoteCommand(service: .appleMusic, action: "queueGrounding"))
        try? await manager.loop.bus.execute(RemoteCommand(service: .spotify, action: "queueGrounding"))
        try? await manager.loop.bus.execute(RemoteCommand(service: .diFm, action: "preferChillChannel"))
        refreshFromLoop()
    }

    public func exploreMusic() async {
        try? await manager.loop.bus.execute(RemoteCommand(service: .diFm, action: "preferProgressiveChannel"))
        try? await manager.loop.bus.execute(RemoteCommand(service: .appleMusic, action: "allowExploration"))
        refreshFromLoop()
    }

    public func logDemoDose() async {
        let result = await manager.loop.logDose(
            DrugLog(substance: "2C-B", doseMg: 12, setAndSetting: "home / lo-fi", hrDelta: 8, entropyShift: 1.2)
        )
        groundingAlert = result.prediction.isGroundingAlert
        pcci = result.pcci
        refreshFromLoop()
    }

    public func setANC() async {
        try? await manager.loop.bus.execute(RemoteCommand(service: .airPods, action: "enableANC"))
        refreshFromLoop()
    }

    public func setTransparency() async {
        try? await manager.loop.bus.execute(RemoteCommand(service: .airPods, action: "transparency"))
        refreshFromLoop()
    }

    public func voiceChill() async {
        await manager.loop.handleVoice("chill music and dim lights")
        alexaLights = manager.loop.alexa.lightsPercent
        refreshFromLoop()
    }

    private func refreshFromLoop() {
        let state = manager.loop.state
        musicBPM = state.musicBPM
        audioEntropy = state.audioEntropyBits
        deltaHRV = state.deltaHRV
        pcci = state.pcci
        sciScore = state.sci
        alexaLights = manager.loop.alexa.lightsPercent
        Task {
            let snap = await manager.loop.crooks.snapshot()
            await MainActor.run {
                self.sigmaIrr = snap.sigmaIrr
                self.closurePercent = snap.closurePercent
                self.phaseLabel = snap.phase.rawValue
                self.lastAction = snap.lastActionSummary
            }
        }
    }
}

// MARK: - SCITrend bridge

// BonhommeCore SCIVisualizationView uses SCITrend — ensure we reference the same type.
// If SCITrend lives next to SCIVisualizationView in BonhommeCore, this compiles.
// Fallback alias if needed is unnecessary when importing BonhommeCore fully.
