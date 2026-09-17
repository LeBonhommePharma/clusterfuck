# iOS / iPadOS overrides — ClusterFuck remote

MASTER.md clinical palette (`#0284C7` / `#16A34A` / `#DC2626`) is required. iPhone/iPad chrome uses **adaptive** surfaces: light MASTER background `#F0F9FF` in light mode, watch HUD navy `#0F0F23` in dark mode.

**Design dials:** Variance 3 · Motion 3 · Density 8

## Layout

- Phone: same four-page remote as watch, larger type, 44pt buttons, safe-area padding.
- iPad (regular width): `NavigationSplitView` — sidebar lists pages, detail shows the σ_irr HUD plus the selected actuator page.
- Loading: disable Minimize / dose / voice buttons while `isBusy`.
- Do not introduce yoga pose flow or quota remaining rings.

## Tokens

Views read `ClusterFuckTheme` only — no raw hex in `RemoteSessionView`.
