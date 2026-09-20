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
            if usesSidebar {
                NavigationSplitView {
                    List(selection: Binding<Int?>(
                        get: { model.selectedTab },
                        set: { if let selection = $0 { model.selectedTab = selection } }
                    )) {
                        navRow(0, title: "σ_irr", symbol: .sigma)
                        navRow(1, title: "Music", symbol: .music)
                        navRow(2, title: "DrugKit", symbol: .dose)
                        navRow(3, title: "Environment", symbol: .environment)
                    }
                    .navigationTitle("Remote")
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                } detail: {
                    page(for: model.selectedTab)
                        .padding(ClusterFuckSpacing.lg)
                        .frame(maxWidth: 720, alignment: .top)
                }
            } else {
                pagedRemote
            }
            #endif
        }
        .background(Color.clusterFuckBackground.ignoresSafeArea())
        .task {
            while !Task.isCancelled {
                model.refreshHealthReadings()
                do { try await Task.sleep(for: .seconds(1)) }
                catch { break }
            }
        }
        .alert("Action could not complete", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }

    private var pagedRemote: some View {
        TabView(selection: $model.selectedTab) {
            sigmaTab
                .tabItem { Label("σ_irr", systemImage: ClusterFuckSymbol.sigma.systemName) }
                .tag(0)
            musicTab
                .tabItem { Label("Music", systemImage: ClusterFuckSymbol.music.systemName) }
                .tag(1)
            doseTab
                .tabItem { Label("DrugKit", systemImage: ClusterFuckSymbol.dose.systemName) }
                .tag(2)
            environmentTab
                .tabItem { Label("Environment", systemImage: ClusterFuckSymbol.environment.systemName) }
                .tag(3)
        }
        #if os(watchOS)
        .tabViewStyle(.verticalPage)
        #endif
    }

    private func navRow(_ tag: Int, title: String, symbol: ClusterFuckSymbol) -> some View {
        Label(title, systemImage: symbol.systemName)
            .tag(tag)
            .symbolRenderingMode(.monochrome)
            .frame(minHeight: ClusterFuckIconSize.hit)
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
                evidenceLabel(model.controlEvidence.label)
                Text(model.healthStatusLabel)
                    .font(.caption)
                    .foregroundStyle(Color.clusterFuckMute)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.healthMetricsLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.clusterFuckInk)
                SigmaHUDView(
                    sigmaIrr: model.displaySigma,
                    closurePercent: model.closurePercent,
                    phase: CrooksCyclePhase(rawValue: model.phaseLabel) ?? .forward,
                    lastAction: model.lastAction,
                    compact: compactChrome
                )
                SCIVisualizationView(score: model.displaySCI, trend: model.sciTrend)
                    .frame(minHeight: compactChrome ? 64 : 88)
                    .accessibilityLabel(model.sciAccessibilityLabel)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ClusterFuckSpacing.sm) {
                        sessionButton
                        minimizeButton
                    }
                    VStack(spacing: ClusterFuckSpacing.sm) {
                        sessionButton
                        minimizeButton
                    }
                }
                Text("Experimental control index. Not a medical measurement or dosing recommendation.")
                    .font(.caption)
                    .foregroundStyle(Color.clusterFuckMute)
                    .fixedSize(horizontal: false, vertical: true)
                if let err = model.lastError, !err.isEmpty {
                    Text(err)
                        .font(ClusterFuckType.caption)
                        .foregroundStyle(Color.clusterFuckFailText)
                        .accessibilityLabel("Error \(err)")
                }
                if model.isBusy {
                    ClusterFuckLoadingRow()
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
        .buttonStyle(ClusterFuckPressStyle())
        .disabled(model.isBusy)
        .accessibilityLabel(model.isSessionRunning ? "Stop pharmacovigilance session" : "Start pharmacovigilance session")
    }

    private var minimizeButton: some View {
        Button {
            Task { await model.forceMinimize() }
        } label: {
            Label(model.isBusy ? "Working…" : "Minimize σ", systemImage: ClusterFuckSymbol.minimize.systemName)
                .frame(maxWidth: .infinity, minHeight: ClusterFuckIconSize.hit)
                .foregroundStyle(Color.clusterFuckOnAccent)
                .background(Color.clusterFuckAccent, in: RoundedRectangle(cornerRadius: ClusterFuckRadius.sm, style: .continuous))
        }
        .buttonStyle(ClusterFuckPressStyle())
        .disabled(model.isBusy)
        .accessibilityLabel("Minimize irreversible entropy production")
        .accessibilityHint("Drives music, Alexa, and AirPods actuators")
    }

    private var musicTab: some View {
        ScrollView {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("Music stack", systemImage: ClusterFuckSymbol.music.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
            evidenceLabel(model.audioEvidence.label)
            Text(model.musicMetricsLabel)
                .font(ClusterFuckType.caption.monospacedDigit())
                .foregroundStyle(Color.clusterFuckMute)
            HStack(spacing: ClusterFuckSpacing.sm) {
                Button("Ground") { Task { await model.groundMusic() } }
                    .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
                    .buttonStyle(ClusterFuckPressStyle())
                    .disabled(model.isBusy)
                    .accessibilityLabel("Queue grounding music")
                Button("Explore") { Task { await model.exploreMusic() } }
                    .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
                    .buttonStyle(ClusterFuckPressStyle())
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
    }

    private var doseTab: some View {
        ScrollView {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("DrugKit", systemImage: ClusterFuckSymbol.dose.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
            evidenceLabel(model.doseEvidence.label)
            Text(model.doseMetricsLabel)
                .font(ClusterFuckType.caption.monospacedDigit())
                .foregroundStyle(Color.clusterFuckMute)
            Button("Log demo dose") {
                Task { await model.logDemoDose() }
            }
            .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
            .buttonStyle(ClusterFuckPressStyle())
            .disabled(model.isBusy)
            .accessibilityLabel("Log demo dose for pharmacovigilance")
            if model.groundingAlert {
                Label("Demo grounding alert", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Color.clusterFuckFailText)
                    .font(.caption.bold())
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("Simulated grounding alert, not a measured health finding")
            }
        }
        .padding(ClusterFuckSpacing.md)
        .frame(maxWidth: .infinity)
        }
    }

    private var environmentTab: some View {
        ScrollView {
        VStack(spacing: ClusterFuckSpacing.sm) {
            Label("Environment", systemImage: ClusterFuckSymbol.environment.systemName)
                .font(ClusterFuckType.headline)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Color.clusterFuckSecondary)
            Text(model.alexaLightsLabel)
                .font(ClusterFuckType.caption.monospacedDigit())
                .foregroundStyle(Color.clusterFuckMute)
                .accessibilityLabel(model.alexaLightsLabel)
            Text("Device state unavailable. Commands express intent until an integration confirms the result.")
                .font(.caption)
                .foregroundStyle(Color.clusterFuckMute)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ClusterFuckSpacing.sm) {
                Button("ANC") { Task { await model.setANC() } }
                    .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
                    .buttonStyle(ClusterFuckPressStyle())
                    .disabled(model.isBusy)
                    .accessibilityLabel("Enable AirPods noise cancellation")
                Button("Transparency") { Task { await model.setTransparency() } }
                    .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
                    .buttonStyle(ClusterFuckPressStyle())
                    .disabled(model.isBusy)
                    .accessibilityLabel("Enable AirPods transparency")
            }
            Button("Voice: chill + dim") {
                Task { await model.voiceChill() }
            }
            .frame(minWidth: ClusterFuckIconSize.hit, minHeight: ClusterFuckIconSize.hit)
            .buttonStyle(ClusterFuckPressStyle())
            .disabled(model.isBusy)
            .accessibilityLabel("Voice command chill music and dim lights")
        }
        .padding(ClusterFuckSpacing.md)
        .frame(maxWidth: .infinity)
        }
    }

    private func evidenceLabel(_ label: String) -> some View {
        Label(label, systemImage: label.contains("Demo") ? "testtube.2" : "sensor.tag.radiowaves.forward")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.clusterFuckMute)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var usesSidebar: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    private var compactChrome: Bool {
        #if os(watchOS)
        true
        #else
        !usesSidebar
        #endif
    }
}

