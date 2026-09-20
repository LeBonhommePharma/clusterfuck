#!/usr/bin/env python3
"""Correctness fixture for mutation_harness.

A harness that cries wolf is worse than no harness. Writing this one produced
six false positives on its first attempt (compound `or` mis-split, loop-local
variable shadowing) and one persistent misclassification (a tab-or-space
nested-if disjunction reported as unable to fail when it fires correctly).

So the harness is not trusted on the real scripts until it classifies a set of
guards whose verdicts are known by construction. Each fixture below is
hermetic: its own miniature contract script over its own miniature artifacts,
in a temp directory. Nothing here touches the repo.
"""
from __future__ import annotations

import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from mutation_harness import DEAD, LIVE, UNKNOWN, classify, lint_substring_as_structure  # noqa: E402

FAILS: list[str] = []

SCRIPT = '''
import pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent
FAILS = []
def fail(m): FAILS.append(m)
def read(rel): return (ROOT / rel).read_text()

def test_simple_positive():
    cfg = read("cfg.txt")
    if "REQUIRED_TOKEN" not in cfg:            # L1_LIVE
        fail("cfg must declare REQUIRED_TOKEN")

def test_simple_negative():
    cfg = read("cfg.txt")
    if "FORBIDDEN_TOKEN" in cfg:               # L2_LIVE
        fail("cfg must not declare FORBIDDEN_TOKEN")

def test_nested_disjunction():
    # The WKApplication shape: either spelling is acceptable, so the fail()
    # fires only when BOTH are absent. Leaf-level analysis calls this dead.
    plist = read("plist.txt")
    if "KEY\\tTRUE" not in plist:
        if "KEY    TRUE" not in plist:         # L3_LIVE
            fail("plist must set KEY true in some indentation")

def test_compound_or():
    cfg = read("cfg.txt")
    if "ALPHA" not in cfg or "BETA" not in cfg:   # L4_LIVE
        fail("cfg must declare both ALPHA and BETA")

def test_contradiction():
    cfg = read("cfg.txt")
    if "GAMMA" in cfg and "GAMMA" not in cfg:  # U1_UNKNOWN
        fail("unsatisfiable by construction")

def test_unmodellable_target():
    cfg = read("cfg.txt")
    if "DELTA" not in cfg.replace("x", "y"):   # U2_UNKNOWN
        fail("comparator is a call, not a name")

def test_never_wired():
    # Real class: a contract function nobody added to main(). Its fail() can
    # never execute no matter what the artifacts say.
    cfg = read("cfg.txt")
    if "EPSILON" not in cfg:                   # D1_DEAD
        fail("this can never run")

def main():
    test_simple_positive()
    test_simple_negative()
    test_nested_disjunction()
    test_compound_or()
    test_contradiction()
    test_unmodellable_target()
    # test_never_wired() deliberately not called
    for m in FAILS: print("FAIL:", m)
    return 1 if FAILS else 0

sys.exit(main())
'''

EXPECTED = {
    "L1_LIVE": LIVE, "L2_LIVE": LIVE, "L3_LIVE": LIVE, "L4_LIVE": LIVE,
    "U1_UNKNOWN": UNKNOWN, "U2_UNKNOWN": UNKNOWN, "D1_DEAD": DEAD,
}


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        (root / "cfg.txt").write_text("REQUIRED_TOKEN ALPHA BETA GAMMA DELTA EPSILON\n")
        (root / "plist.txt").write_text("KEY\tTRUE\n")
        script = root / "contracts.py"
        script.write_text(SCRIPT)

        rows = classify(script, root)
        lines = SCRIPT.splitlines()
        by_tag = {}
        for row in rows:
            # the marker sits on the condition line, one or two above the fail()
            for back in range(0, 4):
                idx = row["line"] - 1 - back
                if idx < 0:
                    continue
                for tag in EXPECTED:
                    if tag in lines[idx]:
                        by_tag[tag] = row["verdict"]
                        break
                if row["line"] in [r["line"] for r in rows if True] and any(
                        t in lines[idx] for t in EXPECTED):
                    break

        for tag, want in EXPECTED.items():
            got = by_tag.get(tag)
            if got is None:
                FAILS.append(f"{tag}: harness produced no verdict at all")
            elif got != want:
                FAILS.append(f"{tag}: expected {want}, got {got}")

        # A false DEAD is the failure mode that destroys trust. Assert it
        # separately and loudly.
        false_deads = [t for t, w in EXPECTED.items() if w != DEAD and by_tag.get(t) == DEAD]
        if false_deads:
            FAILS.append(f"FALSE POSITIVES — reported DEAD for {false_deads}")

        # the lint must flag structural-substring shapes and nothing else
        (root / "lintable.py").write_text(
            'import pathlib\n'
            'ROOT = pathlib.Path(__file__).resolve().parent\n'
            'FAILS=[]\n'
            'def fail(m): FAILS.append(m)\n'
            'def read(rel): return (ROOT / rel).read_text()\n'
            'def test_x():\n'
            '    p = read("a.plist")\n'
            '    if "SomeKey" not in p: fail("k")\n'
            '    t = read("b.txt")\n'
            '    if "<key>X</key>" not in t: fail("markup")\n'
            '    if "plain" not in t: fail("fine")\n'
        )
        found = lint_substring_as_structure(root / "lintable.py")
        if len(found) != 2:
            FAILS.append(f"lint expected 2 findings (structured file, markup literal), got {len(found)}: {found}")
        if found and not any(".plist" in f for f in found):
            FAILS.append("lint missed the structured-file case")
        if found and not any("structure" in f for f in found):
            FAILS.append("lint missed the markup-literal case")

    for line in FAILS:
        print("FAIL:", line)
    if not FAILS:
        print(f"OK mutation harness self-test ({len(EXPECTED)} guards classified correctly, lint 2/2)")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())
