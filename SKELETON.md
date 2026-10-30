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
  Walking feel **[unverified]** until Vee walks it on iwantitnow.

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
