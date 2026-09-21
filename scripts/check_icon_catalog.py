"""Every file in an appiconset is declared, and every declaration resolves.

WHY THIS AND NOT validate-submission's check_icon

`check_icon` walks the entries in Contents.json and validates the file each
one names — dimensions, PNG-ness, colour type, opacity. It therefore cannot
see a file that no entry names. That is exactly the case actool caught when
an unreferenced PNG was dropped into the watch appiconset as a probe on
2026-09-20: both release gates stayed green and only actool objected, with

    warning: The app icon set "AppIcon" has an unassigned child.

Catching that should not require a macOS runner. This is the complement:
declaration -> file (already covered, re-checked here cheaply) and
file -> declaration (the gap).

Stdlib only; CI installs nothing.
"""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

# Appiconsets this repo is responsible for. BonhommeRemotePhone and
# BonhommeRemoteWatch are deliberately absent: they belong to
# BonhommeRemote.xcodeproj, a different product, and must not be changed
# under a ClusterFuck brief. That is an explicit exclusion, not an oversight.
CATALOGS = (
    "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset",
    "Apps/ClusterFuckWatch/Assets.xcassets/AppIcon.appiconset",
)


def audit(rel: str) -> list[str]:
    base = ROOT / rel
    if not base.is_dir():
        return [f"{rel} is missing"]
    manifest = base / "Contents.json"
    if not manifest.is_file():
        return [f"{rel}/Contents.json is missing"]
    try:
        images = json.loads(manifest.read_text())["images"]
    except Exception as exc:  # noqa: BLE001
        return [f"{rel}/Contents.json is unreadable: {exc}"]

    declared = {i["filename"] for i in images if i.get("filename")}
    on_disk = {p.name for p in base.iterdir() if p.suffix.lower() == ".png"}

    problems = []
    for name in sorted(on_disk - declared):
        problems.append(
            f"{rel}/{name} is present but no Contents.json entry names it — "
            f"actool reports this as an unassigned child")
    for name in sorted(declared - on_disk):
        problems.append(f"{rel}/Contents.json names {name}, which is not on disk")
    if not declared:
        problems.append(f"{rel}/Contents.json declares no filenames at all")
    return problems


def main() -> int:
    if not CATALOGS:
        print("FAIL: no catalogs configured; this guard would pass vacuously")
        return 1
    problems: list[str] = []
    for rel in CATALOGS:
        problems += audit(rel)
    for line in problems:
        print("FAIL:", line)
    if not problems:
        print(f"OK icon catalogs ({len(CATALOGS)} appiconsets: every file declared, "
              f"every declaration resolved)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
