#!/usr/bin/env python3
"""Self-test for check_icon_palette. Stdlib only.

The guard governs no assets until ClusterFuck's icons land, so without this it
would pass vacuously. These fixtures give it something it must get right now.
"""
from __future__ import annotations

import pathlib
import struct
import sys
import tempfile
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from check_icon_palette import (  # noqa: E402
    AQUA, AQUA_LIGHT, INK, LIGHT_BG, MINT, MINT_LIGHT, TOLERANCE,
    audit, distance_to_palette,
)

ROOT = pathlib.Path(__file__).resolve().parents[1]
FAILS: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)


def write_png(path: pathlib.Path, rows: list[list[tuple[int, int, int]]]) -> None:
    h, w = len(rows), len(rows[0])
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def blend(a, b, t):
    return tuple(round(a[i] * (1 - t) + b[i] * t) for i in range(3))


def main() -> int:
    dark = [INK, AQUA, MINT]
    light = [LIGHT_BG, AQUA_LIGHT, MINT_LIGHT]

    # 1. Anti-aliased blends of declared colours must pass. Only 8-bit
    #    quantisation separates them from the hull.
    worst = 0.0
    for pair in ((INK, AQUA), (INK, MINT), (AQUA, MINT)):
        for i in range(101):
            worst = max(worst, distance_to_palette(blend(*pair, i / 100), dark))
    if worst > TOLERANCE:
        fail(f"legitimate AA blend measured {worst:.3f}, above tolerance {TOLERANCE}")
    if worst > TOLERANCE / 1.5:
        fail(f"AA headroom too thin: worst blend {worst:.3f} vs tolerance {TOLERANCE}")

    # 2. The brass must be rejected on both grounds. This is the regression
    #    that reached two other repos; a system-wide hull check accepts it.
    brass = (0xC4, 0xA3, 0x59)
    for name, palette in (("dark", dark), ("light", light)):
        d = distance_to_palette(brass, palette)
        if d <= TOLERANCE:
            fail(f"#C4A359 accepted against the {name} palette at distance {d:.2f}")

    # 3. Retired v1 colours must be rejected.
    for hexv in ("FBBF24", "22D3EE", "C2456F", "6E7C99", "8B1A4A", "FF2600"):
        colour = (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16))
        if distance_to_palette(colour, dark) <= TOLERANCE:
            fail(f"retired #{hexv} accepted against the dark palette")

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = pathlib.Path(tmp)

        # 4. A clean fixture drawn only from declared colours must produce no findings.
        clean = tmpdir / "clean.png"
        write_png(clean, [[blend(INK, AQUA, x / 31) for x in range(32)] for _ in range(32)])
        if audit(clean, dark):
            fail(f"clean fixture reported offenders: {audit(clean, dark)[:1]}")

        # 5. One brass pixel in 1024 must be caught.
        dirty = tmpdir / "dirty.png"
        rows = [[INK for _ in range(32)] for _ in range(32)]
        rows[16][16] = brass
        write_png(dirty, rows)
        found = audit(dirty, dark)
        if not found:
            fail("a single #C4A359 pixel was not detected")
        elif "C4A359" not in found[0]:
            fail(f"detected the wrong colour: {found[0]}")

    for line in FAILS:
        print("FAIL:", line)
    if not FAILS:
        print(f"OK icon palette guard self-test (AA headroom {worst:.3f} / tol {TOLERANCE})")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
