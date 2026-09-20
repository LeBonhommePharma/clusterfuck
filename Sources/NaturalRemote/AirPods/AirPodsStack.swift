import Foundation

#if canImport(CoreMotion)
import CoreMotion
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(MediaPlayer)
import MediaPlayer
#endif

// MARK: - Shared headphone state

public enum NoiseControlMode: String, Codable, Sendable, CaseIterable {
    case off
    case transparency
    case adaptive
    case noiseCancellation
}

public struct HeadPose: Codable, Sendable, Equatable {
    public var pitch: Double
    public var roll: Double
    public var yaw: Double
    public var timestamp: Date

    public init(pitch: Double, roll: Double, yaw: Double, timestamp: Date = Date()) {
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.timestamp = timestamp
    }
}

public struct AirPodsTelemetry: Codable, Sendable, Equatable {
    public var chipGeneration: String
    public var noiseMode: NoiseControlMode
    public var volume: Float
    public var headPose: HeadPose?
    public var spatialAudioEnabled: Bool
    public var personalizedSpatialEnabled: Bool
    public var conversationAwarenessActive: Bool
    public var adaptiveAudioActive: Bool
    public var heartRateBPM: Double?
    public var rrIntervalsMs: [Double]
    public var timestamp: Date

    public init(
        chipGeneration: String,
        noiseMode: NoiseControlMode = .off,
        volume: Float = 0.5,
        headPose: HeadPose? = nil,
        spatialAudioEnabled: Bool = false,
        personalizedSpatialEnabled: Bool = false,
        conversationAwarenessActive: Bool = false,
        adaptiveAudioActive: Bool = false,
        heartRateBPM: Double? = nil,
        rrIntervalsMs: [Double] = [],
        timestamp: Date = Date()
    ) {
        self.chipGeneration = chipGeneration
        self.noiseMode = noiseMode
        self.volume = volume
        self.headPose = headPose
        self.spatialAudioEnabled = spatialAudioEnabled
        self.personalizedSpatialEnabled = personalizedSpatialEnabled
        self.conversationAwarenessActive = conversationAwarenessActive
        self.adaptiveAudioActive = adaptiveAudioActive
        self.heartRateBPM = heartRateBPM
        self.rrIntervalsMs = rrIntervalsMs
        self.timestamp = timestamp
    }
}

// MARK: - AirPods Max (H1)

/// H1 stack: Digital Crown volume proxy, head tracking, spatial audio, ANC/Transparency control surfaces.
public final class AirPodsMaxH1Controller: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .airPods
    public let chipGeneration = "H1"

    private let lock = NSLock()
    private var telemetry: AirPodsTelemetry
    #if canImport(CoreMotion)
    #if os(iOS) || os(watchOS)
    private let motionManager = CMHeadphoneMotionManager()
    #endif
    #endif
    public var onTelemetry: (@Sendable (AirPodsTelemetry) -> Void)?

    public init() {
        self.telemetry = AirPodsTelemetry(chipGeneration: "H1")
    }

    public func currentTelemetry() -> AirPodsTelemetry {
        return lock.withLock { telemetry }
    }

    /// Digital Crown acts as temperature/intensity dial via system volume proxy.
    public func setCrownVolume(_ volume: Float) {
        let v = min(1, max(0, volume))
        #if canImport(MediaPlayer)
        #if !os(macOS)
        // MPVolumeView / system volume is the supported public proxy for Crown-linked volume on iOS/watchOS.
        let sliderVolume = v
        // AVAudioSession output volume is read-only; volume changes go through MPVolumeView on device.
        // We still record the desired crown mapping for the control loop.
        _ = sliderVolume
        #endif
        #endif
        #if canImport(AVFoundation)
        // Persist desired volume for entropy work terms.
        #endif
        lock.withLock {
        telemetry.volume = v
        }
        publish()
    }

    public func setNoiseMode(_ mode: NoiseControlMode) {
        lock.withLock {
        telemetry.noiseMode = mode
        }
        // Public apps cannot force ANC via private API; we expose control surface + state for Crooks.
        publish()
    }

    public func setSpatialAudioEnabled(_ enabled: Bool) {
        lock.withLock {
        telemetry.spatialAudioEnabled = enabled
        }
        publish()
    }

    public func startHeadTracking() {
        #if canImport(CoreMotion)
        #if os(iOS) || os(watchOS)
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let attitude = motion.attitude
            let pose = HeadPose(
                pitch: attitude.pitch,
                roll: attitude.roll,
                yaw: attitude.yaw
            )
            self.lock.lock()
            self.telemetry.headPose = pose
            self.lock.unlock()
            self.publish()
        }
        #endif
        #endif
    }

    public func stopHeadTracking() {
        #if canImport(CoreMotion)
        #if os(iOS) || os(watchOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
        #endif
    }

    /// Inject pose for unit tests / simulators without hardware.
    public func injectHeadPose(_ pose: HeadPose) {
        lock.withLock {
        telemetry.headPose = pose
        }
        publish()
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "enableANC", "noiseCancellation":
            setNoiseMode(.noiseCancellation)
        case "transparency":
            setNoiseMode(.transparency)
        case "adaptive":
            setNoiseMode(.adaptive)
        case "setVolume":
            if let v = Float(command.params["volume"] ?? "") {
                setCrownVolume(v)
            }
        case "spatialOn":
            setSpatialAudioEnabled(true)
        case "spatialOff":
            setSpatialAudioEnabled(false)
        case "startHeadTracking":
            startHeadTracking()
        case "stopHeadTracking":
            stopHeadTracking()
        default:
            break
        }
    }

    private func publish() {
        let snap = currentTelemetry()
        onTelemetry?(snap)
    }
}

