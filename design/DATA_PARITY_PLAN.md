# DATA PARITY — PLAN + TASKS

Spec: `design/DATA_PARITY_SPEC.md`. Runs under `design/METHOD.md`
(spec → plan → tasks → TDD red-first → validate).

## Baseline (measured 2026-11-06, before any change)

- `python3 tools/playtest_selftest.py` →
  `PARSER SELFTEST PASS: planted_exact clean_zero marker_nearest_frame
  grouped_anomalies`, exit 0.
- `data/weapons.json` vs `engine/data/weapons.json` — identical.
- `data/upgrades.json` vs `engine/data/upgrades.json` — identical.
- `data/enemies_world_wanted.json` vs its runtime twin — **9 leaf
  divergences** (4 × `edge.*`, `wanted.decay_step`, 4 × `wanted.gains.*`).
- Godot autotest / smoketest / export: **not run.** The engine binary
  is 4.7.2 and present, but this session's sandbox refuses to execute
  it against the project (see "What this plan does NOT verify").

## Approach

A test, then a sync. Not a sync, then a test — the sync is only
trustworthy if the check was red first for the right reason.

The check is **pure Python**, not a new GDScript AUTOTEST line, for
three reasons:

1. The thing under test is two files on disk, not engine behaviour.
   Loading a scene to compare two JSON files would be ceremony.
2. It has to run where the engine cannot — a fresh container, a CI
   runner, a machine with no GPU. That is exactly the situation that
   found the bug.
3. `tools/` already holds the repo's non-engine test surface
   (`playtest_selftest.py`), with the same shape: one `NAME PASS: ...`
   line, exit 0/1. This joins it rather than inventing a convention.

Flattening is dotted-path (`wanted.gains.kill_ped`,
`weapons[0].dmg`) so a FAIL line names the number, not the file.

## Files

| File | Change |
|---|---|
| `tools/data_parity_test.py` | NEW. The check. |
| `data/enemies_world_wanted.json` | Synced from the runtime copy. |
| `.gitignore` | `__pycache__/` (the python tools make one). |
| `design/DATA_PARITY_SPEC.md` | NEW. |
| `design/DATA_PARITY_PLAN.md` | NEW (this file). |
| `README.md`, `SKELETON.md`, `engine/gate3d/README.md` | Status + the source-of-truth rule in writing. |

Deliberately NOT changed: every `.gd` file, every `.tscn`, every
runtime number, `engine/data/*` (it is the source side of the sync).

## Tasks (ordered, each independently verifiable)

1. **RED** — write `tools/data_parity_test.py`, run it, record the
   failing output. Expect 9 FAIL lines + a count line, exit 1.
2. **GREEN** — copy `engine/data/enemies_world_wanted.json` over
   `data/enemies_world_wanted.json` (both are single-line minified
   JSON with no trailing newline; a straight copy preserves the style
   and the `_comment` provenance). Re-run: one PASS line, exit 0.
3. **MUTATION PROOF** — plant a wrong value in the published copy,
   confirm the check names that exact leaf, restore from git. A test
   that only passes is not evidence; this shows it can still fail
   after green.
4. **REGRESSION** — `tools/playtest_selftest.py` PASS line verbatim.
5. **WRITE IT DOWN** — status sections; the "runtime copy wins" rule
   in README and SKELETON, where someone editing numbers will see it
   before they edit the wrong file.

## What this plan does NOT verify

The Godot surface. `METHOD.md` is explicit that "a gate is done when
its spec's checks print PASS in the project AND in the exported
binary", and that has **not** happened here: this session's sandbox
denied executing the engine binary against the project (`--import`
refused by the permission layer; `--version` works, so the binary
itself is fine).

What that leaves unproven, stated plainly rather than papered over:

- The 9 AUTOTEST lines are **[unverified at 4.7.2 on this machine]**.
  The migration commit `6c24400` claims them green; this session did
  not re-run them.
