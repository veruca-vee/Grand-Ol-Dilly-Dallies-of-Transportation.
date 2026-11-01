# Gate 3D — PS2-era city (was: greybox)

Run it (from the `engine/` folder):

```
godot --path . res://gate3d/Gate3D.tscn
```

**Controls:** WASD move / drive · mouse aims (camera-centre ray) ·
**LMB** fire · **1–9** select weapon, **Q** cycles · **E** enter/exit
car · **B** Black Market upgrades · hold **T** to talk and watch
the head flap. Peds talk to themselves at random — same flap.
Fleeing peds and firing characters flap too.

## The PS2 brief, as built here

- Low-poly everything, all of it generated in code (Gate 3D-2)
- Camera far plane 160 + exponential fog (density 0.012) — the draw
  distance *is* the period look, like San Andreas at launch
- One directional light + procedural sky, hazy horizon
- Seeded city: 5×5 blocks, seed 2004, road pitch 52

## The Canadian look in 3D

`flappy_person3d.gd`: head split at the mouth line; the upper head
(beady eyes on it, close-set black spheres) hangs on a hinge pivot at
the back of the jaw and rotates open while talking. Max opening
0.55 rad. That's the 2D flap translated to a 3D hinge.

**Visually verified by Vee, 2026-10-30** (Gate 3D-0 build, running on
her laptop): "it works and they talk and the car drives and the
people are there and theyre southpark canadian cube heads."

## Gate 3D-1 — systems ported from Gate 0 (2026-10-30)

Gate 3D-0 proved world + third-person + driving + flap-heads.
Gate 3D-1 ports the actual game systems from the 2D prototype
(`engine/scripts/`) into this scene. All balance numbers load from
`res://data/*.json` (the HTML's numbers, copied exactly); the rules
mirror `scripts/main.gd`, including its two HTML bug fixes:

1. **Wanted is a float.** Gains are fractional (kill enemy +0.1,
   kill ped +0.15, destroy car +0.3); every star/cap/spawn-type
   lookup uses `floori(wanted_level)`. The HTML indexed its arrays
   with the float and got `undefined`.
2. **The fire cooldown ticks every physics frame, on foot and
   in-car.** The HTML set the drive-by cooldown but never ticked it
   in-car, so drive-by fired exactly once.

What's in:

- **All 9 weapons** (FISTS, PISTOL, SHOTGUN ×6 pellets, SMG, ASSAULT,
  SNIPER, MINIGUN, ROCKET, LASER) with the data's damage, fire-rate
  (in 60 Hz frames), range, spread, melee/rocket flags. Non-rocket
  weapons are hitscan from the camera-centre ray (what the crosshair
  points at decides the aim point; the shot is then traced from the
  gun), with tracer + muzzle-flash visuals. ROCKET fires a visible
  projectile that explodes with the 2D radius-damage rules.
  Drive-by uses the data's separate drive-by weapon (dmg 12,
  rate 8 frames) while driving.
- **Wanted system**: star HUD, decay of 1 star after 600 crime-free
  frames, spawn caps `[0,3,6,10,15,22,30]`, per-frame spawn roll
  `0.02 + stars×0.005`, spawn types by star (cop, cop, SWAT, SWAT,
  military, tank) with their data stats. Cops/SWAT/military are
  flap-heads who chase to 60% of their range, then shoot (projectile
  bullets, enemy damage halved against the player as in 2D); the
  tank is a slow armoured box vehicle with a turret. Enemies flap
  while firing.
- **Cash / combo economy**: kills pay per the data (ped $10, run-over
  $15, car $25, cop $20, SWAT $40, military $20, tank $100) times the
  combo multiplier `min(5, 1 + combo×0.5)` with the 120-frame combo
  window; score likewise. Kills drop pickups through the HTML's 30%
  spawn gate: **cash** (gold, +$15), **health** (green, +30 HP),
  **weapon** (white, grants a random weapon — see adaptations).
  Cars have 100 HP, can be destroyed (explosion, +wanted), and the
  driven car runs peds over.
- **Player HP / BUSTED**: enemy fire and explosions damage the
  player; death shows BUSTED with score/cash and reloads a fresh run
  (cash/score/wanted/enemies cleared), as in Gate 0.
- **HUD**: HP bar, weapon name, cash + score, wanted stars, combo
  indicator, crosshair. Midnight Circle accents (violet HP fill,
  gold cash/stars, ember BUSTED).

### 3D adaptations (labelled, not silent)

The 2D world is 3600 units across; the 3D city is 240. Where 3D
forced a change from the 2D numbers, this is what was done:

- **Distances and radii ÷ 15** (the world scale): weapon ranges,
  enemy ranges, explosion radii, bullet hit distances, melee reach,
  ped flee radius (150 → 10), spawn ring (500–900 → 42–64, pushed
  slightly inward so spawns fit the smaller city; buildings avoided).
- **Speeds scaled by the player-speed ratio 5.0 / 3.8** so chases
  keep the 2D proportions (cop 1.8 → 2.4, SWAT 2.2 → 2.9, tank
  1.5 → 2.0, ped walk 0.6–1.3 → 0.8–1.7, ped flee 2.5 → 3.3).
  Enemy bullet speed 72 u/s and rocket speed 40 u/s chosen so the
  data's frame-based bullet lifetimes cover the data's ranges.
- **Hitscan instead of projectiles** for player guns (brief: shoot
  from the camera-centre ray). Enemy fire and the player ROCKET
  stay projectiles, as in 2D. Frame-based timers (fire rates,
  combo window 120, decay 600) are counted in 60 Hz physics frames.
- **Weapon pickups are new.** The 2D code only had cash/health
  pickup kinds. In 3D-1, 25% of non-tank enemy cash drops are
  weapon pickups instead (tank still drops health, as in 2D).
- **Run-overs** are checked for the player's driven car only; in 2D
  the AI cars could also run peds over (3D greybox cars don't drive
  themselves yet).
- **Health pickup heals +30**, following `scripts/main.gd`. (An
  earlier brief said +25; the 2D code says 30, so the code won.)

## Verification (2026-10-30, this VM, Godot 4.3 headless)

- Project imports clean (after two type-inference parse fixes).
- Main scene, 1200 frames headless: **zero script errors, zero parse
  errors**, exit 0. 153 `Parameter "m" is null` lines — the known
  headless dummy-renderer artifact (an empty probe project with one
  BoxMesh reproduces it); not this project's code.
- **Autotest** (`godot --headless --path . -- --autotest`): drives
  the real fire/spawn/economy code — SMG kills a ped (cash +10,
  score +20, combo increments), SMG damages then kills a cop,
  wanted 1.4 floors to 1 star with cap 3, forced spawns stop at the
  cap and are all cops, spawn types at 3/6 stars are SWAT/tank,
  drive-by cooldown ticks down while in a car and resets to 8 on
  fire. Output: `AUTOTEST PASS: smg_ped_kill cash+score+combo |
  smg_cop_damage+kill | wanted_floor caps spawn_types |
  driveby_cooldown_ticks`, exit 0.
- Linux export (`builds/GODOT-Linux/GODOT.x86_64`, 66,162,048
  bytes): the exported binary itself ran 300 frames headless with
  zero script errors, and the autotest PASSES inside the export too.
  Zipped as `builds/GODOT-Linux-Gate3D1.zip` (24,156,352 bytes).
- Gate 3D-1 visuals/game feel are **[unverified]** — headless has no
  pixels; Vee running the new build windowed is the check.

## Gate 3D-2 — decked out (2026-10-30)

Vee's brief: "build out everything we need, deck out this
scaffolding and replace the grey boxes." Two hard constraints shaped
it: the Canadian cube flap-heads stay exactly as they are (her
stipulation), and **no binary assets** — the repo's GitHub push
route accepts UTF-8 text only, so .glb/.fbx packs can't live in the
repo. Everything visual is therefore **procedural**: meshes,
materials and textures generated in GDScript at startup
(`dressing.gd`), licence-clean and reproducible from seed 2004.

