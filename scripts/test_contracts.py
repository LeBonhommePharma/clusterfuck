#!/usr/bin/env python3
"""Linux-runnable contracts for ClusterFuck / NATURaL Remote."""
from __future__ import annotations

import json
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FAILS: list[str] = []


def fail(msg: str) -> None:
    FAILS.append(msg)


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_design_system() -> None:
    master = ROOT / "design-system/clusterfuck/MASTER.md"
    if not master.is_file():
        fail("design-system/clusterfuck/MASTER.md missing")
        return
    text = master.read_text(encoding="utf-8")
    for needle in ("#45E0A8", "#8B5CF6", "#08091A", "Brand override"):
        if needle not in text:
            fail(f"MASTER.md missing {needle}")
    if "| Primary | `#0284C7`" in text:
        fail("MASTER primary table must not ship clinical blue as source of truth")
    for page in ("watchos", "ios", "macos"):
        if not (ROOT / f"design-system/clusterfuck/pages/{page}.md").is_file():
            fail(f"missing page override {page}.md")
    theme = read("Sources/NaturalRemote/Theme/ClusterFuckTheme.swift")
    for needle in ("0x45E0A8", "0x8B5CF6", "0x08091A", "accessibilityReduceMotion", "waveform.path.ecg"):
        if needle not in theme:
            fail(f"ClusterFuckTheme missing {needle}")
    if "0x0284C7" in theme:
        fail("ClusterFuckTheme must not ship the generated clinical blue")
    remote = read("Sources/NaturalRemote/Session/RemoteSessionView.swift")
    if ".tabItem" not in remote:
        fail("phone TabView must keep labeled tab items")
    hud = read("Sources/NaturalRemote/Session/SigmaHUDView.swift")
    if '"—"' not in hud:
        fail("σ_irr HUD must render em-dash for non-finite values")
    if '"Closure —"' not in hud:
        fail("unknown σ_irr must not invent Closure 0%")
    if "if known" not in hud:
        fail("σ_irr ring trim must omit fill when the value is unknown")
    if "if known, frac > 0" not in hud:
        fail("σ_irr ring must omit fill at 0% closure")
    if "if known {" in hud:
        fail("σ_irr ring must not stroke a 0% round-cap stub")
    if "case .unknown" not in theme:
        fail("unknown σ_irr must map to a mute band, not elevated")
    vm = read("Sources/NaturalRemote/Session/RemoteSessionView.swift")
    if "sigmaIrr: Double = .nan" not in vm:
        fail("idle ViewModel must start σ_irr as non-finite, never 0")
    if 'BPM — · H_audio —' not in vm:
        fail("idle music HUD must not invent BPM 120 / H_audio 0")
    if "doseEvidence.displayValue(pcci)" not in vm or "physiologicalEvidence.displayValue(deltaHRV)" not in vm:
        fail("DrugKit HUD must gate each metric on its own source evidence")
    if "Text(model.musicMetricsLabel)" not in vm or "Text(model.doseMetricsLabel)" not in vm:
        fail("HUD must render provenance-aware metric labels")
    if "sigmaIrr: model.displaySigma" not in vm or "score: model.displaySCI" not in vm:
        fail("rings must not display raw kernel defaults")
    if 'Alexa lights: —' not in vm:
        fail("idle environment HUD must not invent Alexa lights 60%")
    if 'Text("Alexa lights: \\(model.alexaLights)%")' in vm:
        fail("environment HUD must not always interpolate Alexa lights")
    if "alexaLightsLabel" not in vm:
        fail("environment HUD must fail closed through alexaLightsLabel")
    if '?? "unknown"' in vm:
        fail("SCI VoiceOver must not format NaN via map")
    if "sciAccessibilityLabel" not in vm:
        fail("SCI VoiceOver must fail closed through sciAccessibilityLabel")
    if "score.isFinite" not in vm:
        fail("SCI VoiceOver must treat non-finite SCI as unavailable")
    if "ClusterFuckPressStyle" not in theme:
        fail("Remote buttons must use ClusterFuckPressStyle (Reduce Motion aware)")
    if "ClusterFuckLoadingRow" not in theme:
        fail("busy state must use ClusterFuckLoadingRow, not a frozen HUD")
    root = read("Apps/Shared/ClusterFuckRootView.swift")
    if "preferredColorScheme(.dark)" in root:
        fail("Remote must follow system light/dark, not lock dark")


def test_feature_vector_no_observed_delta() -> None:
    src = read("Sources/NaturalRemote/Analysis/DeltaHRVFlexAIDMapper.swift")
    match = re.search(r"public var vector: \[Double\] \{(.+?)\n    \}", src, re.S)
    if not match:
        fail("DeltaHRVFlexAIDFeatures.vector missing")
        return
    body = match.group(1)
    if "observedDelta" in body:
        fail("feature vector must not include observed ΔHRV (label leakage)")
    if "flexAIDDeltaS" not in body:
        fail("feature vector must include flexAIDDeltaS")
    mapper = read("Sources/NaturalRemote/Analysis/DeltaHRVFlexAIDMapper.swift")
    if "func configurationalDeltaS(freeAngles" not in mapper:
        fail("mapper must expose configurationalDeltaS (not a flexAIDDeltaS method that collides in tests)")
    tests = read("Tests/NaturalRemoteTests/DeltaHRVFlexAIDTests.swift")
    if "import BonhommeCore" in tests:
        fail("DeltaHRVFlexAIDTests must not import BonhommeCore (actor DeltaHRVFlexAIDMapper name clash)")
    if "NaturalRemote.DeltaHRVFlexAIDMapper" not in tests:
        fail("FlexAID tests must module-qualify NaturalRemote.DeltaHRVFlexAIDMapper")


