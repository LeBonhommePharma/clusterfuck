# macOS overrides — ClusterFuck control window

MASTER brand override (mint / violet / ink). Follows system light/dark — not locked dark, not Exergy gold gauges.

Because the window tracks the system appearance, the light ground is a shipping
surface, not a fallback. `ClusterFuckAdaptiveColor` swaps each key colour for
its light-ground variant (same hue and chroma, lower lightness) via the
`NSColor` dynamic provider; light background is `#F4F6FB`, card `#FFFFFF`,
foreground `#1E293B`, muted `#5A6478`.

**Design dials:** Variance 3 · Motion 3 · Density 7

## Layout

- `NavigationSplitView` with the four remote pages. Sidebar rows 44pt.
- Minimum window 420×560 (existing). Keyboard: default button = Minimize σ when session is live.
- App sandbox + outgoing network (Spotify / Alexa / Sonos / DI.fm). No iOS `LSRequiresIPhoneOS` keys.

## Icon

Mac App Store icon is the concentric Crooks gauge (1024 RGB opaque PNG). Same family as iOS/watch.
