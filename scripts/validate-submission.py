#!/usr/bin/env python3
"""Offline App Store configuration checks for ClusterFuck / NATURaL Remote."""
from __future__ import annotations

import json
import pathlib
import struct
import plistlib
from pbxproj import load_project
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
            expected = int(entry["size"].split("x")[0]) * int(entry.get("scale", "1x")[:-1])
            require((width, height) == (expected, expected), f"{entry['filename']} must match {expected}px catalog slot")
            require(depth == 8 and color == 2, platform + " icon must be RGB")
            require(b"tRNS" not in data, platform + " icon must be opaque")
            seen = True
    require(seen, platform + " catalog missing platform entry")


def check_privacy(path: pathlib.Path) -> None:
    data = plistlib.loads(path.read_bytes())
    require(data.get("NSPrivacyTracking") is False, str(path) + " tracking must be false")
    require(isinstance(data.get("NSPrivacyCollectedDataTypes"), list), str(path) + " collected types")
    require(isinstance(data.get("NSPrivacyAccessedAPITypes"), list), str(path) + " accessed APIs")


def check_project(path: pathlib.Path) -> None:
    data = load_project(path)
    objects = data["objects"]
    targets = {v["name"]: v for v in objects.values() if v.get("isa") == "PBXNativeTarget"}
    project = objects[data["rootObject"]]
    project_configs = objects[project["buildConfigurationList"]]["buildConfigurations"]
    for config in project_configs:
        settings = objects[config]["buildSettings"]
        require(settings.get("DEVELOPMENT_TEAM") == "ZJLX84G8QV", str(path) + " release team")
        require(settings.get("SWIFT_VERSION") in ("5", "5.0", "6", "6.0"), str(path) + " supported Swift language mode")
    for name, target in targets.items():
        for config in objects[target["buildConfigurationList"]]["buildConfigurations"]:
            settings = objects[config]["buildSettings"]
            require(settings.get("ASSETCATALOG_COMPILER_APPICON_NAME") == "AppIcon", name + " app icon selection")
            info = plistlib.loads((ROOT / settings["INFOPLIST_FILE"]).read_bytes())
            require(info["CFBundleVersion"] == "$(CURRENT_PROJECT_VERSION)", name + " build version")
            require(info["CFBundleShortVersionString"] == "$(MARKETING_VERSION)", name + " marketing version")
        resources = [objects[f]["fileRef"] for phase in target["buildPhases"]
                     if objects[phase]["isa"] == "PBXResourcesBuildPhase" for f in objects[phase]["files"]]
        names = {objects[f].get("path") for f in resources}
        require("Assets.xcassets" in names and "PrivacyInfo.xcprivacy" in names, name + " bundled assets/privacy")
    for phone, watch, bundle in (("ClusterFuck", "ClusterFuckWatch", "com.lebonhommepharma.clusterfuck"),
                                 ("BonhommeRemotePhone", "BonhommeRemoteWatch", "com.natural.BonhommeRemote")):
        require(phone in targets and watch in targets, str(path) + " app/watch targets")
        product = targets[watch]["productReference"]
        embedded = any(objects[f].get("fileRef") == product
                       for phase in targets[phone]["buildPhases"] if objects[phase]["isa"] == "PBXCopyFilesBuildPhase"
                       for f in objects[phase]["files"])
        require(embedded, phone + " must embed companion watch app")
        info = plistlib.loads((ROOT / "Apps" / watch / "Info.plist").read_bytes())
        require(info.get("WKCompanionAppBundleIdentifier") == bundle, watch + " companion identifier")


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
    for project in ("ClusterFuck", "BonhommeRemote"):
        check_project(ROOT / (project + ".xcodeproj") / "project.pbxproj")
    print("OK ClusterFuck source/configuration contracts; signed archives and device validation remain required")


if __name__ == "__main__":
    sys.exit(main() or 0)
