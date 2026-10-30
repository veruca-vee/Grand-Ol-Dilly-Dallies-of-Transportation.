# Gate 3D — PS2-era greybox

Run it (from the `engine/` folder):

```
godot --path . res://gate3d/Gate3D.tscn
```

**Controls:** WASD move / drive · mouse aims (camera-centre ray) ·
**LMB** fire · **1–9** select weapon, **Q** cycles · **E** enter/exit
car · hold **T** to talk and watch the head flap. Peds talk to
themselves at random — same flap. Fleeing peds and firing characters
flap too.

## The PS2 brief, as built here

- Primitives only: box buildings, box-and-cylinder cars, box people
- Camera far plane 160 + exponential fog (density 0.012) — the draw
  distance *is* the period look, like San Andreas at launch
- Flat colours, one directional light, no textures yet
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
