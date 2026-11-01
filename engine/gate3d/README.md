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
