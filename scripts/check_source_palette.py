#!/usr/bin/env python3
"""Forbid colour literals outside the theme file. Stdlib only.

WHY

After a full pass on palette discipline, nothing guarded the code that
actually renders. Every view was clean — zero named SwiftUI colours, zero raw
hex outside ClusterFuckTheme.swift — and clean entirely by hand. A
`Color.red`, or a `ClusterFuckRGBA(hex: 0xC4A359)` dropped into any view,
passed every gate in the repo. That is "the guard that doesn't exist" aimed
at the most likely regression there is.

THE EXCLUSION BOUNDARY

ClusterFuckTheme.swift is the one file allowed to name colour values, and it
is allowed to name EXACTLY the values it declares — not "any hex", which
would make the theme a laundering route for an off-palette value. Its
literals are checked against the canonical v2 set plus hue-and-chroma
preserving relights of those, enumerated below.

There is deliberately NO ignore marker, no pragma, no allowlist comment. An
escape hatch a view can also use is not a boundary, it is a suggestion; the
first off-palette colour that needs to ship would simply carry the marker.
If a new value is genuinely needed, it goes in ALLOWED below, in a commit
that has to justify it.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
THEME = "Sources/NaturalRemote/Theme/ClusterFuckTheme.swift"
SEARCH_ROOTS = ("Sources", "Apps")

# Canonical FlexAID∆S v2, plus the relights and surfaces already landed.
# Derived from canonical is fine; invented is not.
ALLOWED_HEX = {
    "08091A", "E4E3F5", "45E0A8", "8B5CF6", "00A2FF", "FF2F92", "FF9300", "DCDCE4",
    "F4F6FB", "FFFFFF", "111226", "1E293B", "5A6478", "8D8CB0",
    "7E4AF5", "0074B7", "157F59", "A45F00", "DB0068", "6C6C8D",
    "F5232B", "FF6B6B", "BE123C",
}

# SwiftUI's built-in palette. None of these are ours, and several are
# explicitly retired names (green, teal, cyan, mint as a system colour).
SYSTEM_COLOURS = (
    "red", "orange", "yellow", "green", "mint", "teal", "cyan", "blue", "indigo",
    "purple", "pink", "brown", "white", "black", "gray", "grey",
)
NAMED = re.compile(r"\bColor\s*\.\s*(" + "|".join(SYSTEM_COLOURS) + r")\b")
HEX = re.compile(r"0x([0-9A-Fa-f]{6})\b")
# UIColor/NSColor constructed straight from components bypasses the tokens too.
COMPONENTS = re.compile(r"\b(?:UIColor|NSColor)\s*\(\s*(?:red|white|hue)\s*:")


def swift_files() -> list[pathlib.Path]:
    out: list[pathlib.Path] = []
    for top in SEARCH_ROOTS:
        base = ROOT / top
        if base.is_dir():
            out += [p for p in base.rglob("*.swift") if ".build" not in p.parts]
    return sorted(out)


def audit(path: pathlib.Path) -> list[str]:
    rel = path.relative_to(ROOT).as_posix()
    is_theme = rel == THEME
    findings = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code = line.split("//", 1)[0]
        for match in NAMED.finditer(code):
            findings.append(f"{rel}:{number}: Color.{match.group(1)} — use a ClusterFuck token")
        for match in COMPONENTS.finditer(code):
            if not is_theme:
                findings.append(f"{rel}:{number}: colour built from raw components — use a token")
        for match in HEX.finditer(code):
            value = match.group(1).upper()
            if not is_theme:
                findings.append(f"{rel}:{number}: raw hex 0x{value} outside the theme")
            elif value not in ALLOWED_HEX:
                findings.append(
                    f"{rel}:{number}: 0x{value} is not canonical v2 nor a declared relight — "
                    f"the theme may name only the values it is allowed to name")
    return findings


def main() -> int:
    files = swift_files()
    if not files:
        print("FAIL: no Swift sources found — the guard would pass vacuously")
        return 1
    if not (ROOT / THEME).is_file():
        print(f"FAIL: theme file missing at {THEME}; the exclusion boundary is undefined")
        return 1
    findings: list[str] = []
    for path in files:
        findings += audit(path)
    for line in findings:
        print("FAIL:", line)
    if not findings:
        print(f"OK source palette ({len(files)} Swift files, colour literals confined to the theme)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
