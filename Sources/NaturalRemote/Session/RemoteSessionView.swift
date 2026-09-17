import SwiftUI
import BonhommeCore

/// Watch/iOS/macOS remote UI: Crooks σ_irr HUD + actuator pages.
///
/// Reuses NATURaL `SCIVisualizationView` for the coherence ring. Layout is a
/// control remote (sigma / music / dose / environment) — not a yoga pose flow.
public struct RemoteSessionView: View {
    @ObservedObject private var model: RemoteSessionViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(model: RemoteSessionViewModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            #if os(watchOS)
            pagedRemote
            #else
            if sizeClass == .regular {
                NavigationSplitView {
                    List(selection: $model.selectedTab) {
                        navRow(0, title: "σ_irr", symbol: .sigma)
                        navRow(1, title: "Music", symbol: .music)
                        navRow(2, title: "DrugKit", symbol: .dose)
                        navRow(3, title: "Environment", symbol: .environment)
                    }
                    .navigationTitle("Remote")
                } detail: {
                    page(for: model.selectedTab)
                        .padding()
                        .frame(maxWidth: 720, alignment: .top)
                }
            } else {
                pagedRemote
            }
            #endif
        }
        .background(Color.clusterFuckBackground.ignoresSafeArea())
        .task {
            await model.start()
        }
    }

    private var pagedRemote: some View {
        TabView(selection: $model.selectedTab) {
            sigmaTab.tag(0)
            musicTab.tag(1)
            doseTab.tag(2)
            environmentTab.tag(3)
        }
        #if os(watchOS)
        .tabViewStyle(.verticalPage)
        #endif
    }

    private func navRow(_ tag: Int, title: String, symbol: ClusterFuckSymbol) -> some View {
        Label(title, systemImage: symbol.systemName)
            .tag(tag)
            .symbolRenderingMode(.monochrome)
    }

    @ViewBuilder
    private func page(for tag: Int) -> some View {
        switch tag {
        case 1: musicTab
        case 2: doseTab
        case 3: environmentTab
        default: sigmaTab
        }
    }

    private var sigmaTab: some View {
        ScrollView {
            VStack(spacing: ClusterFuckSpacing.md) {
                SigmaHUDView(
                    sigmaIrr: model.sigmaIrr,
                    closurePercent: model.closurePercent,
                    phase: CrooksCyclePhase(rawValue: model.phaseLabel) ?? .forward,
                    lastAction: model.lastAction,
                    compact: compactChrome
                )
                SCIVisualizationView(score: model.sciScore, trend: model.sciTrend)
                    .frame(minHeight: compactChrome ? 64 : 88)
                    .accessibilityLabel("Shannon collapse index \(model.sciScore.map { String(format: "%.2f", $0) } ?? "unknown")")

                HStack(spacing: ClusterFuckSpacing.sm) {
                    sessionButton
                    minimizeButton
                }
                if let err = model.lastError, !err.isEmpty {
                    Text(err)
                        .font(ClusterFuckType.caption)
                        .foregroundStyle(Color.clusterFuckDestructive)
                        .accessibilityLabel("Error \(err)")
                }
            }
            .padding(ClusterFuckSpacing.md)
        }
    }

    private var sessionButton: some View {
        Button {
            Task {
                if model.isSessionRunning { model.stop() }
                else { await model.start() }
            }
        } label: {
            Text(model.isSessionRunning ? "Stop" : "Start")
                .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
        }
        .buttonStyle(.bordered)
        .disabled(model.isBusy)
        .accessibilityLabel(model.isSessionRunning ? "Stop pharmacovigilance session" : "Start pharmacovigilance session")
    }

    private var minimizeButton: some View {
        Button {
            Task { await model.forceMinimize() }
        } label: {
            Label(model.isBusy ? "Working…" : "Minimize σ", systemImage: ClusterFuckSymbol.minimize.systemName)
                .frame(minHeight: ClusterFuckIconSize.hit)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.clusterFuckAccent)
        .disabled(model.isBusy)
        .accessibilityLabel("Minimize irreversible entropy production")
        .accessibilityHint("Drives music, Alexa, and AirPods actuators")
    }

    private var musicTab: some View {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("Music stack", systemImage: ClusterFuckSymbol.music.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
            Text(String(format: "BPM %.0f · H_audio %.2f bit", model.musicBPM, model.audioEntropy))
                .font(ClusterFuckType.caption.monospacedDigit())
                .foregroundStyle(Color.clusterFuckMute)
            HStack(spacing: ClusterFuckSpacing.sm) {
                Button("Ground") { Task { await model.groundMusic() } }
                    .frame(minHeight: ClusterFuckIconSize.hit)
                    .disabled(model.isBusy)
                    .accessibilityLabel("Queue grounding music")
                Button("Explore") { Task { await model.exploreMusic() } }
                    .frame(minHeight: ClusterFuckIconSize.hit)
                    .disabled(model.isBusy)
                    .accessibilityLabel("Allow exploratory music")
            }
            Text("Apple Music · Spotify · Sonos · DI.fm")
                .font(.caption2)
                .foregroundStyle(Color.clusterFuckMute)
        }
        .padding(ClusterFuckSpacing.md)
        .frame(maxWidth: .infinity)
    }

    private var doseTab: some View {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("DrugKit", systemImage: ClusterFuckSymbol.dose.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
            Text(String(format: "PCCI %.2f · ΔHRV %.1f", model.pcci, model.deltaHRV))
                .font(ClusterFuckType.caption.monospacedDigit())
                .foregroundStyle(Color.clusterFuckMute)
            Button("Log demo dose") {
                Task { await model.logDemoDose() }
            }
            .frame(minHeight: ClusterFuckIconSize.hit)
            .disabled(model.isBusy)
            .accessibilityLabel("Log demo dose for pharmacovigilance")
            if model.groundingAlert {
                Text("grounding_alert")
                    .foregroundStyle(Color.clusterFuckDestructive)
                    .font(.caption.bold())
                    .accessibilityLabel("Grounding alert: predicted versus observed delta HRV mismatch")
            }
        }
        .padding(ClusterFuckSpacing.md)
        .frame(maxWidth: .infinity)
    }

    private var environmentTab: some View {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("Environment", systemImage: ClusterFuckSymbol.environment.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
            Text("Alexa lights: \(model.alexaLights)%")
                .font(ClusterFuckType.caption)
                .foregroundStyle(Color.clusterFuckMute)
            HStack(spacing: ClusterFuckSpacing.sm) {
                Button("ANC") { Task { await model.setANC() } }
                    .frame(minHeight: ClusterFuckIconSize.hit)
                    .disabled(model.isBusy)
                    .accessibilityLabel("Enable AirPods noise cancellation")
                Button("Transparency") { Task { await model.setTransparency() } }
                    .frame(minHeight: ClusterFuckIconSize.hit)
                    .disabled(model.isBusy)
                    .accessibilityLabel("Enable AirPods transparency")
            }
            Button("Voice: chill + dim") {
                Task { await model.voiceChill() }
            }
            .frame(minHeight: ClusterFuckIconSize.hit)
            .disabled(model.isBusy)
            .accessibilityLabel("Voice command chill music and dim lights")
        }
        .padding(ClusterFuckSpacing.md)
        .frame(maxWidth: .infinity)
    }

    private var compactChrome: Bool {
        #if os(watchOS)
        true
        #else
        sizeClass != .regular
        #endif
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
    @Published public var isBusy = false
    @Published public var lastError: String?

    public let manager: PharmaControlSessionManager

    public init(manager: PharmaControlSessionManager = PharmaControlSessionManager()) {
        self.manager = manager
    }

    public func start() async {
        isBusy = true
        defer { isBusy = false }
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
        state.physiologicalSCI = sci
        let snap = await manager.loop.crooks.update(with: state)
        manager.loop.replaceState(state)
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
        isBusy = true
        defer { isBusy = false }
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
        isBusy = true
        defer { isBusy = false }
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
        isBusy = true
        defer { isBusy = false }
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
