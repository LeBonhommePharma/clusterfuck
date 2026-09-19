import Foundation

public enum RemoteHealthStatus: Sendable, Equatable {
    case idle, requestingAuthorization, noDataOrDenied, unavailable
    case failed(String)

    public var message: String {
        switch self {
        case .idle: return "Health observation stopped"
        case .requestingAuthorization: return "Waiting for Health permission"
        case .noDataOrDenied: return "No recent readable Health data. None may be available, or read access may not be granted."
        case .unavailable: return "Health data unavailable on this device"
        case .failed(let reason): return "Health observation failed: \(reason)"
        }
    }
}

public enum RemoteHealthMetric: Sendable { case heartRate, sdnn, beatIntervals }
public enum RemoteHealthEvent: Sendable {
    case status(RemoteHealthStatus)
    case heartRate(Double, Date)
    case sdnn(Double, Date)
    case beatIntervals([Double], Date)
    case invalidated(RemoteHealthMetric)
}

/// Injectable query boundary. Cancellation must stop every underlying query.
public protocol RemoteHealthObserving: Sendable {
    func events() -> AsyncStream<RemoteHealthEvent>
}

public struct RemoteHealthValue: Sendable, Equatable {
    public let value: Double
    public let date: Date
}

public struct RemoteBeatStatistics: Sendable, Equatable {
    public let intervals: [Double]
    public let date: Date
    public let rmssd: Double
    public let sdnn: Double

    public init?(intervals: [Double], date: Date) {
        guard intervals.count >= 4, intervals.allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(intervals.count - 1)
        let successive = zip(intervals.dropFirst(), intervals).reduce(0) { $0 + pow($1.0 - $1.1, 2) }
        let rmssd = sqrt(successive / Double(intervals.count - 1))
        let sdnn = sqrt(variance)
        guard rmssd.isFinite, sdnn.isFinite else { return nil }
        self.intervals = intervals; self.date = date; self.rmssd = rmssd; self.sdnn = sdnn
    }
}

/// One contiguous run only: never derive adjacent RR differences across missing beats.
public struct RemoteHeartbeatAccumulator: Sendable {
    private var previous: TimeInterval?
    private var intervals: [Double] = []
    public init() {}
    public mutating func append(time: TimeInterval, precededByGap: Bool) {
        guard time.isFinite, time >= 0 else { previous = nil; intervals = []; return }
        if precededByGap { intervals = []; previous = time; return }
        if let previous {
            let interval = (time - previous) * 1_000
            if interval > 0, interval.isFinite { intervals.append(interval) }
            else { intervals = [] }
        }
        previous = time
    }
    public func statistics(at date: Date) -> RemoteBeatStatistics? {
        RemoteBeatStatistics(intervals: intervals, date: date)
    }
}

public struct RemoteHealthReadings: Sendable {
    public private(set) var status: RemoteHealthStatus = .idle
    public private(set) var heartRate: RemoteHealthValue?
    public private(set) var sdnn: RemoteHealthValue?
    public private(set) var beats: RemoteBeatStatistics?
    public init() {}

    public mutating func apply(_ event: RemoteHealthEvent, now: Date = Date()) {
        switch event {
        case .status(let status):
            self.status = status
            if status != .noDataOrDenied { heartRate = nil; sdnn = nil; beats = nil }
        case .heartRate(let value, let date):
            guard value.isFinite, value > 0, Self.isRecent(date, now: now) else { return }
            if date >= (heartRate?.date ?? .distantPast) { heartRate = RemoteHealthValue(value: value, date: date) }
        case .sdnn(let value, let date):
            guard value.isFinite, value >= 0, Self.isRecent(date, now: now) else { return }
            if date >= (sdnn?.date ?? .distantPast) { sdnn = RemoteHealthValue(value: value, date: date) }
        case .beatIntervals(let values, let date):
            guard Self.isRecent(date, now: now), date >= (beats?.date ?? .distantPast),
                  let statistics = RemoteBeatStatistics(intervals: values, date: date) else { return }
            beats = statistics
        case .invalidated(let metric):
            switch metric {
            case .heartRate: heartRate = nil
            case .sdnn: sdnn = nil
            case .beatIntervals: beats = nil
            }
        }
    }

    public mutating func expire(at now: Date = Date()) {
        if let value = heartRate, !Self.isRecent(value.date, now: now) { heartRate = nil }
        if let value = sdnn, !Self.isRecent(value.date, now: now) { sdnn = nil }
        if let value = beats, !Self.isRecent(value.date, now: now) { beats = nil }
    }

    public var hasReadings: Bool { heartRate != nil || sdnn != nil || beats != nil }
    public var message: String { hasReadings ? "Recent Health readings · measured" : status.message }
    private static func isRecent(_ date: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(date)
        return age.isFinite && age >= -5 && age <= 120
    }
}