### City dressing

- **Buildings**: 1–3 per grid cluster (~48), varied footprints
  (12–20) and heights (6–28). Facades use code-generated window-grid
  textures (6 variants of muted PS2 brick/tan/slate; ~28% of windows
  lit warm) with per-building UV scale so windows stay one size.
  Roof slab parapet, dark storefront band + coloured awning on most,
  concrete pavement pad under each cluster (the pad edge is the
  curb). Rooftop props: AC units and antennas (MultiMesh), a few
  water towers (legs + cylinder tank + cone roof).
- **Roads**: asphalt noise texture, dashed centre lines down every
  road (one MultiMesh, ~390 instances), zebra crosswalks at the
  centre intersection — the only one not built over by clusters in
  this layout, as in 3D-0/1. Ground slab is noise-textured concrete.
- **Props, mostly MultiMesh** (622 instances across ~13 draw calls):
  streetlights with emissive lamp heads along the roads, traffic
  lights at the inner 3×3 intersections (red/green lenses by parity),
  low-poly trees on cluster corners, crates and barriers scattered
  on the pads; dumpsters and bus-stop benches as individual nodes.
  Props have no collision (labelled: only buildings/ground do, as
  before — driving through a lamp post is possible and unpenalised).
- **Sky/lighting**: ProceduralSkyMaterial (hazy blue → warm smog
  horizon), ambient from the sky, same sun, same fog 0.012 / far 160.
- **Cars**: dressed bodies — paint lower body + trim, glass cabin,
  paint roof, bumpers, hubcaps; front wheels visibly steer, all
  wheels roll; headlights/taillights are emissive (no real light
  sources — perf on the Celeron). Two extra paint colours (silver,
  purple) and two extra parked cars. The tank got olive armour,
  skirts, deck plate, hatch, storage boxes and an antenna.
- **Characters**: heads and the flap hinge are UNTOUCHED. Bodies got
  more shirt/pants variety; cops and military wear caps that ride
  the upper head (glued to the top half, so they flap too).

### Scaffolding / systems completion