def test_control_honesty() -> None:
    loop = read("Sources/NaturalRemote/Session/RemoteControlLoop.swift")
    if "self.drugKit = DrugKitEngine.shared" in loop:
        fail("RemoteControlLoop must not share DrugKitEngine.shared")
    if "DrugKitEngine()" not in loop:
        fail("RemoteControlLoop must construct its own DrugKitEngine")
    crooks = read("Sources/NaturalRemote/Core/CrooksCycleController.swift")
    if "deltaG: Double = 0.05" not in crooks:
        fail("default ΔG must remain 0.05")
    if "try? await bus.execute" in crooks:
        fail("minimizeSigma must not swallow actuator results with try?")
    if ":unregistered" not in crooks:
        fail("lastActionSummary must record unregistered actuators")
    apply = read("Sources/NaturalRemote/Actuators/ResearchKitBridge.swift")
    if "state.physiologicalSCI" not in apply:
        fail("ResearchKit apply must blend from physiologicalSCI")
    voice = read("Sources/NaturalRemote/Actuators/AlexaAndFoundation.swift")
    if 'lowered.contains("up")' in voice:
        fail("voice parser must not match substring 'up'")
    http = read("Sources/NaturalRemote/Core/RemoteHTTPHonesty.swift")
    if "requireSuccess" not in http:
        fail("RemoteHTTPHonesty.requireSuccess missing")
    phone = read("Apps/BonhommeRemotePhone/App/PhoneConnectivityBridge.swift")
    if 'context["tokens"] = tokens' in phone:
        fail("WC application context must not carry OAuth tokens")
    session = read("Sources/NaturalRemote/Session/HealthKitRemoteSource.swift")
    if "canRequestReadAuthorization" not in session:
        fail("HealthKit request must be gated (NSInvalidArgumentException without usage description)")
    if "requestAuthorization" in session and "canRequestReadAuthorization()" not in session:
        fail("requestAuthorization must sit behind canRequestReadAuthorization()")


def test_privacy_and_watch_plist() -> None:
    for rel in (
        "Apps/ClusterFuck/PrivacyInfo.xcprivacy",
        "Apps/ClusterFuckWatch/PrivacyInfo.xcprivacy",
        "Apps/BonhommeRemotePhone/PrivacyInfo.xcprivacy",
        "Apps/BonhommeRemoteWatch/PrivacyInfo.xcprivacy",
    ):
        text = read(rel)
        if "NSPrivacyTracking" not in text:
            fail(f"{rel} missing tracking key")
        if "<false/>" not in text:
            fail(f"{rel} must set NSPrivacyTracking false")
        if "NSPrivacyCollectedDataTypes" not in text:
            fail(f"{rel} missing collected types")
    watch = read("Apps/BonhommeRemoteWatch/Info.plist")
    if "<key>WKApplication</key>\n\t<true/>" not in watch.replace("\r", ""):
        if "<key>WKApplication</key>\n    <true/>" not in watch:
            fail("BonhommeRemoteWatch WKApplication must be boolean true")
    mac_plist = read("Apps/ClusterFuck/MacInfo.plist")
    if "LSRequiresIPhoneOS" in mac_plist:
        fail("Mac Info.plist must not require iPhone OS")
    mac_ent = read("Apps/ClusterFuck/ClusterFuckMac.entitlements")
    if "com.apple.security.app-sandbox" not in mac_ent:
        fail("Mac entitlements must sandbox")


def _png_rgb_1024(path: pathlib.Path, platform: str) -> None:
    if not path.is_file():
        fail(f"{platform} icon missing: {path}")
        return
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"{platform} icon is not PNG")
        return
    width, height, depth, color = struct.unpack(">IIBB", data[16:26])
    if (width, height) != (1024, 1024):
        fail(f"{platform} icon {width}x{height}, need 1024")
    if depth != 8 or color != 2:
        fail(f"{platform} icon must be 8-bit RGB (got depth={depth} color={color})")
    if b"tRNS" in data:
        fail(f"{platform} icon must be opaque (no tRNS)")


def test_icons() -> None:
    _png_rgb_1024(
        ROOT / "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        "ios",
    )
    _png_rgb_1024(
        ROOT / "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset/AppIcon-Mac-1024.png",
        "macos",
    )
    _png_rgb_1024(
        ROOT / "Apps/ClusterFuckWatch/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
        "watchos",
    )
    ios_json = json.loads(
        (ROOT / "Apps/ClusterFuck/Assets.xcassets/AppIcon.appiconset/Contents.json").read_text()
    )
    platforms = {img.get("platform") for img in ios_json["images"] if "platform" in img}
    if "ios" not in platforms:
        fail("ClusterFuck AppIcon must declare ios platform")
    watch_json = json.loads(
        (ROOT / "Apps/ClusterFuckWatch/Assets.xcassets/AppIcon.appiconset/Contents.json").read_text()
    )
    if watch_json["images"][0].get("platform") != "watchos":
        fail("watch AppIcon platform must be watchos")


def test_no_invented_tvos_app() -> None:
    if (ROOT / "Apps/ClusterFuckTV").exists():
        fail("do not invent a tvOS app host")


def main() -> int:
    test_design_system()
    test_feature_vector_no_observed_delta()
    test_control_honesty()
    test_privacy_and_watch_plist()
    test_icons()
    test_no_invented_tvos_app()
    if FAILS:
        for item in FAILS:
            print("FAIL:", item)
        return 1
    print("OK ClusterFuck contracts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
