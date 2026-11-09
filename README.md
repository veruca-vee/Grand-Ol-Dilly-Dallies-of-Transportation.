# G.O.D.O.T — Grand Ol' Dilly-Dallies Of Transportation

**G**rand **O**l' **D**illy-Dallies **O**f **T**ransportation.
Built in **Godot**. (Working title in the files before 2026-10-29 was
"Felony City" — that name is retired, the history is in `SKELETON.md`.)

Target, set by Vee 2026-10-29: **ditch the top-down. PS2 level, like
San Andreas — like when it came out.** Third-person 3D, period budgets,
not modern AAA.

## Where it stands

- `SKELETON.md` — what's decided (in Vee's words), what's blank, and
  the dated pivot from GTA 1 top-down → PS2-era 3D
- `engine/data/` — **every gameplay number, and the only copy.**
  Weapons, upgrades, enemies, world, wanted, combo, economy, copied
  from the original HTML version. This is `res://data/...`: what the
  game reads and what the headless simulator reads. Tune here.
  There used to be a second copy at the repo root; it drifted
  silently for five days because nothing read it, and Vee retired it
  2026-11-09 (`design/DATA_PARITY_SPEC.md` has the whole story).
- `.github/workflows/checks.yml` — the engine-free check (telemetry
  parser selftest) on every push. Pure Python, seconds; the Godot
  autotest is deliberately NOT in CI until the suite is confirmed
  green at 4.7.2
- `design/ENGINE.md` — why Godot
- `sim/SIMULATOR.md` + `engine/sim/simulator.gd` — headless balance
  simulator, runs on the same data files (verified passing)
- `assets/pipeline/` — emoji → scaffold → generated image → saved asset
- `assets/PREMADE.md` — checked pre-made asset shortlist (Kenney city
  kits CC0 first), with the binary-push warning for model files
- `engine/gate3d/` — **Gate 3D-0 (built 2026-10-29):** PS2-era 3D
  greybox. Third-person, low-poly city blocks, fog + 160-unit draw
  distance, one drivable car (+3 parked), wandering flap-head peds.
  Verified headless on Godot 4.3: 600 frames, zero script errors.
  Canadian look in 3D = upper head on a hinge at the mouth line,
  beady eyes riding it (see `gate3d/README.md`)
- `engine/` — Gate 0 greybox: a **top-down 2D systems prototype** in
  Godot 4.3 (movement, car stealing/driving, shooting, wanted, HUD),
  verified running 1200 frames headless with zero script errors.
  It proves the systems; it is NOT the target view. The 3D build is
  the next gate.

Characters in the greybox are drawn in code to Vee's stipulation:
South-Park-Canadian-style — beady eyes, head split at the mouth, the
whole top half flaps when they talk/shout. Whether that look carries
into 3D, and how, is an open slot in `SKELETON.md`.

Credit: Veruca Velharin
