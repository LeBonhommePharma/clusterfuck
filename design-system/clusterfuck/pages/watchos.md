# watchOS overrides — ClusterFuck wrist HUD

MASTER.md stays the clinical source of truth. This page **overrides** chrome for the watch remote: dense Crooks σ_irr HUD, not a yoga tracker and not a quota meter.

**Design dials:** Variance 3 · Motion 2 · Density 9

## Color (dark HUD)

| Role | Hex | Token |
|------|-----|--------|
| Background | `#0F0F23` | `ClusterFuckPalette.darkBackground` |
| Surface | `#1E1B4B` | `ClusterFuckPalette.darkSurface` |
| Ink | `#F8FAFC` | `ClusterFuckPalette.darkInk` |
| Primary ring | `#0284C7` | MASTER primary (unchanged) |
| Secondary ring | `#0891B2` | MASTER secondary |
| Closure / calm | `#16A34A` | MASTER accent |
| Elevated σ_irr | `#F97316` | watch CTA |
| Destructive | `#DC2626` | MASTER destructive |

## Layout

- One primary control: **σ_irr ring + closure %**. SCI ring from BonhommeCore sits under it.
- Vertical page `TabView` (existing four pages: sigma, music, dose, environment).
- Hit targets ≥ 44pt. SF Symbols outline only (`waveform.path.ecg`, `speaker.wave.2`, `pills`, `airpods.pro`). No emoji.
- Session Start/Stop and Minimize σ are the only primary actions on page 0.
- Respect `accessibilityReduceMotion` — no decorative spin.

## Copy

Wrist labels stay short: `σ_irr`, `Closure`, phase `fwd`/`rev`. Accessibility labels spell out “irreversible entropy production” and phase.
