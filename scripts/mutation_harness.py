#!/usr/bin/env python3
"""Ask of every guard in a contract script: can it fail?

A guard that has only ever been seen passing is indistinguishable from one
that cannot fail. This makes each guard's protected artifact genuinely violate
and checks the script exits nonzero.

The unit is the `fail()` CALL SITE, not the individual comparison. That
distinction is the whole correctness story:

    watch = read("Info.plist")
    if "<key>WKApplication</key>\\n\\t<true/>" not in watch:
        if "<key>WKApplication</key>\\n    <true/>" not in watch:
            fail(...)

Those two comparisons are a tab-or-space disjunction. Testing either leaf
alone says "this can never fire", because the other form is present -- and
that is a false positive, not a finding. Firing requires BOTH conditions
satisfied at once, so the mutation must remove both spellings together.

Three outcomes, and the third is load-bearing:

    LIVE     mutated the artifact, the script exited nonzero.
    DEAD     mutated the artifact, the script stayed green. A real finding.
    UNKNOWN  could not construct a mutation from the conditions. NOT a
             finding -- it means this guard needs a bespoke mutation. Never
             report UNKNOWN as DEAD; conflating the two is what produced six
             phantom findings the first time this was written.
"""
from __future__ import annotations

import ast
import pathlib
import subprocess
import sys

LIVE, DEAD, UNKNOWN = "LIVE", "DEAD", "UNKNOWN"


class Need:
    """One requirement on one file: this needle must be present, or absent."""

    def __init__(self, relpath: str, needle: str, present: bool):
        self.relpath, self.needle, self.present = relpath, needle, present

    def __repr__(self) -> str:
        return f"{'+' if self.present else '-'}{self.needle!r}@{self.relpath}"


def _file_scope(fn: ast.FunctionDef) -> dict[str, str]:
    """var -> relpath, from `x = read("...")`, including reads inside a for-loop
    over literal paths (where the var rebinds each iteration)."""
    scope: dict[str, str] = {}
    loop_literals: dict[str, list[str]] = {}
    for node in ast.walk(fn):
        if isinstance(node, ast.For) and isinstance(node.target, ast.Name):
            vals = [e.value for e in getattr(node.iter, "elts", [])
                    if isinstance(e, ast.Constant) and isinstance(e.value, str)]
            if vals:
                loop_literals[node.target.id] = vals
    for node in ast.walk(fn):
        if not (isinstance(node, ast.Assign) and len(node.targets) == 1
                and isinstance(node.targets[0], ast.Name)):
            continue
        var, val = node.targets[0].id, node.value
        if isinstance(val, ast.Call) and isinstance(val.func, ast.Name) and val.func.id == "read":
            arg = val.args[0] if val.args else None
            if isinstance(arg, ast.Constant):
                scope[var] = arg.value
            elif isinstance(arg, ast.Name) and arg.id in loop_literals:
                scope[var] = loop_literals[arg.id][0]   # any member exercises it
    return scope


def _needs_for(test: ast.expr, want_true: bool, scope: dict[str, str]) -> list[Need] | None:
    """What must be true of the files for `test` to evaluate to `want_true`."""
    if isinstance(test, ast.BoolOp) and isinstance(test.op, ast.Or):
        if want_true:
            for value in test.values:            # satisfying any one disjunct suffices
                got = _needs_for(value, True, scope)
                if got:
                    return got
            return None
        merged: list[Need] = []                  # falsifying an OR needs all false
        for value in test.values:
            got = _needs_for(value, False, scope)
            if got is None:
                return None
            merged += got
        return merged
    if isinstance(test, ast.BoolOp) and isinstance(test.op, ast.And):
        merged = []
        if not want_true:
            got = _needs_for(test.values[0], False, scope)
            return got
        for value in test.values:
            got = _needs_for(value, True, scope)
            if got is None:
                return None
            merged += got
        return merged
    if (isinstance(test, ast.Compare) and len(test.ops) == 1
            and isinstance(test.ops[0], (ast.In, ast.NotIn))
            and isinstance(test.left, ast.Constant) and isinstance(test.left.value, str)
            and isinstance(test.comparators[0], ast.Name)):
        rel = scope.get(test.comparators[0].id)
        if not rel:
            return None
        is_notin = isinstance(test.ops[0], ast.NotIn)
        # `needle not in f` true  => needle absent.  `needle in f` true => present.
        present = (not is_notin) if want_true else is_notin
        return [Need(rel, test.left.value, present)]
    return None


