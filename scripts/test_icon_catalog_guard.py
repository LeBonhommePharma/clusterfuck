"""Correctness fixture for check_icon_catalog. Stdlib only.

Hermetic: its own miniature appiconsets in a temp directory, with verdicts
known by construction. Nothing here touches the repo's catalogs.
"""
from __future__ import annotations

import contextlib
import io
import json
import pathlib
import struct
import sys
import tempfile
import zlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_icon_catalog as guard  # noqa: E402

FAILS: list[str] = []


def png(path: pathlib.Path, size: int = 8) -> None:
    raw = b"".join(b"\x00" + bytes([8, 9, 26] * size) for _ in range(size))
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF))
    path.write_bytes(b"\x89PNG\r\n\x1a\n"
                     + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def build(base: pathlib.Path, declared: list[str], files: list[str]) -> None:
    base.mkdir(parents=True, exist_ok=True)
    (base / "Contents.json").write_text(json.dumps({
        "images": [{"filename": f, "idiom": "universal", "size": "1024x1024"} for f in declared],
        "info": {"author": "xcode", "version": 1},
    }))
    for f in files:
        png(base / f)


def run(root: pathlib.Path, rel: str) -> list[str]:
    old_root = guard.ROOT
    guard.ROOT = root
    try:
        return guard.audit(rel)
    finally:
        guard.ROOT = old_root


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)

        # clean: declarations and files agree exactly
        build(root / "clean.appiconset", ["a.png", "b.png"], ["a.png", "b.png"])
        if run(root, "clean.appiconset"):
            FAILS.append(f"clean catalog reported problems: {run(root, 'clean.appiconset')}")

        # the probe case: a file nobody declared
        build(root / "extra.appiconset", ["a.png"], ["a.png", "stowaway.png"])
        out = run(root, "extra.appiconset")
        if not out:
            FAILS.append("an undeclared file was not detected — this is the actool probe case")
        elif "stowaway.png" not in out[0]:
            FAILS.append(f"detected the wrong file: {out[0]}")

        # the inverse: a declaration with no file
        build(root / "missing.appiconset", ["a.png", "ghost.png"], ["a.png"])
        out = run(root, "missing.appiconset")
        if not any("ghost.png" in o for o in out):
            FAILS.append("a declaration with no file on disk was not detected")

        # an empty manifest must fail rather than pass vacuously
        build(root / "empty.appiconset", [], [])
        if not run(root, "empty.appiconset"):
            FAILS.append("a catalog declaring nothing was reported as clean")

        # a missing catalog must fail
        if not run(root, "absent.appiconset"):
            FAILS.append("a missing catalog was reported as clean")

    # the guard must refuse to run against an empty catalog list
    # Swallow the guard's own stdout: this sub-test is SUPPOSED to make it
    # print "FAIL: no catalogs configured", and a fixture that prints FAIL on
    # a passing run teaches people to skim its output.
    saved = guard.CATALOGS
    try:
        guard.CATALOGS = ()
        with contextlib.redirect_stdout(io.StringIO()) as sink:
            rc = guard.main()
        if rc == 0:
            FAILS.append("guard passed with no catalogs configured — vacuous")
        elif "vacuous" not in sink.getvalue():
            FAILS.append("empty-catalog refusal did not say why")
    finally:
        guard.CATALOGS = saved

    for line in FAILS:
        print("FAIL:", line)
    if not FAILS:
        print("OK icon catalog guard self-test (5 catalog shapes + the vacuous case)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
