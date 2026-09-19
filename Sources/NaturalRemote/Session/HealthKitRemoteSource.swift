import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Reads saved Health samples while this app's session is active. This does not
/// start a workout or promise continuous background sensor acquisition.
public struct HealthKitRemoteSource: RemoteHealthObserving {
    public init() {}
    public func events() -> AsyncStream<RemoteHealthEvent> {
        #if canImport(HealthKit)
        return AsyncStream { continuation in
            let session = HealthKitObservationSession(continuation: continuation)
            continuation.onTermination = { _ in session.stop() }
            Task { await session.start() }
        }
        #else
        return AsyncStream { $0.yield(.status(.unavailable)); $0.finish() }
        #endif
    }
}

#if canImport(HealthKit)
private final class HealthKitObservationSession: @unchecked Sendable {
    private let store = HKHealthStore()
    private let continuation: AsyncStream<RemoteHealthEvent>.Continuation
    private let lock = NSRecursiveLock()
    private var queries: [HKQuery] = []
    private var cancelled = false
    private var validSeries: Set<UUID> = []

    init(continuation: AsyncStream<RemoteHealthEvent>.Continuation) { self.continuation = continuation }

    func start() async {
        guard HealthKitAuthorizationGate.canRequestReadAuthorization() else {
            emit(.status(.unavailable)); continuation.finish(); return
        }
        let heart = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sdnn = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let beats = HKSeriesType.heartbeat()
        emit(.status(.requestingAuthorization))
        do {
            try await store.requestAuthorization(toShare: [], read: [heart, sdnn, beats])
        } catch {
            emit(.status(.failed(error.localizedDescription))); continuation.finish(); return
        }
        // A successful permission request is not evidence of read permission.
        emit(.status(.noDataOrDenied))
        observe(heart, metric: .heartRate)
        observe(sdnn, metric: .sdnn)
        observe(beats, metric: .beatIntervals)
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        queries.forEach { store.stop($0) }
        queries.removeAll(); validSeries.removeAll()
    }

    private func emit(_ event: RemoteHealthEvent) {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return }
        continuation.yield(event)
    }

    private func execute(_ query: HKQuery) {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return }
        queries.append(query)
        store.execute(query)
    }

    private func observe(_ type: HKSampleType, metric: RemoteHealthMetric) {
        let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-120), end: nil, options: .strictEndDate)
        let handler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = { [weak self] _, samples, deleted, _, error in
            guard let self else { return }
            if let error { self.emit(.status(.failed(error.localizedDescription))); return }
            if let deleted, !deleted.isEmpty {
                self.lock.lock()
                deleted.forEach { self.validSeries.remove($0.uuid) }
                self.lock.unlock()
                self.emit(.invalidated(metric))
            }
            for sample in (samples ?? []).sorted(by: { $0.endDate < $1.endDate }) {
                if let value = sample as? HKQuantitySample {
                    switch metric {
                    case .heartRate: self.emit(.heartRate(value.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())), value.endDate))
                    case .sdnn: self.emit(.sdnn(value.quantity.doubleValue(for: .secondUnit(with: .milli)), value.endDate))
                    case .beatIntervals: break
                    }
                } else if let series = sample as? HKHeartbeatSeriesSample {
                    self.readBeats(series)
                }
            }
        }
        let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit, resultsHandler: handler)
        query.updateHandler = handler
        execute(query)
    }

    private func readBeats(_ series: HKHeartbeatSeriesSample) {
        lock.lock(); validSeries.insert(series.uuid); lock.unlock()
        let accumulator = LockedBeatAccumulator()
        let query = HKHeartbeatSeriesQuery(heartbeatSeries: series) { [weak self] query, time, gap, done, error in
            guard let self else { return }
            self.lock.lock(); defer { self.lock.unlock() }
            guard !self.cancelled, self.validSeries.contains(series.uuid) else { return }
            if let error {
                self.emit(.status(.failed(error.localizedDescription)))
                self.queries.removeAll { $0 === query }
                self.validSeries.remove(series.uuid)
                return
            }
            accumulator.append(time: time, gap: gap)
            if done {
                if let stats = accumulator.statistics(at: series.endDate) {
                    self.emit(.beatIntervals(stats.intervals, stats.date))
                }
                self.queries.removeAll { $0 === query }
                self.validSeries.remove(series.uuid)
            }
        }
        execute(query)
    }
}

private final class LockedBeatAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var accumulator = RemoteHeartbeatAccumulator()
    func append(time: TimeInterval, gap: Bool) {
        lock.lock(); defer { lock.unlock() }
        accumulator.append(time: time, precededByGap: gap)
    }
    func statistics(at date: Date) -> RemoteBeatStatistics? {
        lock.lock(); defer { lock.unlock() }
        return accumulator.statistics(at: date)
    }
}
#endif