def collect(script: pathlib.Path) -> list[dict]:
    """One entry per fail() call site, with the condition chain that guards it."""
    tree = ast.parse(script.read_text(encoding="utf-8"))
    guards: list[dict] = []

    def is_fail(node: ast.AST) -> bool:
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                and node.func.id == "fail")

    def visit(stmts, chain, scope, fname):
        for stmt in stmts:
            if isinstance(stmt, ast.If):
                visit(stmt.body, chain + [(stmt.test, True)], scope, fname)
                visit(stmt.orelse, chain + [(stmt.test, False)], scope, fname)
                continue
            if isinstance(stmt, (ast.For, ast.While, ast.With, ast.Try)):
                for attr in ("body", "orelse", "finalbody"):
                    visit(getattr(stmt, attr, []) or [], chain, scope, fname)
                for handler in getattr(stmt, "handlers", []):
                    visit(handler.body, chain, scope, fname)
                continue
            # A simple statement cannot contain a nested If, so any fail()
            # found here genuinely sits under exactly `chain`.
            for sub in ast.walk(stmt):
                if is_fail(sub):
                    needs: list[Need] | None = []
                    for test, want in chain:
                        got = _needs_for(test, want, scope)
                        if got is None:
                            needs = None
                            break
                        needs += got
                    guards.append({"line": sub.lineno, "func": fname, "needs": needs})

    for fn in [n for n in tree.body if isinstance(n, ast.FunctionDef)]:
        visit(fn.body, [], _file_scope(fn), fn.name)

    seen, out = set(), []
    for g in guards:
        if g["line"] in seen:
            continue
        seen.add(g["line"])
        out.append(g)
    return out


def _comment(path: pathlib.Path, needle: str) -> str:
    if path.suffix in (".md", ".plist", ".entitlements", ".xcprivacy", ".html"):
        return f"\n<!-- {needle} -->\n"
    return f"\n// {needle}\n"


def classify(script: pathlib.Path, root: pathlib.Path) -> list[dict]:
    def run() -> int:
        return subprocess.run([sys.executable, str(script)], cwd=root,
                              capture_output=True, text=True).returncode

    if run() != 0:
        raise SystemExit(f"FAIL: {script.name} is not green at baseline; cannot classify")

    results = []
    for guard in collect(script):
        needs = guard["needs"]
        if needs is None or not needs:
            results.append({**guard, "verdict": UNKNOWN, "why": "no mutation derivable"})
            continue
        # conflicting requirements on one needle cannot be satisfied together
        keyed: dict[tuple[str, str], bool] = {}
        conflict = False
        for need in needs:
            key = (need.relpath, need.needle)
            if key in keyed and keyed[key] != need.present:
                conflict = True
            keyed[key] = need.present
        if conflict:
            results.append({**guard, "verdict": UNKNOWN, "why": "contradictory conditions"})
            continue

        originals: dict[pathlib.Path, str] = {}
        try:
            for (rel, needle), present in keyed.items():
                path = root / rel
                if path not in originals:
                    originals[path] = path.read_text(encoding="utf-8")
                text = path.read_text(encoding="utf-8")
                if present:
                    # requirement: needle must be present. Already there = satisfied.
                    text = text if needle in text else text + _comment(path, needle)
                else:
                    # requirement: needle must be absent. Already absent = satisfied.
                    # This is the tab-or-space disjunction: one spelling is in the
                    # file, the other never was, and BOTH must go for the guard to
                    # fire. Treating "already absent" as inapplicable is what made
                    # that guard look unable to fail when it fires correctly.
                    text = text.replace(needle, "")
                path.write_text(text, encoding="utf-8")
            changed = any((root / rel).read_text(encoding="utf-8") != originals[root / rel]
                          for rel, _ in keyed)
            if not changed:
                verdict, why = UNKNOWN, "every requirement already held; mutation was a no-op"
            else:
                verdict, why = (LIVE, "") if run() != 0 else (DEAD, "script stayed green")
        finally:
            for path, text in originals.items():
                path.write_text(text, encoding="utf-8")
        results.append({**guard, "verdict": verdict, "why": why})

    if run() != 0:
        raise SystemExit("FAIL: tree not restored after classification")
    return results


