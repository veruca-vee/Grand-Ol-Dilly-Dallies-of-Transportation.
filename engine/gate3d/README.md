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
