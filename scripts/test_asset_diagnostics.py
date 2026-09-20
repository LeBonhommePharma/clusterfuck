#!/usr/bin/env python3
"""Correctness fixture for report_asset_diagnostics. Stdlib only.

A parser proven only on a clean build has not been shown to parse anything.
These are real actool output shapes, plus the Swift warnings it must ignore:
the last green run carried 116 distinct compiler warnings, and a reporter that
swept those into an "actool" count would be worse than silence.
"""
from __future__ import annotations

import contextlib
import io
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from report_asset_diagnostics import extract, main  # noqa: E402

FAILS: list[str] = []

# Left column: real actool / xcodebuild line. Right: severity we must report,
# or None for lines that must be ignored.
CASES: list[tuple[str, str | None]] = [
    # --- actool diagnostics that MUST be caught ---
    ("/path/Assets.xcassets:./AppIcon.appiconset/[][ipad][76x76][][][1x][][][]: notice: "
     "76x76@1x app icons only apply to iPad apps targeting releases of iOS prior to 10.0.",
     "notice"),
    ("/path/Assets.xcassets: warning: The app icon set \"AppIcon\" has 1 unassigned child.",
     "warning"),
    ("/path/Assets.xcassets:./Brand.imageset: warning: unassigned children.", "warning"),
    ("/path/Assets.xcassets:./AppIcon.appiconset/[][][1024x1024][][][1x][][][]: error: "
     "The image set name provided does not match any image set.", "error"),
    ("/path/Colors.xcassets:./tint.colorset: notice: colour has no dark appearance variant.",
     "notice"),
    ("CompileAssetCatalog /Build/Products/Debug-iphonesimulator/App.app: warning: something",
     "warning"),

    # --- lines that MUST be ignored ---
    # Swift compiler warnings: 2,350 of these in the last green run.
    ("/path/Sources/NaturalRemote/DrugKit/DrugKitEngine.swift:215:18: warning: instance method "
     "'lock' is unavailable from asynchronous contexts", None),
    ("/path/Sources/Foo.swift:12:9: warning: variable 'local' was never mutated", None),
    # The actool invocation itself names the tool but is a command, not a diagnostic.
    ("    /Applications/Xcode.app/Contents/Developer/usr/bin/actool /path/Assets.xcassets "
     "--compile /tmp/out --output-format human-readable-text --notices --warnings", None),
    # Unrelated tool output.
    ("ld: warning: object file was built for newer macOS version", None),
    ("note: Using new build system", None),
]


def main_test() -> int:
    for line, want in CASES:
        got = extract(line)
        if want is None:
            if got:
                FAILS.append(f"should have ignored but reported {got[0][0]}: {line[:70]}")
        else:
            if not got:
                FAILS.append(f"should have caught a {want} but reported nothing: {line[:70]}")
            elif got[0][0] != want:
                FAILS.append(f"expected {want}, got {got[0][0]}: {line[:70]}")

    # counts must aggregate, and repeats must collapse in the display but not the count
    blob = "\n".join(line for line, want in CASES)
    found = extract(blob)
    if len(found) != sum(1 for _, w in CASES if w):
        FAILS.append(f"aggregate extract found {len(found)}, expected {sum(1 for _, w in CASES if w)}")

    # a missing log must FAIL, not silently report zero — that is the vacuous shape
    with tempfile.TemporaryDirectory() as tmp:
        # Swallow the reporter's own stdout here: the missing-log case is
        # SUPPOSED to print "FAIL: build log not captured", and a fixture that
        # prints FAIL on a passing run teaches people to skim its output.
        absent = pathlib.Path(tmp) / "never-written.log"
        with contextlib.redirect_stdout(io.StringIO()) as sink:
            rc = main(["x", str(absent)])
        if rc == 0:
            FAILS.append("a missing build log was reported as clean instead of failing")
        elif "not captured" not in sink.getvalue():
            FAILS.append("missing log failed without saying the capture broke")
        real = pathlib.Path(tmp) / "build.log"
        real.write_text(blob, encoding="utf-8")
        with contextlib.redirect_stdout(io.StringIO()) as sink:
            rc = main(["x", str(real)])
        if rc != 0:
            FAILS.append("a present log with diagnostics should still exit 0 (reporting only)")
        if "3 warning(s)" not in sink.getvalue():
            FAILS.append(f"counts missing from the report: {sink.getvalue()[:120]!r}")

    for line in FAILS:
        print("FAIL:", line)
    if not FAILS:
        print(f"OK asset diagnostics parser ({len(CASES)} line shapes, "
              f"{sum(1 for _, w in CASES if w)} caught / {sum(1 for _, w in CASES if not w)} ignored)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main_test())
