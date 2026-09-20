#!/usr/bin/env python3
"""Reject off-palette pixels in shipped raster assets. Stdlib only (CI installs nothing).

Why a *per-asset* palette and not the system palette:

    The whole v2 palette, taken together, has a convex hull wide enough to
    contain colours that are not in it. #C4A359 -- the brass that reached two
    other repos -- sits INSIDE the hull of the eight canonical colours plus
    the grounds, because a desaturated tangerine is a legitimate convex
    combination of tangerine and near-white. A system-wide hull check would
    have passed the exact bug it exists to prevent. Measured: brass is 20.8
    units inside that hull, and 148.9 units outside the three colours the
    ClusterFuck icon actually declares.

So each asset declares the small set of colours it is drawn from, and every
pixel must lie within TOLERANCE of the convex hull of just those.

Any anti-aliased or partially-transparent blend of declared colours is a
convex combination and so lies in the hull exactly; the only error is 8-bit
quantisation. Measured worst case over 2- and 3-colour blends: 0.739 units.
TOLERANCE is 1.5 -- 2x the quantisation noise, 99x below the brass.
"""
from __future__ import annotations

import pathlib
import struct
import sys
import zlib
from itertools import combinations

ROOT = pathlib.Path(__file__).resolve().parents[1]
TOLERANCE = 1.5


def _hex(value: str) -> tuple[int, int, int]:
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


# Every colour here must be canonical v2 or a hue-and-chroma-preserving relight
# of one. Derived from canonical is fine; invented is not.
INK, AQUA, MINT = _hex("08091A"), _hex("00A2FF"), _hex("45E0A8")
LIGHT_BG, AQUA_LIGHT, MINT_LIGHT = _hex("F4F6FB"), _hex("0074B7"), _hex("157F59")

# path -> the colours that asset is drawn from.
GOVERNED: dict[str, list[tuple[int, int, int]]] = {}


def decode_rgb(path: pathlib.Path) -> tuple[int, int, list[tuple[int, int, int]]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path} is not a PNG")
    pos, idat, width, height, depth, ctype = 8, b"", 0, 0, 0, 0
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        pos += 8
        chunk = data[pos:pos + length]
        pos += length + 4
        if kind == b"IHDR":
            width, height, depth, ctype = struct.unpack(">IIBB", chunk[:10])
        elif kind == b"IDAT":
            idat += chunk
        elif kind == b"IEND":
            break
    if depth != 8 or ctype not in (2, 6):
        raise ValueError(f"{path}: expected 8-bit RGB or RGBA, got depth={depth} colour={ctype}")
    bpp = 3 if ctype == 2 else 4
    raw = zlib.decompress(idat)
    stride = width * bpp
    out, prev, i = bytearray(), bytearray(stride), 0
    for _ in range(height):
        filt = raw[i]
        i += 1
        line = bytearray(raw[i:i + stride])
        i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if filt == 1:
                line[x] = (line[x] + a) & 0xFF
            elif filt == 2:
                line[x] = (line[x] + b) & 0xFF
            elif filt == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 0xFF
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xFF
        out += line
        prev = line
    return width, height, [(out[j], out[j + 1], out[j + 2]) for j in range(0, len(out), bpp)]


def _project(point, verts):
    n = len(verts)
    if n == 1:
        return list(verts[0]), [1.0]
    base = verts[0]
    basis = [[verts[j][i] - base[i] for j in range(1, n)] for i in range(3)]
    m = n - 1
    mat = [[sum(basis[r][i] * basis[r][j] for r in range(3)) for j in range(m)] for i in range(m)]
    rhs = [sum(basis[r][i] * (point[r] - base[r]) for r in range(3)) for i in range(m)]
    aug = [mat[i][:] + [rhs[i]] for i in range(m)]
    for col in range(m):
        piv = max(range(col, m), key=lambda r: abs(aug[r][col]))
        if abs(aug[piv][col]) < 1e-12:
            return None, None
        aug[col], aug[piv] = aug[piv], aug[col]
        for r in range(m):
            if r == col:
                continue
            f = aug[r][col] / aug[col][col]
            for k in range(col, m + 1):
                aug[r][k] -= f * aug[col][k]
    t = [aug[i][m] / aug[i][i] for i in range(m)]
    pt = [base[i] + sum(t[j] * basis[i][j] for j in range(m)) for i in range(3)]
    return pt, [1 - sum(t)] + list(t)


def distance_to_palette(point, palette) -> float:
    """Exact euclidean distance to conv(palette): the nearest point lies on some face."""
    best = float("inf")
    for size in range(1, min(4, len(palette)) + 1):
        for subset in combinations(palette, size):
            pt, weights = _project(point, subset)
            if pt is None or any(w < -1e-9 for w in weights):
                continue
            best = min(best, sum((point[i] - pt[i]) ** 2 for i in range(3)) ** 0.5)
    return best


def audit(path: pathlib.Path, palette) -> list[str]:
    _, _, pixels = decode_rgb(path)
    counts: dict[tuple[int, int, int], int] = {}
    for px in pixels:
        counts[px] = counts.get(px, 0) + 1
    offenders = []
    for colour, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        if distance_to_palette(colour, palette) > TOLERANCE:
            offenders.append((n, colour, distance_to_palette(colour, palette)))
    total = len(pixels)
    try:
        label = path.relative_to(ROOT)
    except ValueError:
        label = path.name  # fixtures in a temp dir during the self-test
    return [
        f"{label}: #{c[0]:02X}{c[1]:02X}{c[2]:02X} is {d:.1f} units "
        f"off-palette ({n * 100 / total:.2f}% of pixels)"
        for n, c, d in offenders[:6]
    ]


def main() -> int:
    fails: list[str] = []
    if not GOVERNED:
        # A guard that governs nothing passes vacuously. Say so rather than exit 0.
        print("SKIP check_icon_palette: no assets governed yet "
              "(wire ClusterFuck's icons in with the icon set)")
        return 0
    for rel, palette in GOVERNED.items():
        path = ROOT / rel
        if not path.is_file():
            fails.append(f"governed asset missing: {rel}")
            continue
        fails.extend(audit(path, palette))
    for line in fails:
        print("FAIL:", line)
    if not fails:
        print(f"OK icon palette ({len(GOVERNED)} assets)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
