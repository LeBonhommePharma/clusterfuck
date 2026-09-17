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
        if HealthKitAuthorizationGate.canRequestReadAuthorization() {
            let types: Set<HKSampleType> = [
                HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            ]
            do {
                try await healthStore.requestAuthorization(toShare: [], read: types)
            } catch {
                // Authorization may fail in simulator / unsigned hosts — loop still runs.
            }
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