- **Black Market (B)**: the 5 upgrades from `data/upgrades.json` —
  Body Armor (hp +25/lvl), Sprint Training (speed +0.4/lvl), Gun
  Mods (damage ×(1+0.15/lvl)), Trigger Job (fire rate
  ×(1+0.10/lvl)), Adrenaline (regen). Cost is exactly the data
  formula `floor(base_cost × 1.4^level)` — note floor() of the
  floating-point product, so level-1 Body Armor is $210 and level-2
  is $293, not $294 (same arithmetic the HTML's JS did). The panel
  pauses the game; buy with the buttons or keys 1–5. Effects are
  live: max HP, walk speed (2D increment scaled by the usual
  5.0/3.8), weapon damage (incl. drive-by and rockets), cooldowns.
  Regen follows the data file's rule as written: only while
  wanted == 0, +(0.3 × level) × 0.05 hp per physics frame.
- **Save/load** (`user://godot_save.json`). **The rule: cash, total
  score, upgrade levels and the unlocked-weapon set are the
  persistent profile.** BUSTED still resets the run (wanted,
  enemies, position) via scene reload, but the profile carries
  over. Autosaves on purchase, every 1800 physics frames (30 s),
  and on BUSTED. (Gate 3D-1 made all 9 weapons available from the
  start; the save persists that available set as `unlocked_weapons`
  and weapon pickups still record into it.)
- **Sound, synthesized** (`sfx.gd`): gunshot noise burst, explosion
  rumble, pickup chime, hurt thud, BUSTED sting — generated
  AudioStreamWAV (22050 Hz 16-bit), pooled players, modest volumes,
  throttled so chain kills don't stack booms. **Cut, explicitly:
  the car-engine hum.** A looped synthesized hum sounds like a
  fridge within seconds; not worth it. Maybe a real sample pack
  someday, licence permitting.
- **Minimap** (`minimap.gd`): bottom-right, drawn in `_draw` from
  world positions (no SubViewport) — block/road grid, car squares,
  ember enemy dots (tanks bigger), gold player dot.
- Debug helpers: `--countnodes` prints scene node + MultiMesh
  instance counts; `--screenshot` (windowed only) saves a frame to
  `user://gate3d_shot.png` and quits — used for the Xvfb visual
  check below. The autotest uses its own save path
  (`user://godot_save_autotest.json`) and deletes it afterwards, so
  testing never touches the real profile.

### Verification (2026-10-30, this VM, Godot 4.3)

- Import clean (two fixes on the way: GDScript `:=` can't infer
  from Variant values — the Gate 3D-1 lesson again — and this
  build's GDScript doesn't expose `TEXTURE_REPEAT_ENABLED` by name;
  empirically, code-generated textures tile with `uv1_scale` by
  default here, proven with a rendered red/green checker under
  Xvfb before relying on it).
- Main scene, 1200 frames headless: exit 0, **zero script errors,
  zero parse errors**, zero other ERROR lines; 401 `Parameter "m"
  is null` lines — the known dummy-renderer artifact, count up from
  153 only because there are more meshes now; not chased.
- **Autotest** (project AND exported binary, identical output):
  `AUTOTEST PASS: smg_ped_kill cash+score+combo | smg_cop_damage+kill
  | wanted_floor caps spawn_types | driveby_cooldown_ticks` and the
  new `AUTOTEST PASS: upgrade_purchase cost_scaling effects |
  save_load_roundtrip` (hp cost 150 → 210 across a purchase, max HP
  100 → 125, damage ×1.15, fire rate ×1.10, broke purchase refused,
  save → scramble → load restores cash/score/levels/unlocks).
- Black Market panel exercised live under Xvfb: opens visible +
  tree paused, button purchase applies (cash 500 → 350, max HP
  125), closes unpaused.
- Visual check under Xvfb (llvmpipe): the dressed city renders —
  facades with lit windows, crosswalks, traffic light, trees,
  dressed red car, minimap with live dots. One fix from that check:
  crosswalk stripes thinned from 0.10 to 0.03 (they read as slabs,
  now they read as paint).
- **Perf sanity**: 714 nodes total in the dressed scene; 622 prop
  instances ride ~13 MultiMesh draw calls instead of ~600 nodes.
  Buildings are ~48 static bodies as before in kind. No per-frame
  allocations added beyond the minimap's redraw. Should hold up on
  the UHD 600 / N4000; real-hardware feel is Vee's check.
- Linux export: `builds/GODOT-Linux/GODOT.x86_64`, 66,192,368
  bytes, sha256 `27e4212013ae3d2114d1a60ce035e66f6b052d4844dea47b6ed571fb5d36fe53`;
  exported binary ran 300 frames headless, zero script errors, and
  PASSES both autotest lines. Zipped as
  `builds/GODOT-Linux-Gate3D2.zip` (24,282,126 bytes).
- Gate 3D-2 visuals/game feel on real hardware are **[unverified]**
  — the Xvfb frame is software-rendered; Vee running the build on
  iwantitnow is the check, as always.

## Gate 3D-2 walk fix (2026-10-30, from Vee's playtest)

**Report (Vee, playing Gate 3D-2 on iwantitnow):** "WASD works with
steering in vehicle but it doesn't work for walking, it's annoying
as hell to walk around."

**Root cause:** `player3d.gd` built on-foot movement on WORLD axes
(W = world −Z, A = world −X) and never read `cam_yaw`. The follow
camera swings behind the actor and mouse aim fires along the camera
ray, so on foot W always walked world-north whatever the camera was
looking at, and the camera then rotated around behind the new
heading. Driving steers relative to the car, so it felt right —
the mismatch was the bug.

**Fix:** movement is now camera-relative. Input is read as a 2D
vector (x = strafe D−A, y = forward W−S), then
`forward = Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))` (the negation
of the follow-cam's `back` vector in `gate3d_main.gd`),
`right = forward.cross(Vector3.UP)` — at cam_yaw 0 that gives
forward (0,0,−1), right (1,0,0), identical to the old axes — and
`dir = (forward*y + right*x).normalized()`. `cam_yaw` is read from
the player's `main` reference each physics frame, falling back to
yaw 0 (= old world axes) if unavailable. Nothing else changed:
driving input, firing facing (`rotation.y = cam_yaw`), gravity,
walk speed and the Sprint Training multiplier path, flap/talk.

**Test seam:** `Player3D.move_override` (Vector2, default
`Vector2(NAN, NAN)` = unset). When set, it replaces the key reads
so headless tests can walk. Normal play never sets it.

**Verification (2026-10-30, this VM, Godot 4.3):** import clean;
main scene 1200 frames headless, exit 0, zero script/parse errors
(401 "Parameter m is null" artifact lines, counted, not chased).
Autotest gained section 7 — camera yaw forced to −PI/2 (forward =
+X), 30 frames of `move_override` forward must displace along +X
(dot > 0.8) and NOT along world −Z (dot < 0.3), plus a strafe-right
check along camera right. New third line, project and exported
binary identical, alongside the two existing lines verbatim:
`AUTOTEST PASS: wasd_camera_relative`. Linux export:
`builds/GODOT-Linux/GODOT.x86_64`, 66,193,968 bytes, sha256
`b43e6d144a8225b60b605b02e1ad5c9c79f7944c6c15f103a79befe7d4e0e0de`;
exported binary ran 300 frames headless with zero script errors
and passes all three autotest lines. Zipped as
`builds/GODOT-Linux-Gate3D2-walkfix.zip` (24,283,771 bytes).
Walking FEEL on real hardware is **[unverified]** — Vee walking it
on iwantitnow is the check, as always.
**VERDICT (2026-10-31, Vee, from the Detail 1 playtest on
iwantitnow): "walking is a lot better."** The [unverified] label
on walking feel is CLOSED.

## Engine Core gate (2026-10-30) — the engine, extracted

Vee's direction: "focus on mastering the engine bc I wanna be able
to quick port it to other games as their engine." Plan:
`design/ENGINE_CORE_PLAN.md`. The reusable systems moved out of
`gate3d_main.gd` into `engine/core/` (guide: `core/README.md`), one
module per step, the full autotest re-run after EVERY step — all
three PASS lines survived verbatim at every step, in the project
and (at the end) in the exported binary. **No behavior or numbers
changed**; the autotest is the contract and it never blinked.

`gate3d_main.gd`: **1,562 → 1,183 lines**. What remains is wiring +
truly G.O.D.O.T rules (kill-economy hooks, BUSTED, car entry/exit,
the Black Market panel, spawn placement, the autotest itself).
Game state vars (`cash`, `wanted_level`, `cam_yaw`,
`upgrade_levels`, …) are now forwarding properties onto the core
modules, so game code and the autotest kept their old names.

Where things live now:

| Was (in gate3d/) | Now (in core/) |
|---|---|
| `sfx.gd` | `sfx_synth.gd` (`SfxSynth`, moved as-is) |
| save/load I/O in main | `save_game.gd` (`SaveGame`) |
| `scripts/game_data.gd` calls | `data_loader.gd` (`DataLoader`) — the 2D prototype keeps its own loader |
| upgrades + combo/cash in main | `upgrades.gd` (`Upgrades`), `economy.gd` (`Economy`) |
| wanted tables + spawn policy in main | `wanted.gd` (`Wanted`) — placement/instantiation stay in main |
| shooting math in main | `combat.gd` (`Combat`) — hit selection in core, consequences in main |
| WASD math in `player3d.gd`/`car3d.gd` | `controller.gd` (`Controller`); camera rig in `follow_camera.gd` (`FollowCamera`) |
| HUD builders in main, `minimap.gd` | `hud_kit.gd` (`HudKit`), `minimap.gd` (`Minimap`, constants now config with G.O.D.O.T defaults) |
| `flappy_person3d.gd` | `flap_rig.gd` (class renamed `FlapRig`; player/ped/enemy extend it) |
| city build in main, `dressing.gd` | `city_builder.gd` (`CityBuilder`) + `city_dressing.gd` (`CityDressing`) |

Deviations from the plan's target shape, with reasons:

- **No `engine/game/` folder split.** Gate3D.tscn, the data files
  and the leaf scripts kept their paths; only `core/` is new. The
  plan's deliverable was the extraction, not path cosmetics, and
  moving the scene/data would have risked the export for no
  portability gain — a new game copies `core/`, not the game layer.
- **Spawn director split in two.** `Wanted` owns the policy (caps,
  tables, decay, spawn roll); `_spawn_position`/`_spawn_enemy` stay
  in the game layer because they need the scene tree, the city's
  building footprints and the game's enemy classes.
- **Combat is selection, not consequences.** Hitscan/melee/
  projectile *resolution* (what was hit, in the source's order)
  lives in `Combat`; damage calls, kill economy and explosion
  chaining stay in the game layer, where the kill rules live.
- **Hitscan pellets are all raycast before hits are applied**
  (previously interleaved per pellet). No observable rule change:
  every hit handler is dead-guarded (`kill_ped`, `take_damage`,
  car damage all no-op on a dead target), so a pellet that would
  have passed through a fresh corpse now lands on it and is
  ignored there. The autotest's combat sections are single-shot
  weapons and are unaffected.
- **CityBuilder's layout is constants, not config** (52 pitch, 240
  extent, seed 2004). The plan's rule was "no hardcoded G.O.D.O.T
  *gameplay* numbers in core"; the city layout algorithm is the
  reusable part, and parameterizing the layout before a second
  game exists to vary it would be guessing. Noted in the class
  header as the known seam.
- **The SFX playback pool stayed in the game layer** (10
  AudioStreamPlayers on the Master bus is wiring); the synthesis
  itself is `core/sfx_synth.gd`.

One real bug found and fixed en route (step 10 exposed it, it was
latent since step 6): `Combat.resolve_projectile` took the shooter
as a typed `Object` parameter — a projectile can outlive its
shooter (an enemy dies with a bullet in flight), and passing a
freed instance through a typed Object parameter is a hard script
error. The old inline code only ever *compared* against the
shooter. The parameter is now `Variant`, with the reason recorded
in `core/combat.gd`.

### Port test (the gate's finish line)

`engine/smoketest/` — a throwaway fixture game (NOT shipped): its
own scene + main script + its own data (1 weapon "TEST BLASTER"
dmg 25, 1 enemy type "bot", a 3-star wanted table, upgrade cost
333 that matches nothing in G.O.D.O.T). It boots only `core/`
modules and prints, verbatim from the headless run:

```
SMOKETEST PASS: move camera_relative
SMOKETEST PASS: shoot damage_dealt
SMOKETEST PASS: buy upgrade_purchase
SMOKETEST PASS: wanted_floor save_roundtrip flap_rig sfx_synth
```

Run it: `godot --headless --path . res://smoketest/SmokeTest.tscn`.

### Engine Core verification (2026-10-30, this VM, Godot 4.3)

Import clean. Main scene 1200 frames headless: exit 0, **zero
script errors** (401 "Parameter m is null" artifact lines —
identical count to the pre-gate baseline). All three autotest
lines PASS in the project and in the exported binary; the exported
binary also ran 300 frames headless with zero script errors.
Smoketest: all four SMOKETEST PASS lines, exit 0 (see above).
Linux export: `builds/GODOT-Linux/GODOT.x86_64`, 66,222,912 bytes,
sha256 `9b509c13319b38b9f3d7317cbe398cb22872e35af3bdda3fe66667dc9c312fec`,
zipped as `builds/GODOT-Linux-EngineCore.zip`.

## Detail Pass 1 — "The street feels inhabited" (2026-10-31)

Spec: `design/DETAIL1_SPEC.md`. Plan + tasks:
`design/DETAIL1_PLAN.md`. Method: `design/METHOD.md` (spec →
plan → tasks → per-task TDD → validate & review). All new
behavior lives in `core/` modules per the core rules; the game
kept its numbers, data, collision shapes, and save shape.

What shipped:

1. **Walk cycle** (`core/flap_rig.gd`): legs/arms hang from hip/
   shoulder pivots (box sizes and spans unchanged); `tick_walk`
   advances `walk_phase` from planar speed (stride 2.4 rad/unit)
   with an eased blend, so limbs swing ±0.55 (legs) / ∓0.38
   (arms) while moving and settle to neutral when stopped.
   Called by Player3D/Ped3D/Enemy3D after `move_and_slide()`.
   Head, hinge pivot, eyes, cap: code untouched — proportions
   identical, guarded by autotest checks on pivot height and
   upper-head child count.
2. **Car variants** (`gate3d/car3d.gd`): 3 silhouettes (sedan =
   previous geometry verbatim, hatchback, van) from `body_style`,
   a 10-colour `PALETTE`, wheel spin ∝ speed (pre-existing,
   now contract-locked). Collision shape identical per style.
3. **Signage + facades** (`core/city_dressing.gd`,
   `core/city_builder.gd`): generated emissive sign textures
   (dark panel, accent border, blocky glyph bars) in 5 accents;
   ~20 signs mounted on storefront faces. Every building gets a
   UNIQUE facade seed and its own lit-window ratio in
   [0.08, 0.50] (spec asked for adjacent-difference; unique is
   stronger).
4. **Density**: bollards, cones, trash bags, bushes, newspaper
   boxes, cardboard — all MultiMesh — plus denser trees, crates,
   streetlights. Props remain non-colliding dressing.

### TDD evidence

Baseline before changes: nodes 714, MultiMesh instances 623 →
spec targets: instances ≥ 1246, nodes < 900.

RED (autotest section 8 written first, run before any
implementation — the 3 pre-existing contract lines all passed;
these 12 failed):

```
AUTOTEST FAIL: walk_cycle: player has no walk_phase (walk API missing)
AUTOTEST FAIL: walk_cycle: max limb swing 0.00 rad while walking, expected > 0.15
AUTOTEST FAIL: walk_cycle: swing did not settle when stopped (walk_swing=<null> after 40 idle frames)
AUTOTEST FAIL: walk_cycle: a wandering ped's walk_phase did not advance
AUTOTEST FAIL: walk_cycle: chasing enemy's walk_phase did not advance
AUTOTEST FAIL: car_variants: 0 distinct body_style values across spawned cars, expected >= 3
AUTOTEST FAIL: car_variants: cars expose no paint palette, expected >= 8 colours
AUTOTEST FAIL: signage: sign_count is <null>, expected >= 12
AUTOTEST FAIL: signage: 0 distinct sign accent colours, expected >= 4
AUTOTEST FAIL: signage: facade seed registry has none entries, expected >= 20 buildings
AUTOTEST FAIL: signage: only 0 distinct lit-window ratios, expected >= 10 (variance)
AUTOTEST FAIL: density_budget: 622 MultiMesh instances, expected >= 1246 (2x the 623 baseline)
```

GREEN (after T2–T5, and identically after the T6 refactor):

```
AUTOTEST PASS: smg_ped_kill cash+score+combo | smg_cop_damage+kill | wanted_floor caps spawn_types | driveby_cooldown_ticks
AUTOTEST PASS: upgrade_purchase cost_scaling effects | save_load_roundtrip
AUTOTEST PASS: wasd_camera_relative
AUTOTEST PASS: detail1 walk_cycle car_variants signage density_budget
```

One test-design fix, documented rather than hidden: the ped
walk check first re-enabled a parked ped from the 8-body pile
at (100,100). A probe run showed that ped depenetrating on top
of the pile (y 0.2 → 1.86, planar velocity 0) — it never walks,
so the check was testing pile physics, not the walk cycle. The
check now spawns a fresh wandering ped in open space; the
contract it verifies is unchanged.

### Validate & review (2026-10-31, this VM, Godot 4.3)

- Xvfb screenshot (1280×720) framed on sign #1 via the
  `--screenshot` debug path; PIL pixel check (every 2nd pixel):
  the sign's accent **violet C77DFF present at 1,536 sampled
  pixels** (≈6,100 actual), warm-white glyph pixels 549, void
  panel pixels 917. Sign texture structure confirmed visually
  in the data.
- Scene census: **nodes = 796** (< 900), **MultiMesh
  instances ≈ 1,320** (2.1× the 623 baseline; ±3 run to run
  from RNG prop placement).
- 1200-frame headless run: exit 0, **zero script errors** (419
  "Parameter m is null" headless artifacts, counted, same known
  artifact as prior gates).
- Smoketest: all four SMOKETEST PASS lines.
- Edge cases reviewed: **save compat** — no save fields touched;
  the save/load roundtrip contract passes unchanged, and visual
  state (car style, walk phase) is per-run/per-instance, never
  persisted. **BUSTED** — scene reload builds fresh rigs; walk
  state is instance state (no statics), and dead characters stop
  ticking (limbs freeze with the tip-over, as before).
  **Tank** — extends CharacterBody3D directly, no FlapRig, so
  the walk cycle does not touch it; spawn/drive contracts pass.
  **Firing while walking** — limb swing lives on child pivots
  (local X), the flap on the head hinge, aim on the body root;
  three independent axes, no interference by construction.
- Linux export: `builds/GODOT-Linux/GODOT.x86_64`, 66,236,736
  bytes, sha256
  `7330805412eb30348bbda4cf0825fcb4f2d0a2c809a5b473ecbaf7295208ec26`.
  In the exported binary: 300 frames clean, all four AUTOTEST
  PASS lines, all four SMOKETEST PASS lines. Zip:
  `builds/GODOT-Linux-Detail1.zip` (24,322,175 bytes, sha256
  `a39b7b14e0fc3bb5e33b3ceb765f525542f309962b9432d5e607218c302b0f34`).
- Visual quality on real hardware (iwantitnow, Celeron UHD
  600): **[unverified]** until Vee runs this build — headless
  and Xvfb checks prove structure and pixels, not game feel.

## Detail 1 fix: markings (2026-10-31, from Vee's playtest)

Vee's report, playing the Detail Pass 1 build on iwantitnow (with
screenshots): **"The markings for the road are on the sidewalks."**
Lane dashes and crosswalk stripes rendered on the light pavement
pads instead of the dark asphalt. Fixed under METHOD.md
(red → green → refactor), contract-first.

**Root cause (one sentence):** the 40×40 block pads are centred
on the same grid points as the 10-wide road strips and their tops
(y = 0.10) sat above the asphalt tops (y = 0.045), so the pads
paved over the road surface at every cluster — and the markings,
which poke above the pads (dash tops y = 0.14; crosswalk stripes
placed "0.02 proud of the intersection pad"), painted the
pavement instead of the road.

**The model (test + placement share it):** `CityBuilder` gained
layout constants (PITCH 52, ROAD_HALF 5, PAD_HALF 20, WORLD_HALF
120, ROAD_TOP_Y, PAD_TOP_Y), registries of what was actually
placed (`dash_positions`, `crosswalk_positions`, `pad_centres`),
and two pure functions: `is_asphalt(x, z)` — on a road strip AND
asphalt is the topmost surface there (where a pad overlaps a
strip, the higher top wins) — and `in_intersection_box(x, z)` —
the strips' crossing square. `CityDressing.crosswalk_stripes`
([centre, size] per stripe) is now the single source the mesh is
baked from and the registry reads. Scaffolding landed first and
was verified behaviour-neutral (suite green; census nodes 796,
instances ~1.32k as before — the count wobbles ±10 run-to-run
from global-RNG prop skips, nodes are exact).

**RED (recorded before the fix, exit 1; the four existing PASS
lines still printed verbatim above these):**
```
AUTOTEST FAIL: markings_on_roads: 330 of 390 lane dashes are not on exposed asphalt (first at (-104, 0.09, -114))
AUTOTEST FAIL: markings_on_roads: 20 of 20 crosswalk stripes are not on asphalt or an intersection box (first at (-4, 0.105, -7.6))
```

**GREEN (minimal fix, two numbers + one):** road strip centre
y 0.02 → 0.09 in `CityBuilder._build_city`, so the asphalt top
(0.115) sits above the pad tops (0.10) and the strips stay the
top surface through pad overlaps (`ROAD_TOP_Y` const updated to
match — the model function itself did not change); crosswalk
stripe centre y 0.105 → 0.132 in `CityDressing`, putting the
slabs just proud of the raised asphalt (paint ON the road).
Nothing deleted: all 390 dashes and 20 stripes remain, now on
asphalt. (Filtering dashes to the exposed gaps between pads was
rejected: it would have cut ~350 MultiMesh instances and broken
the density_budget contract, ≥ 1246.) New fifth line, project
and exported binary: `AUTOTEST PASS: markings_on_roads`.
Refactor: the road calls now use the PITCH constant like the
rest of the layout code; suite identically green after, and all
four SMOKETEST PASS lines unchanged.

**Validation:** Xvfb `--markshot` (new debug flag, sibling of
`--screenshot`: stands on the vertical road at z = 15 looking
north) — the frame shows the centreline dash and all four zebra
approaches on the dark asphalt, pavement pads bare. Pixel check
(PIL, road ROI): 5,322 marking-coloured pixels; **0 of 24,300
pixels in the pavement control region are marking-coloured**;
marking pixels' horizontal neighbours have median luminance
0.245, matching the foreground-asphalt control (0.234), not the
pavement control (0.530). 1200-frame headless run: exit 0, zero
script errors, zero parse errors (419 "Parameter m is null"
headless artifacts, counted, known).

**Export:** `builds/GODOT-Linux/GODOT.x86_64`, 66,240,112 bytes,
sha256 `51abed46193e5f726d8ec80811cc908cf9c34e3fa51fd55e6fe8519d48eb4ebd`;
exported binary: 300 frames clean, all five AUTOTEST PASS lines.
Zip: `builds/GODOT-Linux-Detail1-markfix.zip` (24,325,845 bytes,
sha256 `3fad94f82fb035592b3c9a8a26d8f71bcecfc804cfb000faee4cc253307e63b1`).
Markings look on real hardware: **[unverified]** until Vee runs
this build — same rule as always.

## Playtest Telemetry (2026-11-01, Vee's request)

Vee, mid-playtest: **"we should add a live debug log and
screenshot/parser for when I play so you can see all the things
that break or work."** Spec: `design/TELEMETRY_SPEC.md`; plan +
tasks: `design/TELEMETRY_PLAN.md`. Built under METHOD.md —
tests first, red recorded, then green, then refactor.

**What's in:**

- **`core/debug_log.gd` (`DebugLog`, engine core)** — a
  RefCounted session logger, game-agnostic like Economy/
  Wanted: the game passes a directory + build label and feeds
  it snapshot dicts and events; the logger owns the files,
  the timing and the frame rotation. Intervals/caps are
  engine defaults on the module (snapshot 0.5 s, auto-frame
  20 s, cap 90 frames) — no G.O.D.O.T numbers inside.
  Session file `session-<yyyymmdd-hhmmss>.log`: a
  `# GODOT-TELEMETRY v1 build=… godot=… started=…` header,
  then `t=<s> SNAPSHOT pos=… vy=… fps=… wanted=… in_car=…
  hp=… cash=…` lines and `t=<s> EVENT <name> k=v …` lines.
  Writes are appends on an open handle, flushed per line.
  **No network code anywhere in it.**
- **Frames** — PNG beside the log (`frame-<t>.png`), every
  20 s, on BUSTED, and on **F9** (the only control added:
  a `MARKER` event + a forced frame — "it broke right
  here"). Capture goes through a `frame_provider` Callable
  because viewport grabs are renderer-dependent: tests
  inject generated images, the game injects its viewport,
  and a null/empty image is refused — which is what makes
  headless runs safe. Past 90 frames the oldest are deleted.
- **Game wiring** (`gate3d_main.gd`) — session starts in
  `_ready` (build label `Detail1+Telemetry`; dir
  `user://playtest`, `user://playtest_autotest` under
  `--autotest`, `GODOT_TELEMETRY_DIR` env override between
  the two). `_process` builds the state dict and calls
  `tick`. Events at the existing code points, rules
  untouched: `SESSION_START`, `WANTED` (from/to/level, on
  floori change — rises AND decay), `UPGRADE` (id/level/
  cost), `CAR_ENTER`/`CAR_EXIT`, `PICKUP` (kind, +weapon
  name), `BUSTED` (+ forced frame). The HUD help line now
  ends "· F9 mark a moment".
- **Parser** — `tools/playtest_digest.py` (repo root, NOT
  in the export; stdlib-only Python): reads a session dir
  and prints a Markdown digest per session — duration,
  snapshot/event counts, tallies (pickups by kind), the
  frame index, nearest frame per marker/anomaly, and
  ANOMALIES under exactly the spec's rules: on-foot jump
  > 25 u between snapshots, y outside [−5, 30], fps < 20
  sustained ≥ 3 s, NaN anywhere.

**TDD record:**

- Parser RED (self-test written first, parser absent):
  `PARSER SELFTEST FAIL: tools/playtest_digest.py does not
  exist yet (parser not written)`, exit 1. GREEN:
  `PARSER SELFTEST PASS: planted_exact clean_zero
  marker_nearest_frame` — the planted session (jump, y,
  fps-run, NaN) flags exactly those four; the clean session
  (including a 1 s fps dip and a 30 u jump *in a car*)
  flags none. One fixture fix on the way: the self-test's
  expected snapshot count was corrected 15 → 13 (fixture
  arithmetic; the parser was right).
- Logger RED (checks written first via `load()` / `get()`
  seams, so a missing module fails as assertions, not a
  parse error; all five prior AUTOTEST lines and four
  SMOKETEST lines printed verbatim above these):
  ```
  AUTOTEST FAIL: telemetry_log: res://core/debug_log.gd is missing
  AUTOTEST FAIL: telemetry_log: game has no debug_log (telemetry not wired)
  SMOKETEST FAIL: telemetry: res://core/debug_log.gd missing
  ```
- GREEN, staged per the plan: DebugLog alone turned the
  smoketest line and the autotest unit half green (wiring
  check still red, as staged); the wiring then closed it.
  New lines, project AND exported binary:
  `AUTOTEST PASS: telemetry_log session snapshots events
  frames marker wiring` and `SMOKETEST PASS: telemetry
  debug_log`. Refactor (event call sites collapsed into a
  `_telemetry_event` helper; parser line-parsing shared)
  left the suite identically green.

**Validate & review (2026-11-01, this VM, Godot 4.3):**

- **Real session, real renderer:** 95 s Xvfb run of the
  game scene → `session-20261101-163042.log` (92.4 s of
  snapshots, 158 of them) + frames at t = 27.76 / 49.45 /
  71.14 (~20 s apart). Frame pixel check (PIL): 1280×720,
  **6,415 unique colours** in a 320×180 downscale, red
  channel σ 47.0 — a real rendered frame, not a black
  grab. The BUSTED frame from the Xvfb autotest session:
  6,491 unique colours.
- **Event proof on real code paths:** the Xvfb `--autotest`
  session file contains, in order: `SESSION_START`,
  `WANTED from=0 to=1`, `CAR_ENTER`, `CAR_EXIT`,
  `UPGRADE` ×3 (hp/damage/firerate at their real costs),
  `MARKER` (the F9 wiring check), `BUSTED cash=777
  score=4321` — telemetry watching the test play the game.
- **The digest on the real session** flags exactly one
  anomaly, and it is a true reading: `fps_sustained — fps
  < 20 for 86.1 s`. The Xvfb renderer is Mesa **llvmpipe**
  (software GL) on this VM and genuinely ran the scene at
  1–9 fps (mode 7–8). That's an artifact of the capture
  environment, not of Vee's hardware (the same build plays
  fine on her UHD 600) — and surfacing exactly this class
  of signal is the digest's job.
- 1200-frame headless run: exit 0, **zero script errors**
  (419 "Parameter m is null" artifacts, counted, known).
- **Edge cases reviewed:** *Unwritable dir* —
  `GODOT_TELEMETRY_DIR=/proc/nope/telemetry`: game runs
  120 frames clean, exactly ONE stderr line (`DebugLog:
  cannot create telemetry dir … (telemetry disabled)`),
  zero script errors; the logger is inert from then on.
  *BUSTED mid-capture* — the BUSTED frame is grabbed
  synchronously from the current viewport texture inside
  `on_player_death`, before the explosion/reload sequence;
  there is no async gap to race. *Rotation during play* —
  deletion happens inside `capture_frame` immediately
  after a successful save, oldest first; the unit contract
  exercises cap 3 (and cap 2 in the smoketest) with real
  files. *Session-name collisions* — one session per game
  run by construction (a second-resolution timestamp; two
  runs in the same second to the same dir would share a
  file — accepted, noted, not worth machinery).
  *Privacy* — files land only in the app's user dir on the
  player's machine; nothing is sent anywhere by the game.

**Export:** `builds/GODOT-Linux/GODOT.x86_64`, 66,246,816
bytes, sha256
`a46fbc23c882b7f0c0b2117465cd5468275a1aeee79093b731bd9f6123121e15`;
in the exported binary: 300 frames clean, all six AUTOTEST
PASS lines, all five SMOKETEST PASS lines. Zip:
`builds/GODOT-Linux-Telemetry.zip` (24,332,105 bytes,
sha256 `1f010a5437e05a1e99fb16eacf490f605645b88e7c2ef40a66e95740a4ff6c62`).
How it feels in a real play session on iwantitnow:
**[unverified]** until Vee plays this build and a session
gets fetched — same rule as always.

## Wanted pacing fix (2026-11-01, from Vee's playtest)

Vee, playing the telemetry build on iwantitnow: **"ive killed
a lot of ped in the game and have not gotten a single star nor
have i seen any policia."** She was right, and the numbers say
why. The system worked exactly as ported — the ported numbers
don't survive 3D pacing:

- **Gains too small for 3D spacing.** `kill_ped` paid the HTML's
  +0.15, so a star needs 7 ped kills (1.0 / 0.15). In the HTML's
  dense top-down world that's seconds of mayhem; in the 3D city
  kills are minutes apart.
- **Decay too coarse.** `Wanted.tick()` removed a FULL 1.0 star
  after 600 crime-free frames, so whatever fraction accumulated
  between spaced-out kills evaporated in one step.
- **The coverage gap:** every older autotest injected
  `add_wanted(1.4)` directly and never exercised a realistic
  kill chain — the bug lived exactly where no test looked.

**RED (autotest section 11 written first, run against the
unfixed code; all six prior PASS lines printed verbatim above
these, exit 1):**
```
AUTOTEST FAIL: wanted_pacing: 3 ped kills 300 frames apart gave level 0.45 (0 stars), expected >= 1 star
AUTOTEST FAIL: wanted_pacing: try_spawn_enemy(true) at 0 stars (level 0.45) spawned nothing
AUTOTEST FAIL: wanted_pacing: decay from 1.20 after 601 crime-free frames gave 0.20, expected ~0.95 (one partial decay_step)
```
The chain drives the REAL `kill_ped` path (fresh peds, three
kills, 300 wanted ticks after each — 5 s at 60 fps), then
checks a forced spawn from the resulting state, then decay.

**GREEN (minimal, tuning only):** gains moved to a live tuning
block in the data — `wanted.gains` in
`data/enemies_world_wanted.json` — and `gate3d_main` reads all
three kill paths from it (run-over kills use `kill_ped_runover`;
fallbacks are the HTML numbers if the block is absent).
`core/wanted.gd`'s decay now subtracts a `decay_step` that
arrives via `setup(cfg)` with **default 1.0**, so core stays
game-agnostic: the smoketest's config sets no `decay_step` and
keeps the old whole-star behaviour, all five SMOKETEST PASS
lines verbatim. Nothing else moved: caps, spawn types,
`decay_frames` 600 all unchanged.

| Tuning | Old (HTML) | New (live) |
|---|---|---|
| kill_ped | 0.15 | **0.35** |
| kill_ped_runover | 0.15 | **0.35** |
| destroy_car | 0.3 | 0.3 (unchanged value, now from data) |
| kill_enemy | 0.1 | 0.1 (unchanged value, now from data) |
| decay step | 1.0 (whole star) | **0.25** |

Three ped kills now bank 1.05 → star 1 → cops spawn; a quiet
600 frames costs a quarter-star, not the whole record.
`gains_in_html` in the data is **untouched** — it is the
historical record, not the live tuning.

**Validation:** new seventh line, project AND exported
binary: `AUTOTEST PASS: wanted_pacing ped_chain_star
cop_spawn decay_partial`, alongside all six prior AUTOTEST
lines and all five SMOKETEST lines, verbatim. 1200-frame
headless run: exit 0, zero script errors. Export:
`builds/GODOT-Linux/GODOT.x86_64`, 66,248,064 bytes, sha256
`a5fd3b2199550f18e09baf837fdf6b39697d17c1f1804af4479399f823238f55`;
exported binary ran 300 frames clean and passes the full
autotest. Zip: `builds/GODOT-Linux-WantedFix.zip` (24,333,414
bytes, sha256
`e2ac6fe667dee02a9c743d5f831b0ce10179663648dde3658ab7212a535650ed`).
Whether the policia actually show up at a satisfying pace on
real hardware is **[unverified]** until Vee plays this build —
the test proves the chain reaches a star and spawns a cop;
the feel of the pacing is hers to judge.

## Fall fix (2026-11-01, TDD red → green → refactor; Vee's first live telemetry)

**The bug, from her own telemetry.** In Vee's first live
sessions on the telemetry build (archived at
`~/workspace/playtest-archive/2026-11-01-first-live/`),
`session-20261101-094432.log` shows her driving east in a car
at z≈-38, y=0.25, x 35 → 127 — and then falling: at x≈127.5
vy starts accelerating, the car falls to **y=-771**, she
exits mid-fall at t=48.11 and keeps falling on foot. The
city's ground slab ends at `CityBuilder.WORLD_HALF` (120);
past it there was no ground, no boundary, and no kill-plane.
(FPS on her hardware was 31–60, healthy; the same archive
verifies the wanted fix live — WANTED 0→1 in three sessions.)

**Direction change mid-gate (Vee, 2026-11-01):** the planned
fix was invisible walls that dead-stop you at the edge. Her
amendment, verbatim: **"bonk should send you flying like
old mx vs atv logic."** The walls still exist (nothing
leaves the world), but fast contact now LAUNCHES: velocity
reflects off the edge with a boost plus an upward pop,
arcing you back onto the map. Slow contact just blocks.

