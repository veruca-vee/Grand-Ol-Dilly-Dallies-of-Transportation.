# Felony City — Skeleton

Rule (Vee's brainstorming rule, 2026-10-20/25): slots are filled only with
what Vee said in plain words. Blanks stay blank. One open question at a time.
No files were built for the PS2-GTA idea in 2026-10-25 — this file is the
first scaffold, created 2026-10-29 at Vee's direction in this chat:
"Bring it out of HTML and into an actual scaffolding and an actual engine
and an actual simulator"

## Filled — from Vee

- **Name (Vee, 2026-10-29): G.O.D.O.T** — "G=Grand O=Ol D=Dilly-Dallies
  O=Of T=Transportation": **Grand Ol' Dilly-Dallies Of Transportation**.
  Repo: veruca-vee/Grand-Ol-Dilly-Dallies-of-Transportation. (the repo
  name on GitHub literally ends in a period — verified in search results
  2026-10-29, and its description is "G.O.D.O.T")
- **Form — SUPERSEDED 2026-10-29 by Vee, in her words:** "Let's ditch
  the top down and shoot for PlayStation two level. Like San Andreas.
  But like when it came out"
  → Current form: **PS2-era 3D, third-person, San Andreas at launch
  (2004) as the level to aim at** — not GTA 1 top-down, not modern AAA.
  [interpretation, labelled: low-poly 3D city, third-person on foot /
  in car, draw-distance fog and period texture/model budgets are what
  "PS2 level, like when it came out" points at; the budgets themselves
  are a Gate-3D spec still to write, not Vee's words.]
  The Gate 0 top-down greybox stays in the repo as the systems
  prototype (data, wanted, economy, simulator all carry over); its
  camera/view does NOT carry over.
- **Form — original, superseded (kept for history):** "like its
  predecessors with today's graphics but just like good old Grand
  Theft Vehicle number one" (Vee, 2026-10-29, earlier this chat)
- **Source of truth for systems:** the two HTML versions Vee pasted
  2026-10-29 (multi-mode v2 + mobile-only v1). All numbers in `data/`
  are copied from that HTML, not invented.
- **Asset pipeline [earlier proposal, not yet re-confirmed for this build]:**
  Vee, 2026-10-25: assets start as emojis, are "meticulously scaffolded"
  and filled with generated images, then saved. Continuity at asset
  creation via Gemini / apparently ChatGPT.

- **Character look in 3D: YES (Vee, 2026-10-29):** "yes to the Canadian
  look, how not sure." → slot filled: the look carries into 3D.
  **How [assistant's design, not Vee's words]:** the head is two pieces
  split at the mouth line. The upper head (with the beady eyes on it)
  sits on a hinge pivot at the back of the jaw and rotates open/closed
  around that hinge while talking — the 2D flap, as a 3D hinge.
  Implemented in Gate 3D-0 (`engine/gate3d/flappy_person3d.gd`).
- **Character look (Gate 0 stipulation, Vee 2026-10-29):** "The characters
  must look similar to the way the Canadians look in South Park."
  [design translation, labelled: simple flat bodies, beady close-set eyes,
  and a head split horizontally at the mouth — the whole top half of the
  head flaps up/down when the character talks/shouts. Placeholder draw
  code implements the flap + beady eyes; no South Park art is copied.]
- **Build order (Vee approved 2026-10-29):** Gate 0 greybox in Godot —
  engine with placeholder assets first, then simulator, asset spec,
  one vertical-slice asset set, then bulk assets. Her words: "You can
  start Gate Zero"

## Blank — not decided

- **Engine:** Godot 4 — *in use for Gate 0 at Vee's "start Gate Zero"
  go-ahead on the Godot greybox option presented to her (2026-10-29);
  not separately re-named by her in words.*
- **Setting / city name & era:** ______ (HTML uses a generic 3600-unit
  grid city, no named setting)
- **Player character:** ______ (HTML is an unnamed green circle)
- **Platform target:** ______ (HTML ran mobile + desktop; engine export
  target not yet stated)

## Gate 3D-0 status (2026-10-29, verified)

- Built in `engine/gate3d/`: third-person 3D city (5x5 seeded blocks,
  seed 2004), roads, fog density 0.012, camera far 160, player + 8
  peds (all flap-heads), 4 box cars, E to enter/drive/exit.
- Verified headless, Godot 4.3: 600 frames, **zero script errors**.
  Two catches from verification, both handled: (1) pre-tree
  `global_position` sets on Node3D error and are dropped — switched
  to local `position`, errors went to zero; (2) 152 "mesh is null"
  errors in the log are a headless dummy-renderer artifact — a probe
  project with a single BoxMesh and nothing else reproduces them
  exactly, so they are not this project's code.
- The 3D visuals / flap readability are [unverified] — headless has
  no pixels; Vee running it windowed is the check.
- **VISUALLY VERIFIED BY VEE, 2026-10-30** (her words, from running
  the exported Linux build on iwantitnow): "it works and they talk
  and the car drives and the people are there and theyre southpark
  canadian cube heads." Linux build: single-file GODOT.x86_64
  export, hash-verified on both ends of the SSH transfer
  (e61e1285…f545), lives at ~/GODOT-Linux/ on her laptop and as a
  zip attached in this chat. Gate 3D-0 is DONE on every surface:
  headless logic + real screen + real hardware.

## Gate 3D-1 status (2026-10-30, built + verified headless)

- Gate 3D-0's scene, extended in `engine/gate3d/`: all 9 weapons
  (camera-ray hitscan + tracer/flash, ROCKET as an explosive
  projectile, drive-by with the in-car cooldown ticking — HTML bug
  fix #2), the wanted system (float + floor lookups — fix #1; caps
  [0,3,6,10,15,22,30]; cop/SWAT/military flap-heads, tank as an
  armoured box vehicle), and the cash/combo economy (data payouts ×
  combo multiplier, 120-frame window, 30% pickup gate: cash gold
  +$15 / health green +30 / weapon white). Player HP, damage,
  BUSTED → fresh run. HUD: HP bar, weapon, cash/score, stars,
  combo. All numbers from `data/*.json`; rules mirror the 2D
  `engine/scripts/main.gd`. 3D adaptations (distance ÷15, speed
  ratio 5.0/3.8, weapon pickups new) labelled in
  `engine/gate3d/README.md`.
- Verified on this VM, Godot 4.3 headless: import clean; main scene
  1200 frames, **zero script errors** (153 "Parameter m is null"
  dummy-renderer artifact lines, same as Gate 3D-0); scripted
  `--autotest` prints AUTOTEST PASS (SMG ped kill pays exactly
  $10/+20 score, cop damage+kill, wanted 1.4 → 1 star/cap 3, forced
  spawns stop at cap, spawn types SWAT@3/tank@6, drive-by cooldown
  ticks in-car). Linux export (66,162,048-byte single file, zip
  `builds/GODOT-Linux-Gate3D1.zip` 24,156,352 bytes) ran 300 frames
  clean and PASSES the autotest inside the export.
- Gate 3D-1 visuals / game feel are [unverified] — only Vee running
  the new build windowed on iwantitnow can judge them.

## Gate 3D-2 status (2026-10-30, built + verified headless; Xvfb visual check done)

- Vee's go, verbatim: "work while i am gone build out everything we
  need deck out this scaffolding and replace the grey boxes."
- **Procedural dressing only** — hard constraint, recorded: the
  GitHub snapshot push accepts UTF-8 text only, so binary model
  files (.glb/.fbx) cannot be pushed; ALL visuals are generated in
  GDScript (meshes, materials, code-made textures via Image /
  ImageTexture). No asset packs downloaded. New: `gate3d/dressing.gd`.
  Buildings: 1–3 per cluster with varied footprints/heights,
  generated window-grid facades (some windows lit), roof parapets,
  storefront band + awning, rooftop AC/antennas/water towers.
  Roads: asphalt texture, pavement pads, dashed lane markings +
  centre-intersection crosswalks (MultiMesh). Props via MultiMesh:
  streetlights (emissive heads), traffic lights, trees, crates,
  barriers; dumpsters + benches as nodes. Procedural sky + sky
  ambient; fog 0.012 / far 160 unchanged.
- **Cars dressed**: body + glass cabin + roof, bumpers, hubcaps,
  front wheels steer / all wheels roll, emissive head/taillights,
  wider paint palette (6 cars now). Tank: olive, turret + barrel
  (existing) + skirts, hatch, antenna, storage boxes.
- **Characters**: Canadian cube flap-heads EXACTLY as before (Vee's
  stipulation — hinge + beady eyes untouched). Bodies dressed:
  varied shirt/pants colours; cop + military caps riding the upper
  head.
- **Systems completed**: Black Market upgrades (all 5 from
  `data/upgrades.json`, cost `floor(base × 1.4^level)`, B panel,
  keys/buttons, effects live: max HP / speed / damage mult /
  fire-rate mult / regen per the data's rule — wanted == 0 only);
  save/load `user://godot_save.json` — **rule: cash, total score,
  upgrade levels and unlocked weapons persist across BUSTED; only
  the run (wanted/enemies/position) resets**; autosave on purchase,
  every 1800 frames, on BUSTED. Synthesized SFX (`gate3d/sfx.gd`,
  generated AudioStreamWAV: gunshot, explosion, pickup, hurt,
  BUSTED sting) — **engine hum CUT explicitly** (looped synth hum =
  fridge drone; recorded in the gate README). Minimap
  (`gate3d/minimap.gd`, `_draw`, no SubViewport): grid + player +
  enemy + car dots.
- Verified on this VM, Godot 4.3 headless: import clean; main scene
  1200 frames, **zero script errors** (401 "Parameter m is null"
  dummy-renderer artifact lines — up from 153 because there are
  more meshes; same known artifact). `--autotest` prints BOTH PASS
  lines: the Gate 3D-1 line (unchanged) plus
  `AUTOTEST PASS: upgrade_purchase cost_scaling effects |
  save_load_roundtrip` (hp cost 150→210, max HP 100→125, damage
  ×1.15, fire rate ×1.10, broke-buy refused, save/scramble/load
  restores). Shop panel also exercised live under Xvfb (opens
  paused, purchase applies, closes). Xvfb screenshot check: dressed
  city renders (lit windows, crosswalks — thinned after the check —
  traffic light, trees, minimap live). Perf: 714 nodes total, 622
  prop instances in ~13 MultiMesh draw calls.
- Linux export (66,192,368 bytes, sha256 27e42120…e53): 300 frames
  clean, both autotest lines PASS inside the export. Zip
  `builds/GODOT-Linux-Gate3D2.zip` (24,282,126 bytes).
- **VISUALLY VERIFIED BY VEE, 2026-10-30**: she uploaded two
  screenshots from live play on iwantitnow — dressed street view
  (facades, lit windows, minimap live, HUD $125 / Score 160, MINIGUN
  equipped) and the BLACK MARKET panel open with all 5 upgrades at
  data prices. Gate 3D-2 is done on every surface.
- **Gate 3D-2 walk fix (2026-10-30, from Vee's playtest report):**
  she reported WASD steering fine in a car but broken for walking.
  Root cause: `player3d.gd` moved on WORLD axes and ignored
  `cam_yaw`, so W always walked world-north while the follow camera
  swung around. Fix: on-foot movement is now camera-relative
  (forward = `Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))`, right =
  forward × up; identical to the old axes at yaw 0), driving /
  firing / speeds untouched. Autotest section 7 added via a
  `move_override` seam on Player3D — new PASS line
  `AUTOTEST PASS: wasd_camera_relative`, both prior lines still
  verbatim, in project and exported binary; 1200 frames headless
  zero script errors. New export 66,193,968 bytes, sha256
  b43e6d14…e0de, zip `builds/GODOT-Linux-Gate3D2-walkfix.zip`.
  Walking feel **VERIFIED BY VEE, 2026-10-31** (her words, from
  the Detail 1 playtest): "walking is a lot better." Label closed.

## Engine Core gate status (2026-10-30, built + verified headless)

- Direction (Vee, 2026-10-30): master the engine before detail
  work, so it can be quick-ported to other games as their engine.
  Plan: `design/ENGINE_CORE_PLAN.md`. The engine's name slot stays
  BLANK (Vee's call).
- Done: the reusable systems were extracted from the 1,562-line
  `gate3d_main.gd` into `engine/core/` — `gate3d_main.gd` is now
  1,183 lines of wiring + G.O.D.O.T-specific rules. Modules:
  data_loader, save_game, sfx_synth, economy, upgrades, wanted,
  combat, controller, follow_camera, hud_kit, minimap, flap_rig
  (was flappy_person3d), city_dressing + city_builder. Guide:
  `engine/core/README.md`; full module map + labelled deviations
  (no `game/` folder split, spawn/combat split at selection vs
  consequences, city layout constants as the known seam) in
  `engine/gate3d/README.md`.
- Contract held: extracted one module per step, full autotest
  after every step — all three AUTOTEST PASS lines verbatim at
  every step, and again in the final exported binary. One latent
  bug found + fixed en route (freed shooter passed through a
  typed Object parameter in Combat's projectile resolution).
- PORT TEST PASSED: `engine/smoketest/` (throwaway fixture, own
  data: 1 weapon, 1 enemy, different upgrade costs) boots only
  `core/` and prints SMOKETEST PASS for move / shoot / buy (+
  wanted/save/flap/sfx bonus line), headless, exit 0.
- Final verification (2026-10-30): import clean; main scene 1200
  frames headless, zero script errors (401 "Parameter m is null"
  artifact lines, identical to the pre-gate baseline); all three
  AUTOTEST PASS lines in project AND in the exported binary
  (which also ran 300 frames clean). Linux export 66,222,912
  bytes, sha256 9b509c13…2fec, zip
  `builds/GODOT-Linux-EngineCore.zip`. Game feel unchanged by
  construction — this gate moved code, it did not tune anything.

## Detail Pass 1 status (2026-10-31, built + verified headless/Xvfb)

- Spec: `design/DETAIL1_SPEC.md` ("The street feels inhabited");
  plan/tasks: `design/DETAIL1_PLAN.md`; built under
  `design/METHOD.md` (TDD: red recorded → green per task →
  refactor → validate/review). Gate section:
  `engine/gate3d/README.md`.
- Done: walk cycles on flap-rig characters (pivots at hips/
  shoulders, phase from distance, settles when stopped; head/
  hinge proportions untouched), 3 car silhouettes × 10 paints
  (collision unchanged), ~20 emissive storefront signs with
  generated textures + a unique facade seed and lit-window
  ratio per building, and street-clutter density at 2.13× the
  Gate 3D-2 baseline (≈1,320 MultiMesh instances, 796 nodes <
  900 budget) — all new clutter is MultiMesh, props still
  non-colliding.
- Contract: new line `AUTOTEST PASS: detail1 walk_cycle
  car_variants signage density_budget` joins the three existing
  lines; all four pass in the project AND the exported binary;
  smoketest's four lines unchanged. RED evidence (12 FAIL lines
  before implementation) is quoted in the README gate section.
- Xvfb screenshot framed on sign #1 pixel-checked: its violet
  accent (C77DFF) present at ≈6,100 pixels, glyph bars + panel
  confirmed. 1200-frame run: zero script errors.
- Linux export 66,236,736 bytes, sha256 73308054…ec26, zip
  `builds/GODOT-Linux-Detail1.zip`. **Visual quality on real
  hardware (iwantitnow): [unverified]** until Vee runs it.
- **Playtest result (Vee, iwantitnow, 2026-10-31): game works,
  walking "a lot better" — and a BUG: "The markings for the road
  are on the sidewalks."** Root cause: the 40×40 block pads are
  centred on the same grid points as the road strips and their
  tops (y = 0.10) sat above the asphalt tops (y = 0.045), so the
  pads paved over the roads at every cluster and the markings
  painted the pads. **FIXED same day (TDD):** new autotest
  segment `markings_on_roads` went RED first (330 of 390 dashes
  + all 20 crosswalk stripes off asphalt), road strips raised
  (asphalt top 0.115 > pad top 0.10) and crosswalk stripes
  re-seated (y 0.132) — GREEN, full suite + smoketest green,
  Xvfb pixel check: 0 marking-coloured pixels on pavement,
  neighbours' median luminance 0.245 = asphalt. Build:
  66,240,112 bytes, sha256 51abed46…4ebd, zip
  `builds/GODOT-Linux-Detail1-markfix.zip`. Markings look on
  real hardware: [unverified] until Vee runs the markfix build.
  Full record: README "Detail 1 fix: markings".

## Playtest Telemetry status (2026-11-01, built + verified; Vee's request)

- Vee's words: "add a live debug log and screenshot/parser
  for when I play so you can see all the things that break
  or work." Done under METHOD.md (spec
  `design/TELEMETRY_SPEC.md`, plan `design/TELEMETRY_PLAN.md`,
  red runs recorded in the README gate section).
- `core/debug_log.gd` (DebugLog, engine core): every run
  writes `session-<timestamp>.log` (header, 0.5 s state
  snapshots, events: BUSTED / WANTED / UPGRADE / CAR_ENTER /
  CAR_EXIT / PICKUP) + `frame-<t>.png` screenshots every
  20 s, on BUSTED, and on **F9** (MARKER + forced frame),
  capped at 90 frames. Local files only, no network.
- Parser `tools/playtest_digest.py` (repo root, not in the
  export): Markdown digest with anomalies (on-foot jump
  > 25 u, y outside [−5, 30], fps < 20 for ≥ 3 s, NaN) and
  nearest-frame lookup per marker/anomaly. Self-test:
  planted session flags exactly its 4 planted anomalies,
  clean session flags none.
- Contract: new lines `AUTOTEST PASS: telemetry_log …` and
  `SMOKETEST PASS: telemetry debug_log` join the existing
  five + four, all green in project AND export. Validated
  on a real 95 s Xvfb session (158 snapshots, real frames
  pixel-checked, digest's one fps anomaly = this VM's
  llvmpipe software rendering, labelled as such in the
  README). Build: 66,246,816 bytes, sha256 a46fbc2…121e15,
  zip `builds/GODOT-Linux-Telemetry.zip`. Feel in a real
  play session on iwantitnow: [unverified] until Vee plays
  it and a session is fetched.
- **Fetch/digest workflow (3 lines):** sessions land in
  `~/.local/share/godot/app_userdata/G.O.D.O.T - Grand Ol
  Dilly-Dallies Of Transportation/playtest/` on the
  player's machine → Hexe pulls the session dir over SSH
  when Vee says a session happened → digest + frames are
  reviewed in this HQ chat (`python3 tools/playtest_digest.py
  <session-dir>`).

## Wanted pacing fix status (2026-11-01, built + verified headless)

- **Playtest bug (Vee, iwantitnow): "ive killed a lot of ped in
  the game and have not gotten a single star nor have i seen
  any policia."** Root cause, in the ported numbers: kill_ped
  paid the HTML's +0.15 (7 kills per star) while decay removed
  a FULL 1.0 star after 600 crime-free frames — in 3D, kills
  are minutes apart, so wanted never accumulated. Older
  autotests injected `add_wanted(1.4)` and never tested a
  realistic kill chain; that gap is now closed.
- **Fix (TDD, red first):** new autotest section 11 went RED
  with the real numbers (3 kills 300 frames apart → level
  0.45, 0 stars, no spawn; decay 1.20 → 0.20). Gains moved to
  a live `wanted.gains` block in the data (kill_ped 0.35,
  kill_ped_runover 0.35, destroy_car 0.3, kill_enemy 0.1) and
  decay is now a partial `decay_step` 0.25 (core `Wanted`
  default stays 1.0 — smoketest lines verbatim). Caps, spawn
  types, decay_frames 600 unchanged; `gains_in_html` untouched
  as the historical record. New line `AUTOTEST PASS:
  wanted_pacing ped_chain_star cop_spawn decay_partial` —
  seventh AUTOTEST line, green in project AND export; 1200
  frames zero script errors. Full record: README "Wanted
  pacing fix".
- Build: 66,248,064 bytes, sha256 a5fd3b21…f55, zip
  `builds/GODOT-Linux-WantedFix.zip`. A real-hardware policia
  sighting at a satisfying pace is **[unverified]** until Vee
  plays this build.

## Fall fix + telemetry hardening status (2026-11-01, built + verified headless/Xvfb)

- **Playtest bug (Vee's first LIVE telemetry sessions):** she
  drove east past x=120 — where the ground slab ends — and
  fell to y=-771, exiting the car mid-fall (archived session
  `session-20261101-094432.log`, t≈44.6–55.5). No boundary,
  no kill-plane. Her amendment to the fix, verbatim: "bonk
  should send you flying like old mx vs atv logic."
- **Fix (TDD, red first — 12 game FAILs, 2 naming FAILs,
  4 parser FAILs recorded in README "Fall fix"):** invisible
  CityBuilder walls at ±WORLD_HALF (nodes 796 → 801, budget
  intact); kill-plane respawn at y=-20 to the nearest
  building-clear road point, car + player together, NO
  penalty (none specified, none invented), `RESPAWN` event;
  edge **bonk**: impact ≥ 6 u/s reflects ×1.2 + 7.0 up-pop
  via body-owned launch state, `BONK` event, slow contact
  just blocks. Tuning in the data's new `edge` block.
  Telemetry hardening: frame files are session-stamped
  (`frame-<stamp>-<t>.png`, parser reads old names too) and
  the digest groups consecutive same-rule anomalies — the
  archived fall re-digests as ONE entry, ×22.
- New line `AUTOTEST PASS: fall_respawn kill_plane_foot
  kill_plane_car bonk_launch bonk_slow_block` — eighth
  AUTOTEST line, green in project AND export, all prior
  lines verbatim; 1200 frames zero script errors; Xvfb
  screenshot visually unchanged. Build: 66,257,984 bytes,
  sha256 f6c7c58c…916, zip `builds/GODOT-Linux-FallFix.zip`.
  Real-hardware edge behaviour is **[unverified]** until
  Vee drives off a cliff again.

## Gate 0 status (2026-10-29, verified)

- Built in `engine/` (Godot 4.3): main/city/player/car/ped/enemy/bullet/
  pickup/HUD, data loaded from `engine/data/*.json`.
- Verified on the real surface, this VM, Godot 4.3.stable headless:
  simulator ran and printed PASS on fractional-wanted indexing plus
  combat/economy tables; the game itself ran 1200 frames with zero
  script errors after a one-time `--import` (builds the class cache).
  One parse fix was needed and made during verification (simulator
  type inference). Greybox visuals themselves are [unverified] — only
  Vee running it windowed can confirm the flap-head look reads right.
- Simulator caveat: shotgun time-to-kill counts one pellet per shot,
  the weapon fires 6 — its sim TTK is an overestimate by design of the
  simplification, noted here so nobody quotes it as exact.

## Settled in the HTML itself (receipt: code Vee pasted)

- Top-down, single player, start on foot in city centre
- Steal/drive any car, drive-by shooting, run over peds
- Wanted 0–6 stars, decays after 600 frames idle, cops→SWAT→military→tank
- 9 weapons, 5 Black Market upgrades, cash/score/combo, local save