@MainActor
public final class RemoteSessionViewModel: ObservableObject {
    @Published public var selectedTab = 0
    @Published public var sigmaIrr: Double = .nan
    @Published public var closurePercent: Double = 0
    @Published public var phaseLabel: String = CrooksCyclePhase.forward.rawValue
    @Published public var lastAction: String = "idle"
    @Published public var sciScore: Double? = nil
    @Published public var sciTrend: SCITrend = .stable
    @Published public var musicBPM: Double = 120
    @Published public var audioEntropy: Double = 0
    @Published public var pcci: Double = 0
    @Published public var deltaHRV: Double = 0
    @Published public var groundingAlert = false
    @Published public var alexaLights: Int = 60
    @Published public var isBusy = false
    @Published public var lastError: String?

    @Published public private(set) var controlEvidence: RemoteHUDEvidence = .unavailable
    @Published public private(set) var physiologicalEvidence: RemoteHUDEvidence = .unavailable
    @Published public private(set) var audioEvidence: RemoteHUDEvidence = .unavailable
    @Published public private(set) var doseEvidence: RemoteHUDEvidence = .unavailable
    @Published public private(set) var requestedLights: Int?
    @Published public private(set) var healthStatusLabel = RemoteHealthStatus.idle.message
    @Published public private(set) var healthMetricsLabel = "Heart rate — · SDNN —"
    @Published public private(set) var hasHealthReadings = false
    private var lastHealthBeatDate: Date?
    private var generation = 0

