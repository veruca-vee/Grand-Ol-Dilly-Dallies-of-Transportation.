# PLAYTEST TELEMETRY — PLAN

Spec: `design/TELEMETRY_SPEC.md` ("Hexe can see what Vee sees
break"). Method: `design/METHOD.md` — this doc is step 2 (PLAN)
+ step 3 (TASKS). Implementation is step 4 (per-task TDD:
red → green → refactor); step 5 (VALIDATE & REVIEW) closes
the gate in `engine/gate3d/README.md`.

## Baseline (measured 2026-11-01, before any change)

- Autotest: all 5 contract lines PASS (project, headless),
  0 script errors.
- Smoketest: all 4 SMOKETEST PASS lines, 0 script errors.
- Export in `builds/GODOT-Linux/` is the Detail-1 markfix
  build (sha256 51abed46…4ebd).

## Technical approach per spec statement

### 1–4. Session log, snapshots, events, screenshots → `core/debug_log.gd`

- New core module `class_name DebugLog extends RefCounted`.
  Plain object, unit-testable without a scene (core rule 3,
  same as Economy/Wanted/Upgrades). NO G.O.D.O.T numbers
  inside: intervals/caps are engine defaults on the module
  (`snapshot_interval = 0.5`, `frame_interval = 20.0`,
  `frame_cap = 90`), overridable per game; the game passes
  only its build label and the output directory.
- API the game uses:
  - `start_session(dir_path, build_label) -> bool` — creates
    the dir, opens `session-<yyyymmdd-hhmmss>.log`, writes
    the header line (`# GODOT-TELEMETRY v1 build=<label>
    godot=<version> started=<iso8601>`). On any failure the
    logger disables itself, prints ONE line to stderr, and
    every later call is a no-op — telemetry must never crash
    or spam the game it observes.
  - `snapshot(state: Dictionary)` — one line:
    `t=<s> SNAPSHOT pos=<x,y,z> vy=<f> fps=<i> wanted=<f>
    in_car=<bool> hp=<f> cash=<i>`.
  - `event(name, data := {})` — one line:
    `t=<s> EVENT <name> k=v …`.
  - `tick(delta, state)` — core owns the timing (spec 5):
    accumulates real elapsed time, fires `snapshot(state)`
    every `snapshot_interval` and an auto-frame every
    `frame_interval`.
  - `marker()` — writes `EVENT MARKER` and forces a frame.
  - `capture_frame(image) -> bool` — the file/rotation core:
    saves `frame-<t>.png` beside the log, records the path,
    deletes the oldest frames past `frame_cap`. A null or
    empty image is refused (returns false, no file) — that is
    what makes headless runs safe.
  - `capture_now()` — pulls an image from `frame_provider`
    (a Callable the game sets) and captures it. Viewport
    grabs are renderer-dependent, so real-pixel capture is
    proven in the Xvfb validation, not in headless tests;
    tests inject generated Images through the same path.
- Writes are append-only in behaviour: the file is created
  once at session start, the handle stays open, each line is
  `store_line` + `flush`. No network code, no OS calls
  beyond file I/O.
- Time base is `Time.get_ticks_msec()` from session start.
  A `_test_now` seam (seconds, −1 = live clock) lets tests
  stamp deterministic times — the same pattern as the
  autotest's `move_override` seam in `player3d.gd`.

### 5. Game wiring → `gate3d/gate3d_main.gd`

- `_ready`: create the logger, resolve the directory
  (`GODOT_TELEMETRY_DIR` env override if set and non-empty,
  else `user://playtest`; under `--autotest`,
  `user://playtest_autotest` so test runs never mix with a
  player's real sessions — mirrors the save-path pattern),
  `start_session(dir, "Detail1+Telemetry")`, set
  `frame_provider` to a viewport-grab Callable.
- `_process`: build the snapshot Dictionary (player pos,
  vertical velocity — the car's while driving — fps from
  `Performance.TIME_FPS`, float wanted, in_car, hp, cash)
  and call `debug_log.tick(delta, state)`. Skipped only
  when the logger failed to start.
- Events at the existing code points, no rule changes:
  `BUSTED` (+ forced frame) at the top of
  `on_player_death`; `WANTED` (from/to/level) whenever the
  floori changes — checked in `add_wanted` and after the
  decay tick in `_physics_process`; `UPGRADE` (id/level/
  cost) on a successful `buy_upgrade`; `CAR_ENTER` /
  `CAR_EXIT` in `_try_enter_car` / `_exit_car`; `PICKUP`
  (kind, +weapon name for weapon pickups) in the pickup
  loop; `SESSION_START` event right after the header.
- F9 in `_input`: `debug_log.marker()` — the ONLY control
  added, per spec. Works with the shop open (main already
  runs `PROCESS_MODE_ALWAYS` for input).
- HUD help line gains "· F9 mark" so the button is
  discoverable in-game.

### 6. Parser → `tools/playtest_digest.py` (+ self-test)

- Stdlib-only Python. Input: a session dir. For every
  `session-*.log` in it, prints a Markdown digest section:
  build label, duration, snapshot/event counts, event
  tallies (PICKUP broken down by kind), the anomaly list,
  the frame index (t parsed from `frame-<t>.png` names),
  and for every MARKER and anomaly the nearest frame.
- Anomaly rules (spec 6, exactly): on-foot position jump
  > 25 u between consecutive snapshots; y < −5 or y > 30;
  fps < 20 sustained ≥ 3 s (one anomaly per run of low
  snapshots, reporting start t + span); NaN anywhere in a
  line.
- `tools/playtest_selftest.py` builds two fake sessions
  (one with exactly 4 planted anomalies — jump, y, fps-run,
  NaN — plus a marker and frames; one clean) and asserts
  the digester flags exactly the planted set and nothing
  in the clean session. Written BEFORE the parser (its red
  run is the parser's RED).

## What does NOT change

- Gameplay numbers, the save file shape, the save path,
  controls (beyond adding F9), spawn/combat/economy rules.
- Existing PASS lines: the 5 AUTOTEST lines and the 4
  SMOKETEST lines stay byte-identical. New checks append:
  one AUTOTEST line (`telemetry_log …`) and one SMOKETEST
  line (`telemetry debug_log`).
- The 2D Gate 0 game (`scripts/`), the simulator, data
  files.
- No GitHub push, no device connections (parent's jobs).

## Tasks (ordered, each independently verifiable)

- **T1 — Parser self-test first (RED for T2).** Write
  `tools/playtest_selftest.py` with the two fake sessions
  and expected anomaly sets; run it against the not-yet-
  written parser; record the failure.
- **T2 — Parser (GREEN for T1).** Write
  `tools/playtest_digest.py`; self-test passes exactly.
  Refactor: shared line-parsing helpers; self-test still
  passes.
- **T3 — Telemetry tests first (RED).** Autotest section
  10 `telemetry_log` (logger unit checks via a `load()`
  seam so a missing module fails as assertions, not a
  parse error — the Detail-1 precedent; game-wiring checks
  via the `get("debug_log")` duck seam) and the smoketest
  telemetry section (standalone DebugLog in a bare scene,
  temp dir). Run both; record RED verbatim.
- **T4 — DebugLog core (GREEN, unit half of T3).** Write
  `core/debug_log.gd`. Smoketest telemetry goes green;
  autotest unit checks go green, wiring checks still red
  (recorded — wiring is T5).
- **T5 — Game wiring (GREEN, rest of T3).** Wire
  `gate3d_main.gd` per above. Full suite green: 6 AUTOTEST
  lines + 5 SMOKETEST lines. Refactor: the snapshot-state
  builder and wanted-check become small helpers; suite
  identically green.
- **T6 — Validate & review.** Xvfb real-game run (~90 s)
  producing a real session in the app_userdata playtest
  dir; parser digest on it quoted; a real frame PNG pixel-
  variance-checked; Xvfb `--autotest` run shows event
  lines in a real session file (UPGRADE etc. from the
  test's real code paths); 1200-frame headless run, 0
  script errors; edge-case notes (BUSTED mid-capture,
  rotation during play, unwritable dir) into the README.
- **T7 — Export + docs.** Linux export; exported binary
  full autotest (all 6 lines); sha256/sizes; zip
  `builds/GODOT-Linux-Telemetry.zip`; README gate section;
  SKELETON.md status (+ the 3-line fetch/digest workflow);
  core README module row for DebugLog.

## Completion (2026-11-01)

All tasks done; full evidence in the README gate section
("Playtest Telemetry"). Summary: parser self-test red →
green (planted anomalies exact, clean session zero); logger
red (module missing / not wired) → unit green with DebugLog
→ full green after wiring; refactor identically green.
Validation: 95 s Xvfb session (158 snapshots, real frames,
6,415 unique colours), event-rich Xvfb autotest session,
digest run on the real session (its single fps anomaly =
this VM's llvmpipe software rendering, labelled), 1200
frames / 0 script errors, unwritable-dir probe clean.
Export 66,246,816 bytes, sha256 a46fbc23…121e15; all 6
AUTOTEST + 5 SMOKETEST lines pass in the exported binary;
zip `builds/GODOT-Linux-Telemetry.zip` 24,332,105 bytes,
sha256 1f010a54…f6c62. No deviations from the spec; nothing
dropped.