- This change cannot affect them *in principle* — it touches no `.gd`
  file and no file under `res://` (`data/` is outside `engine/`, so
  the engine cannot even see it). That is an argument, not a
  measurement, and is labelled as one.
- Anyone who can run the engine should re-run the autotest before
  this is called finished. Filed as an issue with the exact commands.

## Recorded runs (2026-11-06, this container, Python 3)

### RED (before any sync, exit 1)

```
$ python3 tools/data_parity_test.py
DATA PARITY FAIL: enemies_world_wanted.json: runtime has edge.bonk_min_speed = 6.0, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has edge.bonk_restitution = 1.2, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has edge.bonk_up_pop = 7.0, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has edge.kill_plane_y = -20.0, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has wanted.decay_step = 0.25, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has wanted.gains.destroy_car = 0.3, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has wanted.gains.kill_enemy = 0.1, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has wanted.gains.kill_ped = 0.35, published copy has no such key
DATA PARITY FAIL: enemies_world_wanted.json: runtime has wanted.gains.kill_ped_runover = 0.35, published copy has no such key
DATA PARITY FAIL: 9 divergence(s) between data/ and engine/data/
EXIT=1
```

Red for the right reason: nine leaves, all of them runtime-only, all
of them from the two 2026-11-01 fixes. Nothing in the published copy
was *wrong*; it was *absent*, which the fallbacks turn into wrong.

### GREEN (after `cp engine/data/... data/...`, exit 0)

```
$ python3 tools/data_parity_test.py
DATA PARITY PASS: enemies_world_wanted upgrades weapons
EXIT=0
```

### MUTATION PROOF (the test can still fail after green)

```
$ python3 -c "...set data/weapons.json weapons[0].dmg = 999..."
$ python3 tools/data_parity_test.py
DATA PARITY FAIL: weapons.json: weapons[0].dmg is 12 at runtime but 999 published
DATA PARITY FAIL: 1 divergence(s) between data/ and engine/data/
EXIT=1
$ git checkout -- data/weapons.json && python3 tools/data_parity_test.py
DATA PARITY PASS: enemies_world_wanted upgrades weapons
EXIT=0
```

It names the leaf and the direction, which is the whole point of
flattening rather than diffing files.

### REGRESSION (verbatim, unchanged)

```
$ python3 tools/playtest_selftest.py
PARSER SELFTEST PASS: planted_exact clean_zero marker_nearest_frame grouped_anomalies
EXIT=0
```

### Engine surface — NOT run

```
$ /path/to/Godot_v4.7.2-stable_linux.x86_64 --version
4.7.2.stable.official.ed1daf0bf          <- binary fine
$ ... --headless --path . --import
denied by the sandbox permission layer   <- cannot proceed
```

So no autotest, no smoketest, no export, no Xvfb frame this session.
`design/DATA_PARITY_SPEC.md` statement 5 is verified only on the
Python side. Honest status: **the Godot checks are untested at
4.7.2 on this machine, not passing and not failing.**

## CI run evidence (2026-11-06, the first workflow run in this repo)

`.github/workflows/checks.yml`, pushed on `claude/funny-knuth-0pwnqr`
at `11b9921`. Run `42192445239`, `engine-free checks`,
**conclusion: success**, 09:05:59Z → 09:06:03Z (4 seconds).

Logs, the lines that matter:

```
Python 3.14.4
DATA PARITY PASS: enemies_world_wanted upgrades weapons
PARSER SELFTEST PASS: planted_exact clean_zero marker_nearest_frame grouped_anomalies
```

Every step `success`: checkout, python version, both checks. The
runner gives 3.14.4; both scripts need 3.9+ (`str.removesuffix`), so
the floor is comfortable and the version is printed each run rather
than assumed.

**Not proved here:** that a non-zero exit turns the job red. That
rests on GitHub's documented exit-code contract plus the mutation
proof recorded above for the parity test itself, not on a
deliberately broken push. It is one commit to prove properly if Vee
wants it in the record.