# ---------------------------------------------------------------------------
# Rule 2: substring-as-structure lint.
#
# Reachability is necessary but NOT sufficient, and the gap is the one that
# actually bit. Every real finding so far was an ADEQUATE-branch problem, not
# an unreachable one:
#
#   "| Primary | `#0284C7`" in master_md      reachable; matched a table
#                                             layout the file never used
#   "NSPrivacyTracking" in privacy_plist      reachable; satisfied by
#                                             NSPrivacyTrackingDomains
#   "<false/>" in privacy_plist               reachable; satisfied by any
#                                             unrelated false in the document
#
# A mutation test says LIVE on all three, because inserting the literal does
# fire the branch. What is wrong is that the substring is a bad proxy for the
# rule. That is not mechanically derivable in general -- but its SHAPE is:
# asserting something structural by matching raw text. So flag that shape.
STRUCTURED_SUFFIXES = (".plist", ".xcprivacy", ".entitlements", ".json", ".pbxproj")
STRUCTURAL_MARKUP = ("<key>", "<true/>", "<false/>", "<string>", "<array", "<dict", "|")


def lint_substring_as_structure(script: pathlib.Path) -> list[str]:
    tree = ast.parse(script.read_text(encoding="utf-8"))
    findings = []
    for fn in [n for n in tree.body if isinstance(n, ast.FunctionDef)]:
        scope = _file_scope(fn)
        for node in ast.walk(fn):
            if not (isinstance(node, ast.Compare) and len(node.ops) == 1
                    and isinstance(node.ops[0], (ast.In, ast.NotIn))
                    and isinstance(node.left, ast.Constant)
                    and isinstance(node.left.value, str)):
                continue
            needle = node.left.value
            target = node.comparators[0]
            rel = scope.get(target.id) if isinstance(target, ast.Name) else None
            reason = None
            if rel and rel.endswith(STRUCTURED_SUFFIXES):
                reason = f"substring match against structured file {rel}"
            elif any(m in needle for m in STRUCTURAL_MARKUP):
                reason = "substring literal asserts structure (markup or table syntax)"
            if reason:
                findings.append(f"{script.name}:{node.lineno}: {reason} — parse it instead "
                                f"({needle[:40]!r})")
    return findings


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    scripts = [root / "scripts/test_contracts.py"]
    bad = 0
    for script in scripts:
        rows = classify(script, root)
        tally = {v: sum(1 for r in rows if r["verdict"] == v) for v in (LIVE, DEAD, UNKNOWN)}
        print(f"{script.name}: {tally[LIVE]} live, {tally[DEAD]} dead, {tally[UNKNOWN]} need a bespoke mutation")
        for row in rows:
            if row["verdict"] == DEAD:
                bad += 1
                print(f"FAIL: {script.name}:{row['line']} in {row['func']}() cannot fail — {row['why']}")
        for finding in lint_substring_as_structure(script):
            bad += 1
            print("FAIL:", finding)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
