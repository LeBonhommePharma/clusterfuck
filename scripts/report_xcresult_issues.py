#!/usr/bin/env python3
"""Print error, warning and analyzer summaries from an .xcresult. Stdlib only.

The previous inline version ran only `if: failure()` and read only
`errorSummaries`, so warnings never surfaced at all. This reads all three
summary kinds and runs on success too. Reporting only: exit 0 unless the
bundle exists and cannot be read, which would mean the capture is broken.

BASELINE, for whoever sets a warning policy
-------------------------------------------
Measured 2026-09-20, run 35499173864 (green, no probe):

    iOS target   errorSummaries 0    warningSummaries 110
    actool       0 errors, 0 warnings, 0 notices

110 is the number as it stood the day these reporters were switched on. It
is a BASELINE, not an approved level — it had simply never been visible,
because the old step ran `if: failure()` and read only errorSummaries. If a
later run shows a different figure, compare against 110 before assuming a
regression; if it shows a lower one, that is progress rather than a bug in
the counter.

The bulk of it is one issue, not 110 separate ones: `lock`/`unlock` called
from asynchronous contexts in Sources/NaturalRemote/DrugKit/DrugKitEngine.swift,
2,350 occurrences across both targets in the raw log. Five of those are
flagged "this is an error in the Swift 6 language mode", so they are a
scheduling question rather than a tidiness one. Deliberately not fixed here:
concurrency behaviour was out of scope for the design pass that added this.

No ceiling is enforced. The number should sit in view for a while before
anyone argues about what it ought to be.

A NOTE ON THIS CODE PATH
------------------------
Until 2026-09-20 the xcresult extraction had never once executed: it was
gated on `if: failure()` and the build had not failed since it was written.
Whether `xcresulttool get object --legacy` still worked under Xcode 26.6 was
therefore unknown, not assumed-good. Run 35498773988 exercised it for the
first time and it does work. A code path that has never run is a hypothesis,
not a fallback.
"""
from __future__ import annotations

import json
import pathlib
import subprocess
import sys

KINDS = ("errorSummaries", "warningSummaries", "analyzerWarningSummaries")


def summaries(payload: dict, kind: str) -> list[str]:
    block = payload.get("issues", {}).get(kind, {})
    values = block.get("_values", []) if isinstance(block, dict) else []
    out = []
    for item in values:
        message = item.get("message", {})
        text = message.get("_value", "") if isinstance(message, dict) else str(message)
        out.append(text.strip())
    return out


def main(argv: list[str]) -> int:
    failed = 0
    for raw in argv[1:]:
        path = pathlib.Path(raw)
        if not path.exists():
            print(f"(no result bundle at {path} — build step may not have reached it)")
            continue
        print(f"--- {path.name}")
        try:
            proc = subprocess.run(
                ["xcrun", "xcresulttool", "get", "object", "--legacy",
                 "--format", "json", "--path", str(path)],
                capture_output=True, text=True, check=True,
            )
            payload = json.loads(proc.stdout)
        except Exception as exc:  # noqa: BLE001 — any failure means no visibility
            print(f"FAIL: could not read {path}: {exc}")
            failed = 1
            continue
        for kind in KINDS:
            items = summaries(payload, kind)
            print(f"  {kind}: {len(items)}")
            for text in items[:40]:
                print(f"      {text[:200]}")
    return failed


if __name__ == "__main__":
    sys.exit(main(sys.argv))
