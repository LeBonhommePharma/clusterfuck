import SwiftUI

/// Crooks σ_irr / closure gauge. Not a yoga SCI duplicate and not a quota remaining ring:
/// fill is **closure percent** (100% when σ_irr ≈ 0).
public struct SigmaHUDView: View {
    public var sigmaIrr: Double
    public var closurePercent: Double
    public var phase: CrooksCyclePhase
    public var lastAction: String
    public var compact: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        sigmaIrr: Double,
        closurePercent: Double,
        phase: CrooksCyclePhase,
        lastAction: String,
        compact: Bool = false
    ) {
        self.sigmaIrr = sigmaIrr
        self.closurePercent = closurePercent
        self.phase = phase
        self.lastAction = lastAction
        self.compact = compact
    }

    public var body: some View {
        let band = ClusterFuckSigmaBand.classify(sigmaIrr)
        let frac = min(1, max(0, closurePercent / 100.0))
        VStack(spacing: compact ? ClusterFuckSpacing.xs : ClusterFuckSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color.clusterFuckBorder.opacity(0.45), lineWidth: compact ? 6 : 10)
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(band.color, style: StrokeStyle(lineWidth: compact ? 6 : 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(ClusterFuckMotion.animation(reduceMotion: reduceMotion), value: frac)
                VStack(spacing: 2) {
                    Text(sigmaIrr.isFinite ? String(format: "%.3f", sigmaIrr) : "—")
                        .font(compact ? ClusterFuckType.caption.monospacedDigit() : ClusterFuckType.mono)
                        .foregroundStyle(Color.clusterFuckInk)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text("σ_irr")
                        .font(.caption2)
                        .foregroundStyle(Color.clusterFuckMute)
                }
            }
            .frame(width: compact ? 88 : 132, height: compact ? 88 : 132)
            .accessibilityHidden(true)

            Text(String(format: "Closure %.0f%% · %@", closurePercent, phase.rawValue))
                .font(ClusterFuckType.caption)
                .foregroundStyle(Color.clusterFuckMute)
                .monospacedDigit()
            Text(humanize(lastAction))
                .font(.caption2)
                .foregroundStyle(Color.clusterFuckMute)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? ClusterFuckSpacing.sm : ClusterFuckSpacing.md)
        .background(Color.clusterFuckSurface, in: RoundedRectangle(cornerRadius: ClusterFuckRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ClusterFuckRadius.md, style: .continuous)
                .strokeBorder(Color.clusterFuckBorder.opacity(0.6), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(band: band))
    }

    private func accessibilityText(band: ClusterFuckSigmaBand) -> String {
        let sigma = sigmaIrr.isFinite ? String(format: "%.3f", sigmaIrr) : "unavailable"
        return "Irreversible entropy production \(sigma), closure \(Int(closurePercent.rounded())) percent, phase \(phase.rawValue), band \(band.rawValue), last action \(humanize(lastAction))"
    }

    private func humanize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
    }
}