**What shipped:**

- **Boundary walls** (`core/city_builder.gd`): one
  StaticBody3D, four box shapes just outside ±WORLD_HALF,
  30 tall, no meshes. +5 nodes (796 → **801**, budget < 900),
  MultiMesh instances unchanged (1,325).
- **Kill-plane respawn** (game layer): the actor (player on
  foot, or the driven car with the player in it) below
  `kill_plane_y` respawns at the nearest road-centre point
  that clears every building footprint (player spawn as
  final fallback), velocity zeroed, car uprighted, still in
  the car. **No cash/score penalty** — none was specified,
  so none was invented. Logs a `RESPAWN` telemetry event.
- **Bonk** (game layer + body launch state): contact with
  an edge wall at impact speed ≥ `bonk_min_speed` reflects
  the intended horizontal velocity × `bonk_restitution` and
  adds `bonk_up_pop` upward. The launch is carried by state
  the bodies own (`Player3D.apply_launch` / `Car3D.
  apply_bonk` + a 0.5 s ballistic-Y window) because walk
  input and the floor clamp would otherwise rewrite the
  velocity the very next physics tick — a velocity-only
  rewrite in the game layer provably cannot survive a frame.
  Logs a `BONK` event (impact speed + position). Tuning
  lives in the data's new `edge` block:

  | Tuning | Value |
  |---|---|
  | kill_plane_y | -20 |
  | bonk_restitution | 1.2 |
  | bonk_up_pop | 7.0 |
  | bonk_min_speed | 6.0 |

