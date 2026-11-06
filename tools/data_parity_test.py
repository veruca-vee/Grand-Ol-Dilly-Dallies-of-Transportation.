#!/usr/bin/env python3
"""DATA PARITY TEST — the two copies of the gameplay numbers must agree.

The repo keeps the gameplay numbers twice:

  engine/data/*.json  the RUNTIME copy. `res://data/...` resolves here, so
                      this is what the game and the headless simulator
                      actually read (engine/sim/simulator.gd line 5:
                      "Reads the SAME res://data/*.json the game reads").
  data/*.json         the PUBLISHED copy. README.md calls it "every gameplay
                      number, copied from the original HTML version ... These
                      carry over to the 3D build unchanged".

"unchanged" is a checkable statement, so it gets a check. This test is pure
Python on purpose: it runs with no Godot binary, no import cache, no display,
so data drift is caught even when the engine cannot be launched.

Run:  python3 tools/data_parity_test.py
Exit: 0 and one PASS line, or 1 and one FAIL line per divergence.

Direction, when this fails: the RUNTIME copy wins. It is the one the autotest
lines were made green against. Copy engine/data -> data, never the reverse,
unless Vee is deliberately retuning.
"""

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PUBLISHED = REPO / "data"
RUNTIME = REPO / "engine" / "data"


def flatten(node, trail=""):
    """{'a': {'b': 1}} -> {'a.b': 1}; lists index by position."""
    out = {}
    if isinstance(node, dict):
        for key, value in node.items():
            out.update(flatten(value, f"{trail}.{key}" if trail else str(key)))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            out.update(flatten(value, f"{trail}[{index}]"))
    else:
        out[trail] = node
    return out


def compare(name, fails):
    published_path = PUBLISHED / name
    runtime_path = RUNTIME / name

    for path in (published_path, runtime_path):
        if not path.exists():
            fails.append(f"{name}: missing {path.relative_to(REPO)}")
            return

    try:
        published = flatten(json.loads(published_path.read_text()))
        runtime = flatten(json.loads(runtime_path.read_text()))
    except json.JSONDecodeError as exc:
        fails.append(f"{name}: not valid JSON ({exc})")
        return

    # Comments are documentation, not numbers: a differently worded _comment
    # is not a balance change, so it does not fail parity.
    def numbers_only(flat):
        return {k: v for k, v in flat.items() if not k.split(".")[-1].startswith("_")}

    published = numbers_only(published)
    runtime = numbers_only(runtime)

    for key in sorted(set(runtime) - set(published)):
        fails.append(
            f"{name}: runtime has {key} = {runtime[key]!r}, published copy has no such key"
        )
    for key in sorted(set(published) - set(runtime)):
        fails.append(
            f"{name}: published has {key} = {published[key]!r}, runtime copy has no such key"
        )
    for key in sorted(set(published) & set(runtime)):
        if published[key] != runtime[key]:
            fails.append(
                f"{name}: {key} is {runtime[key]!r} at runtime but {published[key]!r} published"
            )


def main():
    fails = []

    published_names = {p.name for p in PUBLISHED.glob("*.json")}
    runtime_names = {p.name for p in RUNTIME.glob("*.json")}

    for name in sorted(runtime_names - published_names):
        fails.append(f"{name}: exists in engine/data but not in data/ (unpublished number set)")
    for name in sorted(published_names - runtime_names):
        fails.append(f"{name}: exists in data/ but not in engine/data (dead number set)")

    for name in sorted(published_names & runtime_names):
        compare(name, fails)

    if fails:
        for line in fails:
            print(f"DATA PARITY FAIL: {line}")
        print(f"DATA PARITY FAIL: {len(fails)} divergence(s) between data/ and engine/data/")
        return 1

    checked = " ".join(sorted(n.removesuffix(".json") for n in published_names & runtime_names))
    print(f"DATA PARITY PASS: {checked}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
