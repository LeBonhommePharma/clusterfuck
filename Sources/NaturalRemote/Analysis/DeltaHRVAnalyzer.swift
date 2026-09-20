import Foundation
import BonhommeCore

/// Explicit windowed ΔHRV (ΔRMSSD / ΔSDNN) canary for the remote control loop.
public final class DeltaHRVAnalyzer: @unchecked Sendable {
    public static let shared = DeltaHRVAnalyzer()

    private let lock = NSLock()
    private var rmssdSeries: [(Date, Double)] = []
    private var sdnnSeries: [(Date, Double)] = []
    private var lastDeltaRMSSD: Double = 0
    private var lastDeltaSDNN: Double = 0
    private let windowSeconds: TimeInterval
    private let entropyCalc: EntropyCalculator

    public init(windowSeconds: TimeInterval = 120, binCount: Int = 32) {
        self.windowSeconds = windowSeconds
        self.entropyCalc = EntropyCalculator(binCount: binCount)
    }

    public struct DeltaHRVResult: Sendable, Equatable {
        public var deltaRMSSD: Double
        public var deltaSDNN: Double
        public var sci: Double
        public var sampleCount: Int
        public var timestamp: Date

        public init(deltaRMSSD: Double, deltaSDNN: Double, sci: Double, sampleCount: Int, timestamp: Date = Date()) {
            self.deltaRMSSD = deltaRMSSD
            self.deltaSDNN = deltaSDNN
            self.sci = sci
            self.sampleCount = sampleCount
            self.timestamp = timestamp
        }
    }

    /// Ingest an HRV observation (HealthKit / AirPods Pro HR path).
    @discardableResult
    public func ingest(rmssd: Double, sdnn: Double, rrIntervals: [Double] = [], at date: Date = Date()) -> DeltaHRVResult {
        lock.lock()
        rmssdSeries.append((date, rmssd))
        sdnnSeries.append((date, sdnn))
        let cutoff = date.addingTimeInterval(-windowSeconds)
        rmssdSeries = rmssdSeries.filter { $0.0 >= cutoff }
        sdnnSeries = sdnnSeries.filter { $0.0 >= cutoff }

        let values = rmssdSeries.map(\.1)
        let half = max(1, values.count / 2)
        let first = Array(values.prefix(half))
        let second = Array(values.suffix(values.count - half))
        let meanFirst = first.isEmpty ? rmssd : first.reduce(0, +) / Double(first.count)
        let meanSecond = second.isEmpty ? rmssd : second.reduce(0, +) / Double(second.count)
        lastDeltaRMSSD = meanSecond - meanFirst

        // ΔSDNN mirrors ΔRMSSD: windowed first-half vs second-half mean of the SDNN series.
        let sdnnValues = sdnnSeries.map(\.1)
        let sdnnHalf = max(1, sdnnValues.count / 2)
        let sdnnFirst = Array(sdnnValues.prefix(sdnnHalf))
        let sdnnSecond = Array(sdnnValues.suffix(sdnnValues.count - sdnnHalf))
        let meanSDNNFirst = sdnnFirst.isEmpty ? sdnn : sdnnFirst.reduce(0, +) / Double(sdnnFirst.count)
        let meanSDNNSecond = sdnnSecond.isEmpty ? sdnn : sdnnSecond.reduce(0, +) / Double(sdnnSecond.count)
        lastDeltaSDNN = meanSDNNSecond - meanSDNNFirst

        let entropySource = rrIntervals.count >= 4 ? rrIntervals : values
        let entropy = entropyCalc.shannonEntropy(entropySource)
        let sci = entropyCalc.entropyToScore(entropy)
        let result = DeltaHRVResult(
            deltaRMSSD: lastDeltaRMSSD,
            deltaSDNN: lastDeltaSDNN,
            sci: sci,
            sampleCount: values.count,
            timestamp: date
        )
        lock.unlock()
        return result
    }

    public func latestDeltaRMSSD() -> Double {
        return lock.withLock { lastDeltaRMSSD }
    }

    public func latestDeltaSDNN() -> Double {
        return lock.withLock { lastDeltaSDNN }
    }

    public func reset() {
        lock.withLock {
        rmssdSeries.removeAll()
        sdnnSeries.removeAll()
        lastDeltaRMSSD = 0
        lastDeltaSDNN = 0
        }
    }

    /// Self-test path using synthetic coherent then noisy RR series.
    public static func runTest() -> DeltaHRVResult {
        let analyzer = DeltaHRVAnalyzer(windowSeconds: 600)
        let base = Date()
        for i in 0..<20 {
            let rr = (0..<32).map { _ in 800.0 + Double.random(in: -5...5) }
            _ = analyzer.ingest(rmssd: 40, sdnn: 50, rrIntervals: rr, at: base.addingTimeInterval(Double(i)))
        }
        for i in 20..<40 {
            let rr = (0..<32).map { _ in 800.0 + Double.random(in: -80...80) }
            _ = analyzer.ingest(rmssd: 70 + Double(i - 20), sdnn: 80, rrIntervals: rr, at: base.addingTimeInterval(Double(i)))
        }
        return analyzer.ingest(rmssd: 90, sdnn: 85, rrIntervals: (0..<32).map { _ in 800 + Double.random(in: -100...100) })
    }
}
