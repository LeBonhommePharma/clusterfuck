"""Render the ClusterFuck app icons. Requires numpy; run by hand, not in CI.

CI validates the committed PNGs with stdlib only (check_icon_palette,
check_icon_catalog, validate-submission). This is the only piece that needs
a third-party package, and it is deliberately not on the CI path.

WHY ANALYTIC AND NOT SVG

Every pixel here is a convex combination of the declared colours BY
CONSTRUCTION, so the palette guard verifies rather than discovers. Rendering
the same artwork through an SVG rasteriser (qlmanage) put 21% of the interior
off-palette — it composites onto a white canvas and offsets — and a guard
adversarial to its own renderer's output is worthless. Measured on this
renderer: 0 off-palette pixels, worst distance 0.829 against a tolerance of
1.5, which is pure 8-bit quantisation.

THE MARK — geometry C

"Coincidence": two acoustic sources, their expanding wavefronts, and the lens
where they agree. That is what audio sync physically is. Rotated 38° so the
upright form's eye / vesica-piscis read does not land, and scaled to fill the
tile. Below ARC_CUTOFF_PX the wavefronts are dropped and the bare lens
carries the mark — a lens inside concentric arcs is an iris inside lids, and
the rotation only fixes that at large sizes.

COLOUR — canonical v2 only, no new values
  dark   ground #08091A · aqua #00A2FF (ΔS_vib, vibration) · mint #45E0A8 (ΔH, closure)
  light  ground #F4F6FB · aqua #0074B7 · mint #157F59
The light pair are hue-and-chroma preserving relights already in the theme;
mint at #45E0A8 is 1.66:1 on the light ground and would be invisible.
"""
from __future__ import annotations

import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from icon_png import write_rgb_png  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]

INK        = np.array([0x08, 0x09, 0x1A], float)
AQUA       = np.array([0x00, 0xA2, 0xFF], float)
MINT       = np.array([0x45, 0xE0, 0xA8], float)
LIGHT_BG   = np.array([0xF4, 0xF6, 0xFB], float)
AQUA_LIGHT = np.array([0x00, 0x74, 0xB7], float)
MINT_LIGHT = np.array([0x15, 0x7F, 0x59], float)

S = 1024.0                      # design space
LX, RX, CY, R = 362.0, 662.0, 512.0, 300.0
FRONTS = [(300.0, 26.0, 1.00), (380.0, 20.0, 0.55), (460.0, 16.0, 0.28)]
ROTATE, SCALE = 38.0, 1.18      # geometry C
ARC_CUTOFF_PX = 32              # below this the arcs are dropped
SMALL_SCALE = 1.45              # the bare lens fills more of the tile


def render(px: int, light: bool = False) -> np.ndarray:
    ground = LIGHT_BG if light else INK
    wave   = AQUA_LIGHT if light else AQUA
    lens   = MINT_LIGHT if light else MINT
    arcs   = px >= ARC_CUTOFF_PX
    scale  = SCALE if arcs else SMALL_SCALE

    u = (np.arange(px) + 0.5) * (S / px)
    X, Y = np.meshgrid(u, u)
    aa = S / px * 0.8                      # one destination pixel, in design units

    cx = cy = S / 2
    x, y = (X - cx) / scale, (Y - cy) / scale
    t = np.radians(-ROTATE)
    xr = x * np.cos(t) - y * np.sin(t) + cx
    yr = x * np.sin(t) + y * np.cos(t) + cy

    img = np.broadcast_to(ground, (px, px, 3)).astype(float).copy()
    r1 = np.hypot(xr - LX, yr - CY)
    r2 = np.hypot(xr - RX, yr - CY)

    if arcs:
        for rad, width, alpha in FRONTS:
            for r, facing in ((r1, xr >= LX), (r2, xr <= RX)):
                cov = np.clip((width / 2 + aa - np.abs(r - rad)) / (2 * aa), 0, 1)
                img += (wave - img) * (cov * facing * alpha)[..., None]

    inside = np.clip(np.minimum((R + aa - r1) / (2 * aa), (R + aa - r2) / (2 * aa)), 0, 1)
    img += (lens - img) * inside[..., None]

    return np.clip(img + 0.5, 0, 255).astype(np.uint8)


def write(px: int, light: bool, path: pathlib.Path) -> None:
    a = render(px, light)
    write_rgb_png(path, [a[r].tobytes() for r in range(px)], px, px)


# (relative path, pixel size, light?) — one entry per distinct file on disk.
#
# WHICH TILE GOES IN WHICH SLOT — decided, not defaulted:
#
#   iOS default (no appearances key) -> the LIGHT tile. The default slot is
#     what iOS shows in light appearance, so the light-ground tile belongs
#     there. It is also the App Store marketing icon.
#   iOS dark appearance              -> the INK tile.
#   macOS and watchOS                -> the INK tile. Neither supports
#     appearance variants in an appiconset, so each gets one icon, and the
#     ink face is the brand's.
#
# That leaves iOS light-by-default while macOS and watchOS are always ink.
# Flagging it rather than hiding it: it is a consequence of only iOS having
# the mechanism, not an oversight. Flip the two iOS entries if the ink face
# should lead on the Store instead.
IOS = "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset"
WATCH = "Apps/ClusterFuckWatch/Assets.xcassets/AppIcon.appiconset"
TARGETS = [
    (f"{IOS}/AppIcon-1024.png", 1024, True),        # iOS default / App Store
    (f"{IOS}/AppIcon-Dark-1024.png", 1024, False),  # iOS dark appearance
    (f"{IOS}/AppIcon-Mac-16.png", 16, False),
    (f"{IOS}/AppIcon-Mac-32.png", 32, False),
    (f"{IOS}/AppIcon-Mac-64.png", 64, False),
    (f"{IOS}/AppIcon-Mac-128.png", 128, False),
    (f"{IOS}/AppIcon-Mac-256.png", 256, False),
    (f"{IOS}/AppIcon-Mac-512.png", 512, False),
    (f"{IOS}/AppIcon-Mac-1024.png", 1024, False),
    (f"{WATCH}/AppIcon-1024.png", 1024, False),
]


def main() -> int:
    for rel, px, light in TARGETS:
        write(px, light, ROOT / rel)
        print(f"  {px:>5}px  {'light' if light else 'dark '}  {rel}")
    print(f"rendered {len(TARGETS)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
