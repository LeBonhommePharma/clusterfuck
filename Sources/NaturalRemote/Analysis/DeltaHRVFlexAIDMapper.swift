import Foundation
import BonhommeCore

/// Hybrid surrogate: maps observed ΔHRV + FlexAID-style ΔS_config features → predicted ΔHRV,
/// then deviation for grounding alerts.
///
/// Uses a pure-Swift linear model (ANE/CoreML-compatible feature layout). When a compiled
/// `.mlmodelc` named `DeltaHRV_FlexAID_Surrogate` is present in the bundle, `ANEPharmaPredictor`
/// can take over; this type always remains a correct, testable path.
public struct DeltaHRVFlexAIDFeatures: Sendable, Equatable {
    public var observedDeltaRMSSD: Double
    public var flexAIDDeltaS: Double
    public var doseMg: Double
    public var baselineSCI: Double
    public var substanceID: Int

    public init(
        observedDeltaRMSSD: Double,
        flexAIDDeltaS: Double,
        doseMg: Double,
        baselineSCI: Double,
        substanceID: Int
    ) {
        self.observedDeltaRMSSD = observedDeltaRMSSD
        self.flexAIDDeltaS = flexAIDDeltaS
        self.doseMg = doseMg
        self.baselineSCI = baselineSCI
        self.substanceID = substanceID
    }

    public var vector: [Double] {
        [
            observedDeltaRMSSD,
            flexAIDDeltaS,
            doseMg,
            baselineSCI,
            Double(substanceID % 100),
        ]
    }
}

public struct DeltaHRVFlexAIDPrediction: Sendable, Equatable {
    public var predictedDelta: Double
    public var deviation: Double
    public var action: String
    public var flexAIDDeltaS: Double

    public init(predictedDelta: Double, deviation: Double, action: String, flexAIDDeltaS: Double) {
        self.predictedDelta = predictedDelta
        self.deviation = deviation
        self.action = action
        self.flexAIDDeltaS = flexAIDDeltaS
    }

    public var isGroundingAlert: Bool { action == "grounding_alert" }
}

public final class DeltaHRVFlexAIDMapper: @unchecked Sendable {
    public static let shared = DeltaHRVFlexAIDMapper()

    /// Linear surrogate weights (trained-layout placeholder with physically motivated signs).
    /// predictedΔ ≈ w·x + b
    private let weights: [Double]
    private let bias: Double
    private let deviationThreshold: Double
    private let entropyCalc: EntropyCalculator
    private let predictor: ANEPharmaPredictor?

    public init(
        weights: [Double] = [0.55, 4.0, 0.02, -8.0, 0.01],
        bias: Double = 2.0,
        deviationThreshold: Double = 0.35,
        predictor: ANEPharmaPredictor? = nil
    ) {
        self.weights = weights
        self.bias = bias
        self.deviationThreshold = deviationThreshold
        self.entropyCalc = EntropyCalculator(binCount: 32)
        self.predictor = predictor
    }

    /// Predict from features; prefers ANE path when available and successful.
    public func predict(_ features: DeltaHRVFlexAIDFeatures) -> DeltaHRVFlexAIDPrediction {
        let predicted: Double
        if let predictor, let ane = predictor.predictDelta(features: features.vector) {
            predicted = ane
        } else {
            predicted = linearPredict(features.vector)
        }

        let denom = max(abs(predicted), 1e-6)
        let deviation = abs(features.observedDeltaRMSSD - predicted) / denom
        let action = deviation > deviationThreshold ? "grounding_alert" : "coherent_continue"
        return DeltaHRVFlexAIDPrediction(
            predictedDelta: predicted,
            deviation: deviation,
            action: action,
            flexAIDDeltaS: features.flexAIDDeltaS
        )
    }

    /// Convenience: estimate FlexAID-style ΔS from free vs bound angle samples using BonhommeCore.
    public func flexAIDDeltaS(freeAngles: [Double], boundAngles: [Double]) -> Double {
        let sFree = entropyCalc.circularShannonEntropy(freeAngles)
        let sBound = entropyCalc.circularShannonEntropy(boundAngles)
        return sBound - sFree
    }

    /// Convert ΔS bits to kcal/mol penalty via shared NATURaL thermodynamic constants.
    public func entropyPenaltyKcal(deltaSBits: Double) -> Double {
        ThermodynamicConstants.entropyPenaltyKcal(deltaSBits: deltaSBits)
    }

    private func linearPredict(_ x: [Double]) -> Double {
        let n = min(x.count, weights.count)
        var y = bias
        for i in 0..<n {
            y += weights[i] * x[i]
        }
        return y
    }
}
