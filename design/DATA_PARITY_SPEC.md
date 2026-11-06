# DATA PARITY — SPEC: "one set of numbers, not two"

Status: found 2026-11-06 while standing up a build environment on a
fresh machine. Not a feature request from Vee — a defect found in the
tree, fixed under METHOD.md (TDD, red first). Recorded here because
METHOD says a gate is done when its spec's checks print PASS, and this
check had never existed.

## The defect, in plain words

The gameplay numbers live in the repo **twice**:

- `engine/data/*.json` — the **runtime** copy. `res://` resolves to
  `engine/`, so `res://data/weapons.json` is this one. The game reads
  it (`engine/core/data_loader.gd`) and so does the headless balance
  simulator, whose own comment says "Reads the SAME res://data/*.json
  the game reads" (`engine/sim/simulator.gd:5`).
- `data/*.json` — the **published** copy. `README.md` describes it as
  "every gameplay number, copied from the original HTML version ...
  These carry over to the 3D build unchanged."

"unchanged" stopped being true on 2026-11-01. Two fixes wrote tuning
into the runtime copy only:

- the wanted pacing fix (`f3258ca`) added `wanted.gains`
  (kill_ped 0.35) and `wanted.decay_step` (0.25)
- the fall fix (`e537abd`) added the whole `edge` block
  (kill_plane_y, bonk_min_speed, bonk_restitution, bonk_up_pop)

`git log -- data/` has exactly one entry, the initial scaffold
(`3f5dda0`). The published copy has never been touched since.

## Why it is load-bearing, not cosmetic

The engine reads these keys with fallbacks, and two of the fallbacks
are the **pre-fix HTML values**:

- `engine/core/wanted.gd:32` — `decay_step = float(cfg.get("decay_step", 1.0))`.
  Missing key = a whole star per decay tick instead of 0.25: four times
  the decay Vee asked for.
- `engine/gate3d/gate3d_main.gd:824` — `wanted_gains.get("kill_ped", 0.15)`.
  Missing key = the old 0.15 gain, i.e. the exact ped-chain pacing bug
  f3258ca was written to fix.

So the stale copy is not merely out of date: it is a loaded gun. Point
the engine at it — a path edit, a sync in the wrong direction, a new
surface that loads `data/` because README says that is where the
numbers are — and the wanted pacing fix silently reverts with every
AUTOTEST line still green except `wanted_pacing`. The `edge` fallbacks
happen to match the data today, so that block is currently benign; it
is the same trap one tuning pass later.

## Behavior statements (each checkable)

1. **The two copies agree.** For every `*.json` present in both
   `data/` and `engine/data/`, every leaf value is equal. Keys whose
   final name starts with `_` (`_source`, `_comment`) are
   documentation, not numbers, and are exempt.
2. **Neither side has orphans.** A file in one directory and not the
   other fails: an unpublished number set, or a dead one.
3. **The check runs without Godot.** Pure Python 3, no engine binary,
   no import cache, no display. Drift is caught on any machine that
   can run the repo's existing `tools/*.py`, including CI and a
   container with no GPU.
4. **The runtime copy wins.** When the check fails, the fix is
   `engine/data/` → `data/`, never the reverse, unless Vee is
   deliberately retuning. Stated in the test's own docstring so
   whoever hits the FAIL does not have to guess direction.
5. **Nothing else regresses.** `tools/playtest_selftest.py` prints its
   PASS line verbatim; no `.gd` file, scene, or runtime number changes.

## Out of scope

- Collapsing the two copies into one. That is a structural call on
  Vee's repo layout (README and SKELETON both point at `data/` as the
  place the numbers live), so it is filed as an issue, not decided
  here. Parity makes the duplication safe; it does not defend it.
- Wiring this into CI. There is no CI in the repo yet; filed as an
  issue.
- Any gameplay number. This spec moves no value that the runtime did
  not already use.
