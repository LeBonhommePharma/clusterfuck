import Foundation
import BonhommeCore

/// PCCI / multi-signal collapse accelerator.
///
/// Metal path is optional; the Swift/Accelerate-equivalent path is always correct and is what
/// unit tests exercise. Naming mirrors the EigenMetalBridge design from the roadmap.
public final class EigenMetalBridge: @unchecked Sendable {
    public static let shared = EigenMetalBridge()

    private let entropyCalc: EntropyCalculator

    public init(binCount: Int = 32) {
        self.entropyCalc = EntropyCalculator(binCount: binCount)
    }

    /// Pharma-Control Coherence Index from a signal vector.
    ///
    /// vector layout: [HRV_norm, spotifyValence, alexaState, drugDelta, fmUncertainty, ...]
    /// Returns PCCI in [0, 1] where 1 = full collapse / high coherence.
    /// Normalized against the histogram entropy ceiling (log₂(binCount)), not the
    /// sample count, so PCCI reflects coherence rather than vector length.
    public func computePCCI(_ vector: [Double]) -> Double {
        let clean = vector.filter { $0.isFinite }
        guard clean.count >= 2 else {
            if let only = clean.first {
                return min(1, max(0, 1.0 - abs(only)))
            }
            return 0
        }
        let entropy = entropyCalc.shannonEntropy(clean)
        return entropyCalc.entropyToScore(entropy)
    }

    /// Batch collapse for streaming frames.
    public func metalBatchCollapse(_ signals: [[Double]]) -> [Double] {
        signals.map { computePCCI($0) }
    }

    /// Benchmark helper used in validation harness.
    public func benchmark(iterations: Int = 200) -> (pcci: Double, milliseconds: Double) {
        let vector = [0.8, 0.73, 0.4, 1.2, 0.9, 0.55, 0.61]
        let start = CFAbsoluteTimeGetCurrent()
        var last = 0.0
        for _ in 0..<iterations {
            last = computePCCI(vector)
        }
        let ms = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        return (last, ms)
    }
}

/// ANE / Core ML surrogate predictor with pure-Swift fallback weights.
public final class ANEPharmaPredictor: @unchecked Sendable {
    private let weights: [Double]
    private let bias: Double
    public private(set) var usedCoreML: Bool = false

    public init(weights: [Double] = [4.0, 0.02, -8.0, 0.01], bias: Double = 2.0) {
        self.weights = weights
        self.bias = bias
        // Attempt Core ML load if model present; failure is non-fatal.
        #if canImport(CoreML)
        if let url = Bundle.main.url(forResource: "DeltaHRV_FlexAID_Surrogate", withExtension: "mlmodelc") {
            // Model presence noted; prediction still uses explicit weights unless wired to MLModel.
            // Full MLModel bridging stays optional so tests remain deterministic.
            _ = url
            usedCoreML = false
        }
        #endif
    }

    public func predictDelta(features: [Double]) -> Double? {
        let n = min(features.count, weights.count)
        guard n > 0 else { return nil }
        var y = bias
        for i in 0..<n {
            y += weights[i] * features[i]
        }
        return y
    }
}
