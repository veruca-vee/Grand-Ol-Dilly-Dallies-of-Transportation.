# PLAYTEST TELEMETRY — SPEC: "Hexe can see what Vee sees break"

Status: Vee's request, 2026-11-01 ("add a live debug log and
screenshot/parser for when I play so you can see all the things
that break or work"). Runs under METHOD.md (TDD, red first).
Implementation specifics below are the assistant's draft under
step 0/1; Vee can amend any line.

## Behavior statements (each checkable)

1. **Every run leaves a session file.** Starting the game creates
   `user://playtest/session-<yyyymmdd-hhmmss>.log`, first line a
   header (build label, godot version, timestamp). One JSON-ish
   event per line, each with `t=` seconds since start.
2. **State snapshots.** Every 0.5 s: player pos, vertical
   velocity, fps, wanted, in_car, health, cash. Cheap text only.
3. **Events.** BUSTED, wanted level change (floor), upgrade
   bought, weapon pickup, car enter/exit — logged as they happen.
4. **Screenshots.** A PNG frame every 20 s AND on BUSTED, saved
   beside the log (`frame-<t>.png`), capped (oldest deleted past
   90 frames). F9 forces a frame + a `MARKER` event line — Vee's
   "it broke right here" button.
5. **Core-worthy.** The logger is an engine/core module
   (`DebugLog`, class_name), game-agnostic: the game feeds it
   snapshots/events; it owns files, rotation, timing. Smoketest
   gains a telemetry check using a temp dir.
6. **Parser.** `tools/playtest_digest.py` (outside the engine,
   not shipped in the export): reads a session dir, prints a
   digest — duration, event counts, and ANOMALIES with rules:
   position jump > 25 u between snapshots while on foot, y < -5
   or y > 30, fps < 20 sustained 3 s, NaN anywhere. Frames listed
   by timestamp so a marker's nearest frame is one lookup away.
7. **Nothing regresses / nothing leaks.** All existing PASS lines
   verbatim. Telemetry is LOCAL ONLY: files on the player's
   machine, fetched by Hexe over SSH only when Vee says a session
   happened or asks. No network code in the logger. Perf: log
   writes are appends; snapshot cost must not show in the
   1200-frame run (0 script errors, same as before).

## Out of scope

- Live streaming (this is fetch-after, not a live feed).
- Engine stderr capture (Hexe already gets that from the launch
  log on the laptop when she launches via SSH).
- Any change to gameplay numbers, save shape, or controls
  besides adding F9.
