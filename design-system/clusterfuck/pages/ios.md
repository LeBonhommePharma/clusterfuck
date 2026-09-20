# iOS / iPadOS overrides — ClusterFuck remote

MASTER **brand override** (mint / violet / ink) is required. Do not ship the generated clinical sky `#0284C7` / `#F0F9FF`.

**Design dials:** Variance 3 · Motion 3 · Density 8

## Layout

- Phone: `TabView` with **four labeled tabs** (σ_irr / Music / DrugKit / Environment). Hits 44pt.
- iPad (regular width): `NavigationSplitView` — sidebar lists pages, detail shows the σ_irr HUD plus the selected actuator page.
- Loading: disable Minimize / dose / voice buttons while `isBusy`.
- Do not introduce yoga pose flow or quota remaining rings.
- Unknown SCI is `—` (nil), never a fake 0.5.

## Tokens

Views read `ClusterFuckTheme` only — no raw hex in `RemoteSessionView`.

iOS follows the system appearance, so **both** grounds ship. Key colours resolve
to their light-ground variant in light mode (`Color.clusterFuckAccent` →
`#157F59`, `clusterFuckPrimary` → `#7E4AF5`, `clusterFuckSecondary` →
`#0074B7`, `clusterFuckWarning` → `#DB0068`). Never render a dark-ground key
colour on the light card — mint is 1.68:1 on white.