// MARK: - AirPods Pro 3 (H2)

/// H2 stack: on-device HR / R-R surfaces, Adaptive Audio, Personalized Spatial, Conversation Awareness.
///
/// Heart-rate samples are ingested from HealthKit / headphone biometric pipelines when available;
/// this controller owns fusion and exposure to Crooks, not private firmware APIs.
public final class AirPodsProH2Controller: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .airPods
    public let chipGeneration = "H2"

    private let lock = NSLock()
    private var telemetry: AirPodsTelemetry
    public var onTelemetry: (@Sendable (AirPodsTelemetry) -> Void)?

    public init() {
        self.telemetry = AirPodsTelemetry(chipGeneration: "H2")
    }

    public func currentTelemetry() -> AirPodsTelemetry {
        return lock.withLock { telemetry }
    }

    public func setAdaptiveAudio(_ active: Bool) {
        lock.withLock {
        telemetry.adaptiveAudioActive = active
        if active { telemetry.noiseMode = .adaptive }
        }
        publish()
    }

    public func setPersonalizedSpatial(_ enabled: Bool) {
        lock.withLock {
        telemetry.personalizedSpatialEnabled = enabled
        telemetry.spatialAudioEnabled = enabled || telemetry.spatialAudioEnabled
        }
        publish()
    }

    public func setConversationAwareness(_ active: Bool) {
        lock.withLock {
        telemetry.conversationAwarenessActive = active
        }
        publish()
    }

    public func setNoiseMode(_ mode: NoiseControlMode) {
        lock.withLock {
        telemetry.noiseMode = mode
        }
        publish()
    }

    /// Ingest biometric samples from HealthKit headphone path or lab fixture.
    public func ingestHeartRate(bpm: Double, rrIntervalsMs: [Double]) {
        lock.withLock {
        telemetry.heartRateBPM = bpm
        telemetry.rrIntervalsMs = rrIntervalsMs
        }
        publish()
    }

    public func execute(_ command: RemoteCommand) async throws {
        switch command.action {
        case "enableANC", "noiseCancellation":
            setNoiseMode(.noiseCancellation)
        case "transparency":
            setNoiseMode(.transparency)
        case "adaptive", "enableAdaptiveAudio":
            setAdaptiveAudio(true)
        case "disableAdaptiveAudio":
            setAdaptiveAudio(false)
        case "personalizedSpatialOn":
            setPersonalizedSpatial(true)
        case "personalizedSpatialOff":
            setPersonalizedSpatial(false)
        case "conversationAwarenessOn":
            setConversationAwareness(true)
        case "conversationAwarenessOff":
            setConversationAwareness(false)
        case "ingestHR":
            let bpm = Double(command.params["bpm"] ?? "0") ?? 0
            let rr = (command.params["rr"] ?? "")
                .split(separator: ",")
                .compactMap { Double($0) }
            ingestHeartRate(bpm: bpm, rrIntervalsMs: rr)
        default:
            break
        }
    }

    /// Map H2 telemetry into Crooks multi-signal fields.
    public func apply(to state: inout RemoteMultiSignalState) {
        let t = currentTelemetry()
        state.airPodsANCEngaged = (t.noiseMode == .noiseCancellation || t.noiseMode == .adaptive)
        state.conversationAwarenessActive = t.conversationAwarenessActive
    }

    private func publish() {
        onTelemetry?(currentTelemetry())
    }
}

// MARK: - Dual-stack facade

public final class AirPodsDualStack: RemoteActuator, @unchecked Sendable {
    public let service: RemoteService = .airPods
    public let maxH1: AirPodsMaxH1Controller
    public let proH2: AirPodsProH2Controller
    private let lock = NSLock()
    private var activeChip: String = "H2"

    public init(
        maxH1: AirPodsMaxH1Controller = AirPodsMaxH1Controller(),
        proH2: AirPodsProH2Controller = AirPodsProH2Controller()
    ) {
        self.maxH1 = maxH1
        self.proH2 = proH2
    }

    public func setActiveChip(_ chip: String) {
        lock.withLock { activeChip = chip }
    }

    public func activeTelemetry() -> AirPodsTelemetry {
        let chip = lock.withLock { activeChip }
        if chip.uppercased().contains("H1") {
            return maxH1.currentTelemetry()
        }
        return proH2.currentTelemetry()
    }

    public func execute(_ command: RemoteCommand) async throws {
        let chip = lock.withLock { activeChip }
        if chip.uppercased().contains("H1") {
            try await maxH1.execute(command)
        } else {
            try await proH2.execute(command)
        }
        // Mirror acoustic mode commands to both for multi-device households.
        if ["enableANC", "noiseCancellation", "transparency", "adaptive"].contains(command.action) {
            try await maxH1.execute(command)
            try await proH2.execute(command)
        }
    }
}
