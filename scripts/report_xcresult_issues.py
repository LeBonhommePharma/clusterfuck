#!/usr/bin/env python3
"""Print error, warning and analyzer summaries from an .xcresult. Stdlib only.

The previous inline version ran only `if: failure()` and read only
`errorSummaries`, so warnings never surfaced at all. This reads all three
summary kinds and runs on success too. Reporting only: exit 0 unless the
bundle exists and cannot be read, which would mean the capture is broken.
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
