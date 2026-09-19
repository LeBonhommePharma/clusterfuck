import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

/// Whether this process may call `HKHealthStore.requestAuthorization` without aborting.
///
/// `requestAuthorization` raises `NSInvalidArgumentException` (not a Swift `Error`)
/// when `NSHealthShareUsageDescription` is missing. SPM `swift test` has no app
/// Info.plist, so the Crooks loop must still start on injected samples.
public enum HealthKitAuthorizationGate: Sendable {
    public static func canRequestReadAuthorization(in bundle: Bundle = .main) -> Bool {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let raw = bundle.object(forInfoDictionaryKey: "NSHealthShareUsageDescription") as? String
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !text.isEmpty
        #else
        return false
        #endif
    }
}

/// Session lifecycle manager: HealthKit workout session optional, Crooks loop always active.
public final class PharmaControlSessionManager: @unchecked Sendable {
    public let loop: RemoteControlLoop
    private let lock = NSLock()
    private var _running = false
    private var _startedAt: Date?

    private let healthSource: any RemoteHealthObserving
    private var observationTask: Task<Void, Never>?
    private var generation = 0
    private var readings = RemoteHealthReadings()
    private var healthControlSnapshot: CrooksSnapshot?

    public init(loop: RemoteControlLoop = RemoteControlLoop(), healthSource: any RemoteHealthObserving = HealthKitRemoteSource()) {
        self.loop = loop
        self.healthSource = healthSource
    }

    deinit { observationTask?.cancel() }

    public func observedHealth(at date: Date = Date()) -> (readings: RemoteHealthReadings, control: CrooksSnapshot?) {
        lock.lock(); defer { lock.unlock() }
        var current = readings
        current.expire(at: date)
        return (current, current.beats == nil ? nil : healthControlSnapshot)
    }

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return _running
    }

    public var startedAt: Date? {
        lock.lock(); defer { lock.unlock() }
        return _startedAt
    }

    public func start() async {
        lock.lock()
        guard !_running else { lock.unlock(); return }
        _running = true
        generation += 1
        let currentGeneration = generation
        _startedAt = Date()
        readings = RemoteHealthReadings()
        healthControlSnapshot = nil
        lock.unlock()
        loop.deltaHRV.reset()
        loop.replaceState(RemoteMultiSignalState())
        await loop.crooks.reset()
        await loop.attach()
        lock.lock()
        guard _running, generation == currentGeneration else { lock.unlock(); return }
        let source = healthSource
        observationTask = Task { [weak self] in
            for await event in source.events() {
                guard !Task.isCancelled else { break }
                await self?.receive(event, generation: currentGeneration)
            }
        }
        lock.unlock()
    }

    public func stop() {
        lock.lock()
        _running = false
        generation += 1
        observationTask?.cancel()
        observationTask = nil
        readings = RemoteHealthReadings()
        healthControlSnapshot = nil
        lock.unlock()
    }

    private func receive(_ event: RemoteHealthEvent, generation expected: Int) async {
        lock.lock()
        guard _running, generation == expected else { lock.unlock(); return }
        readings.apply(event)
        let beats = readings.beats
        lock.unlock()
        guard case .beatIntervals(_, let date) = event, let beats, beats.date == date else { return }
        // Neither a heart-rate scalar nor Apple's SDNN quantity can stand in for
        // RMSSD. Only actual contiguous beat intervals enter the HRV control path.
        let control = await loop.ingestHRV(rmssd: beats.rmssd, sdnn: beats.sdnn, rrIntervals: beats.intervals)
        lock.lock(); defer { lock.unlock() }
        guard _running, generation == expected else { return }
        healthControlSnapshot = control
    }

    public func logDose(substance: String, doseMg: Double, setAndSetting: String) async -> CrooksSnapshot {
        let log = DrugLog(
            substance: substance,
            doseMg: doseMg,
            setAndSetting: setAndSetting
        )
        let result = await loop.logDose(log)
        return result.snapshot
    }
}