- **Telemetry hardening** (same live sessions): (a) frame
  files now carry the session stamp —
  `frame-<yyyymmdd-hhmmss>-<t>.png` — because all sessions
  shared one dir and overwrote each other's `frame-<t>.png`
  files. `core/debug_log.gd` change only; the digest parser
  reads BOTH namings, so old archives still digest.
  (b) The parser (`tools/playtest_digest.py`) groups
  consecutive same-rule anomalies (next start within 1 s of
  the group's end) into one entry with a t-range and count.

**RED (recorded before the fixes):**

Parser selftest, after planting a 3-snapshot y run and a
session-stamped frame name:
```
PARSER SELFTEST FAIL: planted anomalies [('fps_sustained', 2.5), ('nan', 6.0), ('position_jump', 1.0), ('y_out_of_range', 2.0), ('y_out_of_range', 2.5), ('y_out_of_range', 3.0)] != expected [('fps_sustained', 2.5), ('nan', 6.0), ('position_jump', 1.0), ('y_out_of_range', 2.0)]
PARSER SELFTEST FAIL: marker at t=6.50 nearest frame is frame-0.00.png, expected frame-20261101-000000-5.75.png
PARSER SELFTEST FAIL: planted y run produced 3 entries, expected 1 grouped entry
PARSER SELFTEST FAIL: planted frames [{'t': 0.0, 'name': 'frame-0.00.png'}, {'t': 20.0, 'name': 'frame-20.00.png'}] != 3
```

Frame naming (autotest section 10 assertions updated to the
stamped contract first):
```
AUTOTEST FAIL: telemetry_log: marker() kept frames ["user://telemetry_autotest_unit/frame-20.00.png"], expected one frame-<session-stamp>-20.00.png
AUTOTEST FAIL: telemetry_log: newest frame file frame-<session-stamp>-33.00.png missing
```

Game (new autotest section 12, all seven prior PASS lines
verbatim above these, exit 1):
```
AUTOTEST FAIL: fall_respawn: on-foot fall to y=-30 left the player at y=-30.14 (no respawn)
AUTOTEST FAIL: fall_respawn: respawned player still falling (vy=-2.33)
AUTOTEST FAIL: fall_respawn: respawn point (30, -30.14167, -38) is not on a road
AUTOTEST FAIL: fall_respawn: no RESPAWN telemetry event for the on-foot fall
AUTOTEST FAIL: fall_respawn: car fell to y=-30 and kept falling (car y=-30.14, no respawn)
AUTOTEST FAIL: fall_respawn: car respawn point (60, -30.14167, 40) is not on a road
AUTOTEST FAIL: fall_respawn: respawned car still falling (vy=-2.33)
AUTOTEST FAIL: fall_respawn: no RESPAWN telemetry event for the in-car fall
AUTOTEST FAIL: bonk: car hit the +X edge at speed 20 and no BONK fired (pos (135.1389, -5.149058, 0.000001), speed 19.8)
AUTOTEST FAIL: bonk: slow car left the world (x=120.19)
AUTOTEST FAIL: bonk: walking player left the world (x=121.10)
AUTOTEST FAIL: bonk: on-foot impact at 14 u/s did not launch (pos (127.0057, -2.8177, -0))
```

**Three test-design corrections during the gate** (recorded
per METHOD — the tests were wrong, in specific ways, and
the fixes are part of the record):

1. **BUSTED moved.** Section 12 first ran after section
   10's `on_player_death()`, whose 2.5 s scene-reload timer
   fired mid-section and looped the autotest through scene
   reloads forever, printing nothing (probe: zero AUTOTEST
   lines in 60 s, a fresh telemetry session every ~7 s).
   The BUSTED wiring check now runs at the very end of the
   autotest; its assertions are unchanged and section 10's
   other checks are untouched.
2. **The slow car blocked its own lane.** The first RED
   run's on-foot checks stopped at x=117.84 — exactly a car
   length + capsule radius short of the slow-test car left
   parked at the edge. The test now moves that car back to
   its spawn spot before the on-foot checks.
3. **Settle time.** The first GREEN run failed only
   `vy=-2.33` on both respawn checks: the respawn fires on
   tick one, but the body's last ~0.1 u drop to the road
   takes ~6 frames to settle at gravity 22. The checks now
   wait 16 frames; the assertion (velocity ≈ 0, on a road)
   is unchanged.

**GREEN:** new eighth line, project AND exported binary:
`AUTOTEST PASS: fall_respawn kill_plane_foot kill_plane_car
bonk_launch bonk_slow_block`, all seven prior AUTOTEST
lines and all five SMOKETEST lines verbatim; parser
selftest PASS line gains the `grouped_anomalies` token.
Suite run 3× consecutively green in the project.
REFACTOR step: reviewed — the launch state is symmetric
across the two bodies and the game-layer check reads in
one pass; no change was warranted, and the suite is
identically green.

**Validation & review:**

- **Archived fall, re-digested with the new parser:** the
  fall session's anomaly list goes from 22 lines to one:
  `- t=45.01..55.52 [y_out_of_range] ×22 y=-5.63 outside
  [-5, 30] (nearest frame: frame-46.67.png)` — and every
  other archived session digests exactly as before (0
  anomalies), proving old sessions stay readable.
- 1200-frame headless run: exit 0, **0 script errors**
  (419 known "m is null" dummy-renderer artifacts, counted
  only). Xvfb screenshot: 1280×720, 7,411 unique colours,
  ≈5.9 k sign-accent (C77DFF) pixels — visually unchanged,
  walls invisible as designed.
- Edge cases reviewed: bonk detection reads the car's
  carried `speed` (survives the collision slide) and the
  on-foot *intended* velocity (the slide eats the real
  one); reversing into a wall bonks correctly, since the
  check uses the travel vector, not facing. A building
  face inside the edge margin could in principle false-
  trigger a launch — outcome is a harmless inward bounce,
  accepted. The kill-plane checks only the actor (ambient
  cars/peds cannot leave the walled world anyway). The
  0.75 s bonk cooldown prevents double-triggers while a
  body is still kissing the wall. Un-driven cars and peds
  also collide with the walls — they never path out there,
  and spawn placement is unchanged (interior ring).
- Export: `builds/GODOT-Linux/GODOT.x86_64`, 66,257,984
  bytes, sha256
  `f6c7c58ce3c4a7ccfd6fa947d021824957ae90a6b0f9e86b8a3ffa84f9244916`;
  exported binary: full autotest PASS (all 8 lines, exit
  0) and 300 frames clean. (Binary runs on this display-
  less VM need `--headless`; a bare run fails on X11 init
  before any game code — environment, not the build.)
  Zip: `builds/GODOT-Linux-FallFix.zip` (24,343,021 bytes,
  sha256
  `27a1ac69834274572d04a4af4c292b6604f046011b7a197ad6674eca7c56dbec`).

Real-hardware edge behaviour is **[unverified]** until Vee
drives off a cliff again: the tests prove the respawn and
the launch contracts; whether the bonk *feels* like MX vs
ATV is hers to judge.

## Assets Step 1 — Kenney fleet (2026-11-01)

Spec: `design/ASSETS1_SPEC.md`; plan + tasks:
`design/ASSETS1_PLAN.md`. Direction is Vee's (2026-11-01):
"a = step 1, b = step 2, or basically c" — Kenney cars
first, city kits second, phased hybrid. The fleet is models
now: Kenney Car Kit GLBs (CC0, licence verified on the
source page and in the zip — `design/ASSET_RESEARCH.md`),
imported through the pipeline the research gate proved.

### Contract supersession — on the record, in plain words

Detail Pass 1's `car_variants` checks asserted a procedural
fleet: at least 3 `body_style` silhouettes, a paint palette
of at least 8 colours, at least 3 paints visible on spawned
cars, and wheel spin on procedural wheel nodes. **Those
four sub-checks are superseded and removed.** What changed:
the procedural bodies they described no longer exist — Vee
decided (2026-11-01, above) that the fleet becomes Kenney
GLB models, and a test asserting box silhouettes and paint
palettes would be asserting a fleet she retired. Why this
is not a silent weakening: the contract's *intent* — the
fleet is varied, honestly scaled, and its wheels really
spin and steer — moved, strengthened, to section 13 and the
new line `AUTOTEST PASS: assets1 kenney_fleet scale
wheels_spin atlas` (>= 5 distinct models instead of 3 box
styles; per-car visual-length assertion instead of a
palette count; spin AND steer asserted on the GLB's own
wheel nodes; the atlas proven in the tree, on a car at
runtime, and inside the exported binary run from a clean
directory). The `detail1` PASS line still prints verbatim
(`... walk_cycle car_variants signage density_budget`) and
keeps asserting walk_cycle / signage / density_budget; the
supersession comment also sits at the old check site in
`gate3d_main.gd`. The procedural builder itself
(`_box`/`_glass_mat`/`_light_mat`, `PALETTE`, `paint_colors`,
`body_style`, `car_color`) is **deleted** from `car3d.gd`,
not bypassed — spec statement 1: not left as a second fleet.

### RED (recorded before implementation, exit 1)

All 8 prior AUTOTEST lines PASS above these, verbatim:

```
AUTOTEST FAIL: kenney_fleet: 0 distinct GLB models across the fleet, expected >= 5
AUTOTEST FAIL: atlas: res://assets/kenney_car_kit/Textures/colormap.png is missing from the tree
AUTOTEST FAIL: atlas: no textured material found on the first fleet car at runtime
AUTOTEST FAIL: wheels_spin: fleet car exposes no GLB wheel nodes
```

(The scale sub-check passed incidentally in red — the
procedural bodies were already collision-sized; the section
failed for the four reasons above, which are the gate's
actual subject.)

### Probe findings (imported scenes, Godot space)

- Kit nose is **+Z**: `wheel-front-*` sit at positive Z,
  all node rotations identity. Car3D's forward is -Z, so
  the model root turns PI; wheel spin sign is set from the
  axis math for the flipped root (`rotation.x =
  -spin_angle` — the roll direction was verified in the
  Xvfb frames), steering keeps `steer_visual`'s sign.
- Wheel centres at native y 0.30, radius 0.30: at x1.55
  the tyres touch y=0 exactly at the car origin.
- Every mesh's material resolves to
  `res://assets/kenney_car_kit/Textures/colormap.png` —
  the shared atlas, folder structure preserved as copied.

### What shipped

- **Fleet (in `cars[]`, drivable, collision untouched):**
  sedan, hatchback-sports, taxi, van, truck, sedan-sports
  over the six existing spots. `Car3D.model_name` is set
  by the spawner before `add_child` (the old `body_style`
  seam); `_ready` instances the GLB at x1.55 as a visual
  child. Physics, speeds, enter/exit, run-over, bonk,
  kill-plane: the same code paths as before the gate.
- **Wheels:** the kit nodes (`wheel-front-left/right`,
  `wheel-back-left/right`) are collected into `glb_wheels`
  and driven from the existing spin state with
  `WHEEL_R = 0.465` (the GLB wheel radius at scale — roll
  rate stays honest); front wheels also yaw with
  `steer_visual`. Extras (spoiler, grill, doors, the SUV's
  spare) are ignored. `set_dead_visual()` darkens the
  model's non-wheel meshes via per-node material override;
  the shared atlas material is never mutated.
- **Test seam:** `Car3D.drive_override`, mirroring
  `Player3D.move_override` (NaN = real input), so the
  autotest steers through the same code path as a player.
- **Service dressing:** ambulance, firetruck,
  garbage-truck, police as static GLB instances with a
  plain collision box at inter-pad slab spots. They are
  deliberately NOT `Car3D`: their native lengths
  (3.25–3.45) would put a x1.55 visual 26–34 % past the
  fleet's 4.0 collision box, and spec statement 1 names
  them parked dressing. Making them drivable is a later
  gameplay decision, recorded here rather than dropped.
  (There are no AI-driven cars in this build to convert —
  traffic is the parked fleet; pursuers are on foot. The
  police GLB appears parked only, per spec's out-of-scope
  note; enemy cars are a gameplay gate.)
- **Copied into `engine/assets/kenney_car_kit/`** (10
  models, 2.0 MB total): `sedan.glb`, `sedan-sports.glb`,
  `hatchback-sports.glb`, `taxi.glb`, `van.glb`,
  `truck.glb`, `ambulance.glb`, `firetruck.glb`,
  `garbage-truck.glb`, `police.glb`, plus
  `Textures/colormap.png` and `License.txt`. The other 40
  kit models stay in `assets-src/` only.
- A `--carshot` debug flag (mirrors `--markshot`) frames
  the first fleet car for the visual check.

### One test-design correction, documented not hidden

The first clean-dir export run failed exactly one check:
`atlas: ... colormap.png is missing from the tree`. The
export log showed the atlas packed as
`.godot/imported/colormap.png-8f10….ctex` plus its
`.import` remap — the atlas *did* travel; the probe was
wrong. `FileAccess.file_exists` checks the literal path,
which a packed build stores only in remapped form. The
check now uses `ResourceLoader.exists`, which follows the
remap and answers the actual contract in both worlds. The
companion runtime check (a car's material really carries
a texture) passed in the export all along and is
unchanged.

### REFACTOR step

Considered per METHOD: the only repeated shape is the
two-line GLB load in the fleet spawn and the dressing
placement — extracting a helper would touch more than it
saves, so no refactor was taken and the suite stands as
green from the GREEN step.

### Validation

- Project autotest: **9 PASS lines** (8 prior verbatim +
  assets1), exit 0. Smoketest: all 5 lines verbatim.
- Node census: **801 -> 724** (budget < 900; a GLB car is
  ~10 nodes against the procedural ~29). MultiMesh
  instances ~1,320, unchanged. Instanced fleet + dressing
  triangles: **23,443** total across all 10 models
  (counted from the GLBs) — nothing to an UHD 600.
- 1200-frame headless run: exit 0, **0 script errors**
  (311 known "m is null" dummy-renderer artifacts).
- Xvfb: `--carshot` frames the sedan textured — PIL:
  9,123 unique colours, 1,163 sedan-red pixels (fog
  washes the count; the colour is atlas colour, not a
  fallback). `--screenshot` street scene: 7,376 unique
  colours, city unchanged. The exported binary's own
  `--carshot` from the clean dir: 8,628 unique colours,
  sedan-red present.
- Export: `builds/GODOT-Linux/GODOT.x86_64`, 66,944,080
  bytes, sha256
  `1cedd8e39b779aac6d6f7d5c6535f26a215d626bba422c0914b78f43d9d67809`.
  **Clean-dir proof:** copied to `/tmp/clean-run`, run
  there — full autotest PASS (all 9 lines, exit 0) and
  300 frames clean, with no access to the source tree:
  the atlas travels (spec statement 4).
- Zip: `builds/GODOT-Linux-Assets1.zip` (24,997,428
  bytes, sha256
  `2c4ca07051824afcdf96db04f1a812e39f38ddffe0eb9fef019edf9220e65ce7`).

The look on iwantitnow is **[unverified]** until Vee sees
the fleet on her screen — the tests prove models, scale,
spin, steer and texture; whether Kenney's chibi proportions
*feel* right next to the flap-heads is hers to judge.
Step 2 (city kits: roads + buildings) is next, per her
phased call.
