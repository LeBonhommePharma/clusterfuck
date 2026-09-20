import SwiftUI

/// Crooks σ_irr / closure gauge. Not a yoga SCI duplicate and not a quota remaining ring:
/// fill is **closure percent** (100% when σ_irr ≈ 0).
///
/// Hierarchy is deliberate: σ_irr is the one number the app exists to show, so
/// it is the only element at `metric` size. The band chip, closure readout and
/// last action step down from it. State is carried by colour **and** shape
/// **and** text — never hue alone.
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

    private var band: ClusterFuckSigmaBand { ClusterFuckSigmaBand.classify(sigmaIrr) }
    private var known: Bool { sigmaIrr.isFinite && closurePercent.isFinite }
    private var frac: Double { known ? min(1, max(0, closurePercent / 100.0)) : 0 }
    private var ringSize: CGFloat { compact ? 96 : 148 }
    private var stroke: CGFloat { compact ? 7 : 11 }

    public var body: some View {
        VStack(spacing: compact ? ClusterFuckSpacing.sm : ClusterFuckSpacing.md) {
            gauge
            bandChip
            supporting
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? ClusterFuckSpacing.md : ClusterFuckSpacing.lg)
        .background(Color.clusterFuckSurface, in: RoundedRectangle(cornerRadius: ClusterFuckRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ClusterFuckRadius.md, style: .continuous)
                .strokeBorder(Color.clusterFuckBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(band: band))
    }

    private var gauge: some View {
        ZStack {
            // Dashed when there is no reading, so "unknown" cannot be mistaken
            // for "zero" — a solid empty ring reads as a real measurement of 0.
            Circle()
                .stroke(
                    Color.clusterFuckBorder,
                    style: StrokeStyle(
                        lineWidth: stroke,
                        dash: known ? [] : [stroke * 0.9, stroke * 1.1]
                    )
                )
            if known, frac > 0 {
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(band.color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(ClusterFuckMotion.animation(reduceMotion: reduceMotion), value: frac)
                    // The band can change without the fill moving much; without
                    // this the colour snaps at 0ms.
                    .animation(ClusterFuckMotion.animation(reduceMotion: reduceMotion), value: band)
            }
            VStack(spacing: ClusterFuckSpacing.xxs) {
                Text(known ? String(format: "%.3f", sigmaIrr) : "—")
                    .font(compact ? ClusterFuckType.metricCompact : ClusterFuckType.metric)
                    .foregroundStyle(Color.clusterFuckInk)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("σ_irr")
                    .font(ClusterFuckType.micro)
                    .foregroundStyle(Color.clusterFuckMute)
            }
            .padding(.horizontal, stroke * 2)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityHidden(true)
    }

    /// Colour + shape + text. Any one of the three carries the state on its own.
    private var bandChip: some View {
        Label(band.label, systemImage: band.symbol)
            .font(ClusterFuckType.label)
            .foregroundStyle(band.color)
            .symbolRenderingMode(.monochrome)
            .imageScale(.small)
            .padding(.horizontal, ClusterFuckSpacing.sm)
            .padding(.vertical, ClusterFuckSpacing.xs)
            .background(band.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(band.color.opacity(0.35), lineWidth: 1))
            .animation(ClusterFuckMotion.animation(reduceMotion: reduceMotion), value: band)
            .accessibilityHidden(true)
    }

    private var supporting: some View {
        VStack(spacing: ClusterFuckSpacing.withinGroup) {
            Text(known ? String(format: "Closure %.0f%% · %@", closurePercent, phase.rawValue) : "Closure —")
                .font(ClusterFuckType.caption)
                .foregroundStyle(Color.clusterFuckInk)
                .monospacedDigit()
            Text(humanize(lastAction))
                .font(ClusterFuckType.micro)
                .foregroundStyle(Color.clusterFuckMute)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .accessibilityHidden(true)
    }

    private func accessibilityText(band: ClusterFuckSigmaBand) -> String {
        let sigma = sigmaIrr.isFinite ? String(format: "%.3f", sigmaIrr) : "unavailable"
        let closure = sigmaIrr.isFinite && closurePercent.isFinite
            ? String(format: "%.0f percent", min(100, max(0, closurePercent))) : "unavailable"
        return "Irreversible entropy production \(sigma), closure \(closure), phase \(phase.rawValue), band \(band.rawValue), last action \(humanize(lastAction))"
    }

    private func humanize(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
    }
}
