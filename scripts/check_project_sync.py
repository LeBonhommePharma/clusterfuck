#!/usr/bin/env python3
"""Assert the committed .xcodeproj files still describe project.yml. Stdlib only.

WHY

Both .xcodeproj bundles are committed and no generator runs anywhere — not in
CI, not in a Makefile. xcodegen is never invoked, so project.yml is an input
nothing consumes, and the .pbxproj gets hand-edited directly (98c9ed0 changed
the Swift language mode in it). Nothing asserted the two still agreed. That
is a slow leak: the yml can describe one project while the shipped one builds
another, and the first symptom is a signing or deployment surprise at
submission.

SCOPE — deliberately not full equivalence

Four dimensions only: target names, bundle identifiers, code-sign
entitlements paths, and deployment targets. A full structural comparison
would have to be maintained against every xcodegen and Xcode format change,
and a check nobody can maintain gets deleted. These four are the ones whose
drift actually reaches the App Store.

MATCHING — anchored and counted, never substring

Every comparison below is exact-string or set equality, and the target counts
are asserted. This is not incidental. The same class of check in a sibling
repo matched a bundle id by substring, so the widget's identifier
(com.x.app.watchkitapp) satisfied the assertion meant for the main app's
(com.x.app) — deleting the main app's identifier outright still passed,
because the longer string contained the shorter one. Presence tests over
identifiers that share a prefix are worthless by construction.

WHEN THE TWO LEGITIMATELY DIFFER

Today they do not: all five targets agree on all four dimensions across both
project files. So the policy is strict equality, decided now rather than
discovered later.

If a divergence is ever CORRECT — say a target that exists only in one
project file — record it in ACCEPTED_DIVERGENCE below with the reason. Do not
relax a comparison, and do not add an ignore marker. Loosening the check to
accommodate one legitimate case silently accommodates every illegitimate one
that follows, which is how the substring checks this repo spent today
removing came to exist.
"""
from __future__ import annotations

import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pbxproj import load_project  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = "project.yml"
PROJECTS = ("ClusterFuck.xcodeproj/project.pbxproj", "BonhommeRemote.xcodeproj/project.pbxproj")

# (project, target, field) -> why this difference is correct. Empty on purpose.
ACCEPTED_DIVERGENCE: dict[tuple[str, str, str], str] = {}

PLATFORM_SDK = {"iOS": "iphoneos", "watchOS": "watchos", "macOS": "macosx", "tvOS": "appletvos"}
PLATFORM_DEPLOY = {
    "iOS": "IPHONEOS_DEPLOYMENT_TARGET",
    "watchOS": "WATCHOS_DEPLOYMENT_TARGET",
    "macOS": "MACOSX_DEPLOYMENT_TARGET",
}


def _block(text: str, key: str) -> str:
    """The lines under a column-0 `key:`, up to the next column-0 key."""
    lines = text.splitlines()
    try:
        start = next(i for i, l in enumerate(lines) if l == f"{key}:")
    except StopIteration:
        return ""
    out = []
    for line in lines[start + 1:]:
        if line and not line[0].isspace():
            break
        out.append(line)
    return "\n".join(out)


def spec_targets(text: str) -> dict[str, dict[str, str]]:
    """Anchored scan of the `targets:` block. Two-space keys start a target."""
    block = _block(text, "targets")
    targets: dict[str, dict[str, str]] = {}
    current = None
    for line in block.splitlines():
        head = re.match(r"^  ([A-Za-z][\w]*):\s*$", line)
        if head:
            current = head.group(1)
            targets[current] = {}
            continue
        if current is None:
            continue
        for field in ("platform", "PRODUCT_BUNDLE_IDENTIFIER", "CODE_SIGN_ENTITLEMENTS"):
            hit = re.match(rf"^\s+{re.escape(field)}:\s*(\S.*?)\s*$", line)
            if hit:
                targets[current][field] = hit.group(1).strip().strip('"')
    return targets


def spec_deployment(text: str) -> dict[str, str]:
    block = _block(text, "options") + "\n" + text
    out = {}
    for platform in PLATFORM_DEPLOY:
        hit = re.search(rf"^\s+{platform}:\s*\"?([\d.]+)\"?\s*$", text, re.M)
        if hit:
            out[platform] = hit.group(1)
    return out