    public let manager: PharmaControlSessionManager

    public init(manager: PharmaControlSessionManager = PharmaControlSessionManager()) {
        self.manager = manager
    }

    public func start() async {
        guard !isBusy, !manager.isRunning else { return }
        lastError = nil
        isBusy = true
        defer { isBusy = false }
        let operationGeneration = generation
        await manager.start()
        guard generation == operationGeneration else {
            manager.stop()
            return
        }
        await refreshFromLoop()
    }

    /// Stop the pharmacovigilance / remote session.
    public func stop() {
        generation += 1
        manager.stop()
        controlEvidence = .unavailable
        physiologicalEvidence = .unavailable
        audioEvidence = .unavailable
        doseEvidence = .unavailable
        sigmaIrr = .nan
        closurePercent = 0
        sciScore = nil
        groundingAlert = false
        requestedLights = nil
        lastHealthBeatDate = nil
        hasHealthReadings = false
        healthStatusLabel = RemoteHealthStatus.idle.message
        healthMetricsLabel = "Heart rate — · SDNN —"
        lastAction = "session_stopped"
    }

    public var isSessionRunning: Bool { manager.isRunning }

    public func refreshHealthReadings(at date: Date = Date()) {
        let health = manager.observedHealth(at: date)
        hasHealthReadings = health.readings.hasReadings
        healthStatusLabel = health.readings.message
        let heart = health.readings.heartRate.map { String(format: "%.0f bpm", $0.value) } ?? "—"
        let sdnn = health.readings.sdnn.map { String(format: "%.1f ms", $0.value) } ?? "—"
        healthMetricsLabel = "Heart rate \(heart) · SDNN \(sdnn)"
        if let beats = health.readings.beats, let control = health.control {
            // Keep any demo clearly marked until the user stops that demo session.
            guard physiologicalEvidence != .simulated, controlEvidence != .simulated else { return }
            guard beats.date != lastHealthBeatDate else { return }
            lastHealthBeatDate = beats.date
            physiologicalEvidence = .measured
            controlEvidence = .derived
            let state = manager.loop.state
            sciScore = state.sci
            deltaHRV = state.deltaHRV
            sigmaIrr = control.sigmaIrr
            closurePercent = control.closurePercent
            phaseLabel = control.phase.rawValue
            lastAction = control.lastActionSummary
        } else if physiologicalEvidence == .measured {
            physiologicalEvidence = .unavailable
            controlEvidence = .unavailable
            sciScore = nil
            sigmaIrr = .nan
            closurePercent = 0
            lastHealthBeatDate = nil
        }
    }

    public var sessionStatusLabel: String {
        RemoteHUDEvidence.sessionLabel(isRunning: isSessionRunning,
            evidence: [controlEvidence, physiologicalEvidence, audioEvidence, doseEvidence, hasHealthReadings ? .measured : .unavailable])
    }

    public var displaySigma: Double { controlEvidence.displayValue(sigmaIrr) ?? .nan }
    public var displaySCI: Double? { physiologicalEvidence.displayValue(sciScore) }

    public var musicMetricsLabel: String {
        guard let bpm = audioEvidence.displayValue(musicBPM),
              let entropy = audioEvidence.displayValue(audioEntropy) else {
            return "BPM — · H_audio —"
        }
        let prefix = audioEvidence == .simulated ? "Demo · " : ""
        return prefix + String(format: "BPM %.0f · H_audio %.2f bit", bpm, entropy)
    }

