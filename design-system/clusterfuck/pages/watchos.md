# watchOS overrides — ClusterFuck wrist HUD

MASTER brand override (mint closure / violet σ_irr / `#08091A` ink). Dense Crooks HUD, not a yoga tracker and not a quota meter.

**Design dials:** Variance 3 · Motion 2 · Density 9

## Color (dark HUD)

| Role | Hex | Token |
|------|-----|--------|
| Background | `#08091A` | `ClusterFuckPalette.darkBackground` |
| Surface | `#111226` | `ClusterFuckPalette.darkSurface` |
| Ink | `#E4E3F5` | `ClusterFuckPalette.darkInk` |
| σ_irr ring | `#8B5CF6` | violet ΔS |
| Closure / calm | `#45E0A8` | mint ΔH |
| Elevated σ_irr | `#FF2F92` | strawberry |
| Destructive | `#F5232B` | firetruck |

## Layout

- One primary control: **σ_irr ring + closure %**. SCI ring from BonhommeCore sits under it.
- Vertical page `TabView` (four pages: sigma, music, dose, environment).
- Hit targets ≥ 44pt. SF Symbols outline only. No emoji.
- Unknown σ_irr → `—`. Reduce Motion pauses trim.