def project_targets(path: pathlib.Path) -> tuple[dict[str, dict[str, str]], dict[str, str]]:
    data = load_project(path)
    objects = data["objects"]
    out: dict[str, dict[str, str]] = {}
    for value in objects.values():
        if value.get("isa") != "PBXNativeTarget":
            continue
        settings: dict[str, str] = {}
        config_list = objects[value["buildConfigurationList"]]
        for cfg_id in config_list["buildConfigurations"]:
            cfg = objects[cfg_id]
            if cfg["name"] != "Release":
                continue
            settings = cfg["buildSettings"]
        out[value["name"]] = settings
    project = objects[data["rootObject"]]
    project_settings: dict[str, str] = {}
    for cfg_id in objects[project["buildConfigurationList"]]["buildConfigurations"]:
        cfg = objects[cfg_id]
        if cfg["name"] == "Release":
            project_settings = cfg["buildSettings"]
    return out, project_settings


def main() -> int:
    fails: list[str] = []
    spec_text = (ROOT / SPEC).read_text(encoding="utf-8")
    declared = spec_targets(spec_text)
    deploy = spec_deployment(spec_text)

    if not declared:
        print(f"FAIL: parsed zero targets out of {SPEC}; the comparison would be vacuous")
        return 1
    if not deploy:
        print(f"FAIL: parsed no deploymentTarget out of {SPEC}")
        return 1

    for rel in PROJECTS:
        path = ROOT / rel
        if not path.is_file():
            fails.append(f"{rel} missing; nothing to compare against {SPEC}")
            continue
        built, project_settings = project_targets(path)

        # Set equality, and count, not membership.
        if set(built) != set(declared):
            only_spec = sorted(set(declared) - set(built))
            only_proj = sorted(set(built) - set(declared))
            fails.append(
                f"{rel}: target sets differ — only in {SPEC}: {only_spec or 'none'}; "
                f"only in project: {only_proj or 'none'}")
        if len(built) != len(declared):
            fails.append(f"{rel}: {len(built)} targets, {SPEC} declares {len(declared)}")

        for name in sorted(set(built) & set(declared)):
            want, got = declared[name], built[name]
            for field in ("PRODUCT_BUNDLE_IDENTIFIER", "CODE_SIGN_ENTITLEMENTS"):
                if (rel, name, field) in ACCEPTED_DIVERGENCE:
                    continue
                expected, actual = want.get(field), got.get(field)
                # A MISSING declaration is a failure, not a skip. Treating it
                # as "nothing to compare" reproduces the sibling-repo bug in a
                # new shape: delete a bundle id from the spec and the check
                # goes quiet, because absence and agreement look identical.
                # Verified — before this branch existed, removing
                # ClusterFuck's identifier from project.yml passed cleanly.
                if expected is None:
                    fails.append(
                        f"{rel}: {name} declares no {field} in {SPEC}; every target must "
                        f"declare one, or record the exception in ACCEPTED_DIVERGENCE")
                    continue
                if actual is None:
                    fails.append(f"{rel}: {name} has no {field} at all, {SPEC} says {expected!r}")
                elif actual != expected:   # exact, never `in`
                    fails.append(f"{rel}: {name}.{field} is {actual!r}, {SPEC} says {expected!r}")
            platform = want.get("platform")
            if platform is None and (rel, name, "platform") not in ACCEPTED_DIVERGENCE:
                fails.append(f"{rel}: {name} declares no platform in {SPEC}")
            if platform and (rel, name, "SDKROOT") not in ACCEPTED_DIVERGENCE:
                sdk = PLATFORM_SDK.get(platform)
                if sdk and got.get("SDKROOT") != sdk:
                    fails.append(
                        f"{rel}: {name} SDKROOT is {got.get('SDKROOT')!r}, "
                        f"{SPEC} platform {platform} implies {sdk!r}")

        for platform, version in deploy.items():
            key = PLATFORM_DEPLOY[platform]
            if (rel, "<project>", key) in ACCEPTED_DIVERGENCE:
                continue
            actual = project_settings.get(key)
            if actual is not None and actual != version:
                fails.append(f"{rel}: {key} is {actual!r}, {SPEC} says {version!r}")

    for line in fails:
        print("FAIL:", line)
    if not fails:
        print(f"OK project sync ({len(declared)} targets x {len(PROJECTS)} project files: "
              f"names, bundle ids, entitlements, SDK, deployment targets)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