    public var doseMetricsLabel: String {
        let pcciText = doseEvidence.displayValue(pcci).map { String(format: "%.2f", $0) } ?? "—"
        let hrvText = physiologicalEvidence.displayValue(deltaHRV).map { String(format: "%.1f", $0) } ?? "—"
        let prefix = doseEvidence == .simulated || physiologicalEvidence == .simulated ? "Demo · " : ""
        return prefix + "PCCI \(pcciText) · ΔHRV \(hrvText)"
    }

    /// Local command targets do not establish the state of a physical light.
    public var alexaLightsLabel: String {
        guard let requestedLights else { return "Alexa lights: —" }
        return "Requested lights: \(requestedLights)% · unconfirmed"
    }

    public var sciAccessibilityLabel: String {
        guard let score = displaySCI, score.isFinite else {
            return "Shannon collapse index unavailable"
        }
        let prefix = physiologicalEvidence == .simulated ? "Simulated " : ""
        return prefix + String(format: "Shannon collapse index %.2f", score)
    }

    /// Drive multi-signal update through the **shipped** control path (app UI + tests).
    @discardableResult
    public func applySyntheticMultiSignal(
        deltaHRV: Double,
        musicBPM: Double,
        audioEntropy: Double,
        sci: Double
    ) async -> CrooksSnapshot {
        let operationGeneration = generation
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
        guard generation == operationGeneration else { return snap }
        controlEvidence = .simulated
        physiologicalEvidence = .simulated
        audioEvidence = .simulated
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
        await refreshFromLoop()
    }

    public func groundMusic() async {
        await performCommands([
            RemoteCommand(service: .appleMusic, action: "queueGrounding"),
            RemoteCommand(service: .spotify, action: "queueGrounding"),
            RemoteCommand(service: .diFm, action: "preferChillChannel")
        ])
    }

    public func exploreMusic() async {
        await performCommands([
            RemoteCommand(service: .diFm, action: "preferProgressiveChannel"),
            RemoteCommand(service: .appleMusic, action: "allowExploration")
        ])
    }

    public func logDemoDose() async {
        isBusy = true
        defer { isBusy = false }
        let operationGeneration = generation
        let result = await manager.loop.logDose(
            DrugLog(substance: "2C-B", doseMg: 12, setAndSetting: "home / lo-fi", hrDelta: 8, entropyShift: 1.2)
        )
        guard generation == operationGeneration else { return }
        controlEvidence = .simulated
        doseEvidence = .simulated
        groundingAlert = result.prediction.isGroundingAlert
        pcci = result.pcci
        await refreshFromLoop()
    }

    public func setANC() async {
        await performCommands([
            RemoteCommand(service: .airPods, action: "enableANC")
        ])
    }

    public func setTransparency() async {
        await performCommands([
            RemoteCommand(service: .airPods, action: "transparency")
        ])
    }

    public func voiceChill() async {
        isBusy = true
        defer { isBusy = false }
        await manager.loop.handleVoice("chill music and dim lights")
        requestedLights = manager.loop.alexa.lightsPercent
        await refreshFromLoop()
    }

    private func performCommands(_ commands: [RemoteCommand]) async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        var failures: [String] = []
        for command in commands {
            do {
                try await manager.loop.bus.execute(command)
            } catch {
                failures.append("\(command.service.rawValue): \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty { lastError = failures.joined(separator: "\n") }
        await refreshFromLoop()
    }

    private func refreshFromLoop() async {
        let operationGeneration = generation
        let snap = await manager.loop.crooks.snapshot()
        guard generation == operationGeneration else { return }
        let state = manager.loop.state
        musicBPM = state.musicBPM
        audioEntropy = state.audioEntropyBits
        deltaHRV = state.deltaHRV
        pcci = state.pcci
        sciScore = physiologicalEvidence.displayValue(state.sci)
        alexaLights = manager.loop.alexa.lightsPercent
        sigmaIrr = controlEvidence.displayValue(snap.sigmaIrr) ?? .nan
        closurePercent = controlEvidence == .unavailable ? 0 : snap.closurePercent
        phaseLabel = snap.phase.rawValue
        lastAction = snap.lastActionSummary
    }
}
