import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

/// Session lifecycle manager: HealthKit workout session optional, Crooks loop always active.
public final class PharmaControlSessionManager: @unchecked Sendable {
    public let loop: RemoteControlLoop
    private let lock = NSLock()
    private var _running = false
    private var _startedAt: Date?

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    #endif

    public init(loop: RemoteControlLoop = RemoteControlLoop()) {
        self.loop = loop
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
        await loop.attach()
        lock.lock()
        _running = true
        _startedAt = Date()
        lock.unlock()

        #if canImport(HealthKit)
        let types: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        ]
        do {
            try await healthStore.requestAuthorization(toShare: [], read: types)
        } catch {
            // Authorization may fail in unit tests / CI — loop still runs on injected samples.
        }
        #endif
    }

    public func stop() {
        lock.lock()
        _running = false
        lock.unlock()
        #if canImport(HealthKit)
        workoutSession?.end()
        workoutSession = nil
        #endif
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
