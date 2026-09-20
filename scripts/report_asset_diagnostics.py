#!/usr/bin/env python3
"""Surface asset-catalog diagnostics from xcodebuild logs. Stdlib only.

WHY THIS EXISTS

The standard for the icon set is zero errors, zero warnings and zero notices
from actool. That standard was unmeasurable: the diagnostics step ran only
`if: failure()`, and even then it extracted `issues.errorSummaries` and
nothing else. On a successful build actool's notices and warnings were
discarded unread, so a green tick said nothing about the bar.

actool IS already invoked with `--notices --warnings` (verified in run
35496653633) -- the flags were right, the output was thrown away.

REPORTING ONLY, DELIBERATELY

This prints and counts; it never fails the build. Deciding what count is
acceptable is a separate argument, and the number should exist before the
policy does. Exit status is always 0 unless the logs themselves are missing,
which would mean the capture silently stopped working.

FORMAT

actool emits one diagnostic per line, as:

    <catalog path>:<item ref>: notice: <message>
    <catalog path>: warning: <message>

so the severity keyword after a colon is the anchor, and the line must
mention an asset catalog to be ours rather than a Swift warning.
"""
from __future__ import annotations

import os
import pathlib
import re
import sys

SEVERITIES = ("error", "warning", "notice")
# A diagnostic line that concerns an asset catalog, an icon set, or actool itself.
ASSET_MARKERS = (".xcassets", ".appiconset", ".imageset", ".colorset", "actool",
                 "CompileAssetCatalog", "AssetCatalog")
LINE = re.compile(r"^(?P<where>.*?):\s*(?P<severity>error|warning|notice):\s*(?P<message>.*)$")


def extract(text: str) -> list[tuple[str, str, str]]:
    found = []
    for raw in text.splitlines():
        line = raw.strip()
        if not any(marker in line for marker in ASSET_MARKERS):
            continue
        # Skip the actool invocation line itself: it names the tool but is a
        # command, not a diagnostic.
        if "/usr/bin/actool " in line and " --compile " in line:
            continue
        match = LINE.match(line)
        if not match:
            continue
        found.append((match.group("severity"), match.group("where").strip(),
                      match.group("message").strip()))
    return found


def main(argv: list[str]) -> int:
    logs = [pathlib.Path(p) for p in argv[1:]]
    if not logs:
        print("usage: report_asset_diagnostics.py <build log> [...]")
        return 2
    missing = [p for p in logs if not p.is_file()]
    if missing:
        # The capture stopped working. That is worth failing on: a report over
        # a log that does not exist is the vacuous-guard shape again.
        for p in missing:
            print(f"FAIL: build log not captured: {p}")
        return 1

    everything: list[tuple[str, str, str]] = []
    for path in logs:
        everything += extract(path.read_text(encoding="utf-8", errors="replace"))

    counts = {s: sum(1 for sev, _, _ in everything if sev == s) for s in SEVERITIES}
    unique = sorted({(sev, msg) for sev, _, msg in everything})

    banner = (f"actool diagnostics — {counts['error']} error(s), "
              f"{counts['warning']} warning(s), {counts['notice']} notice(s)")
    print("=" * len(banner))
    print(banner)
    print("=" * len(banner))
    if not everything:
        print("clean: no asset-catalog diagnostics in the captured logs")
    for severity, message in unique:
        n = sum(1 for s, _, m in everything if (s, m) == (severity, message))
        print(f"  {severity.upper():7} x{n}  {message}")

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as handle:
            handle.write(f"### {banner}\n\n")
            if not everything:
                handle.write("No asset-catalog diagnostics.\n")
            for severity, message in unique:
                handle.write(f"- **{severity}** — {message}\n")

    # Reporting only. No ceiling is enforced here on purpose.
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
