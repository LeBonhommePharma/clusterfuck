"""Minimal 8-bit RGB PNG writer. Stdlib only.

Pairs with the stdlib PNG reader in check_icon_palette, so the file the
renderer writes and the file CI inspects go through code in this repo rather
than through an image library CI does not have.

Opaque RGB with no tRNS on purpose: App Store icons must be opaque, and
validate-submission enforces exactly that.
"""
from __future__ import annotations

import pathlib
import struct
import zlib


def write_rgb_png(path: pathlib.Path, rows: list[bytes], width: int, height: int) -> None:
    for i, row in enumerate(rows):
        if len(row) != width * 3:
            raise ValueError(f"row {i} is {len(row)} bytes, expected {width * 3}")
    if len(rows) != height:
        raise ValueError(f"{len(rows)} rows, expected {height}")

    raw = b"".join(b"\x00" + row for row in rows)   # filter type 0 per scanline

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
