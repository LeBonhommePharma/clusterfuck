import Foundation

/// Pure Crooks / entropy production mathematics.
///
/// σ_irr ≈ ⟨W_fwd⟩ + ⟨W_rev⟩ − 2ΔG  (non-negative lower bound enforced)
///
/// Work increments are formed from multi-scale remote signals so the same
/// formula can be unit-tested without I/O.
public enum CrooksMath: Sendable {
    /// Instantaneous work contribution from a multi-signal state sample.
    ///
    /// Weights are dimensionless and fixed for reproducibility across tests.
    public static func instantaneousWork(from state: RemoteMultiSignalState) -> Double {
        let bpmTerm = (state.musicBPM - 120.0) * 0.02
        let hrvTerm = state.deltaHRV * 0.4
        let flexTerm = state.flexAIDDeltaS * 0.3
        let audioTerm = state.audioEntropyBits * 0.15
        let alexaTerm = state.alexaEntropyHint * 0.1
        let ancTerm = state.airPodsANCEngaged ? -0.05 : 0.08
        let convoTerm = state.conversationAwarenessActive ? 0.12 : 0.0
        let sciTerm = (0.5 - state.sci) * 0.25
        return hrvTerm + flexTerm + bpmTerm + audioTerm + alexaTerm + ancTerm + convoTerm + sciTerm
    }

    /// Irreversible entropy production with thermodynamic lower bound at 0.
    public static func sigmaIrr(workFwd: Double, workRev: Double, deltaG: Double) -> Double {
        let raw = workFwd + workRev - 2.0 * deltaG
        guard raw.isFinite else { return .infinity }
        return max(0.0, raw)
    }

    /// Closure percentage: 100% when σ_irr ≈ 0, decaying as σ_irr grows.
    /// Uses exponential map so small residuals still show nuance.
    public static func closurePercent(sigmaIrr: Double, scale: Double = 0.25) -> Double {
        guard sigmaIrr.isFinite, sigmaIrr >= 0, scale > 0 else { return 0 }
        let c = exp(-sigmaIrr / scale) * 100.0
        return min(100.0, max(0.0, c))
    }

    /// Accumulated work after adding a sample in the given phase.
    public static func accumulateWork(
        phase: CrooksCyclePhase,
        workFwd: Double,
        workRev: Double,
        sampleWork: Double
    ) -> (workFwd: Double, workRev: Double) {
        switch phase {
        case .forward:
            return (workFwd + sampleWork, workRev)
        case .reverse:
            return (workFwd, workRev + sampleWork)
        }
    }

    /// Whether the controller should flip phase (near closure and cadence).
    public static func shouldFlipPhase(
        sigmaIrr: Double,
        cycleCount: Int,
        sigmaThreshold: Double = 0.03,
        cycleModulo: Int = 3
    ) -> Bool {
        guard cycleModulo > 0 else { return false }
        return sigmaIrr < sigmaThreshold && cycleCount % cycleModulo == 0
    }

    /// Whether minimization actuators should fire.
    public static func shouldMinimize(sigmaIrr: Double, threshold: Double = 0.15) -> Bool {
        sigmaIrr.isFinite && sigmaIrr > threshold
    }

    /// Tempo target (BPM) that reduces perceptual work in reverse phase.
    public static func targetBPM(phase: CrooksCyclePhase, currentBPM: Double, sigmaIrr: Double) -> Double {
        switch phase {
        case .forward:
            // Mild exploration: allow slightly higher tempo, capped.
            return min(148.0, max(100.0, currentBPM + min(8.0, sigmaIrr * 10.0)))
        case .reverse:
            // Grounding: pull toward 80–100 BPM as σ_irr rises.
            let pull = 90.0 - min(15.0, sigmaIrr * 20.0)
            return min(currentBPM, max(72.0, pull))
        }
    }
}
