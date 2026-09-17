#!/usr/bin/env python3
"""Offline App Store configuration checks for ClusterFuck / NATURaL Remote."""
from __future__ import annotations

import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def require(cond: bool, message: str) -> None:
    if not cond:
        raise SystemExit("FAIL: " + message)


def check_icon(path: pathlib.Path, platform: str) -> None:
    catalog = json.loads((path / "Contents.json").read_text())
    require(len(catalog["images"]) >= 1, platform + " icon entries")
    seen = False
    for entry in catalog["images"]:
        if entry.get("platform") == platform or (
            platform == "macos" and entry.get("idiom") == "mac"
        ):
            data = (path / entry["filename"]).read_bytes()
            require(data[:8] == b"\x89PNG\r\n\x1a\n", platform + " icon must be PNG")
            width, height, depth, color = struct.unpack(">IIBB", data[16:26])
            require((width, height) == (1024, 1024), platform + " icon must be 1024")
            require(depth == 8 and color == 2, platform + " icon must be RGB")
            require(b"tRNS" not in data, platform + " icon must be opaque")
            seen = True
            break
    require(seen, platform + " catalog missing platform entry")


def check_privacy(path: pathlib.Path) -> None:
    text = path.read_text()
    require("NSPrivacyTracking" in text, str(path) + " tracking key")
    require("<false/>" in text, str(path) + " tracking false")
    require("NSPrivacyCollectedDataTypes" in text, str(path) + " collected types")


def main() -> None:
    check_icon(ROOT / "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset", "ios")
    check_icon(ROOT / "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset", "macos")
    check_icon(ROOT / "Apps/ClusterFuckWatch/Assets.xcassets/AppIcon.appiconset", "watchos")
    check_icon(ROOT / "Apps/BonhommeRemotePhone/Assets.xcassets/AppIcon.appiconset", "ios")
    check_icon(ROOT / "Apps/BonhommeRemoteWatch/Assets.xcassets/AppIcon.appiconset", "watchos")
    for rel in (
        "Apps/ClusterFuck/PrivacyInfo.xcprivacy",
        "Apps/ClusterFuckWatch/PrivacyInfo.xcprivacy",
        "Apps/BonhommeRemotePhone/PrivacyInfo.xcprivacy",
        "Apps/BonhommeRemoteWatch/PrivacyInfo.xcprivacy",
    ):
        check_privacy(ROOT / rel)
    yml = (ROOT / "project.yml").read_text()
    require("com.lebonhommepharma.clusterfuck" in yml, "ClusterFuck bundle id")
    require("com.lebonhommepharma.clusterfuck.watchkitapp" in yml, "watch bundle id")
    require("com.lebonhommepharma.clusterfuck.mac" in yml, "mac bundle id")
    require("ITSAppUsesNonExemptEncryption" in (ROOT / "Apps/ClusterFuck/Info.plist").read_text(), "export compliance")
    mac = (ROOT / "Apps/ClusterFuck/ClusterFuckMac.entitlements").read_text()
    require("com.apple.security.app-sandbox" in mac, "Mac sandbox")
    watch_plist = (ROOT / "Apps/BonhommeRemoteWatch/Info.plist").read_text()
    require("<key>WKApplication</key>" in watch_plist and "<true/>" in watch_plist, "WKApplication boolean")
    require("LSRequiresIPhoneOS" not in (ROOT / "Apps/ClusterFuck/MacInfo.plist").read_text(), "Mac not iPhone")
    print("OK ClusterFuck submission contracts")


if __name__ == "__main__":
    sys.exit(main() or 0)
