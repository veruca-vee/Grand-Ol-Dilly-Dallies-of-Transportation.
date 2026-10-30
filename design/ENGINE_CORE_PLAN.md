# ENGINE CORE — extraction plan

Status labels: the *direction* is Vee's (2026-10-30, her words:
"Before details lets focus on mastering the engine bc I wanna be
able to quick port it to other games as their engine"). Everything
below the direction line is [plan — assistant's, not yet executed].
The engine's name slot stays blank — naming it is Vee's call.

## The problem this solves

`engine/gate3d/gate3d_main.gd` is a 1,562-line monolith: camera,
shooting, spawning, wanted, economy, pickups, HUD, shop, save,
minimap wiring and the autotest all live in one file. The leaf
scripts (player/car/enemy/ped/bullet/pickup/tank/flappy/dressing/
sfx/minimap, 44–249 lines each) are already nearly separable.
Porting the game today means copying the monolith and carving it.
Porting after this gate means copying a `core/` folder and writing
new data.

## Target shape

```
engine/
  core/            <- the reusable engine (no G.O.D.O.T specifics)
    data_loader.gd     JSON -> validated dictionaries (weapons/upgrades/enemies/world)
    controller.gd      camera-relative character controller (the walk fix lives here)
    follow_camera.gd   follow-cam rig (yaw tracking, aim ray helpers)
    flap_rig.gd        the Canadian hinge-head character rig (from flappy_person3d)
    combat.gd          hitscan/projectile/melee resolution from weapon data
    wanted.gd          float wanted, floor caps, spawn director
    economy.gd         cash/score/combo, drops, pickup rules
    upgrades.gd        shop model (cost floor(base x 1.4^level), effects)
    save_game.gd       JSON persistence (user://), versioned
    hud_kit.gd         bars/labels/stars/crosshair/minimap widgets
    sfx_synth.gd       synthesized AudioStreamWAV effects (from sfx.gd)
    city_builder.gd    seeded block/road/prop generation (from dressing.gd + main)
  game/            <- G.O.D.O.T itself, thin
    main.gd            wires core modules, holds game rules that are truly game-specific
    data/*.json        this game's numbers
```

## Rules of the extraction

1. **No behavior change.** The gate is a move, not a redesign. All
   existing AUTOTEST PASS lines must print verbatim after every
   step, in the project and in the exported binary.
2. **Data is the interface.** Core modules take dictionaries from
   the JSON data files; a module that needs a number not in data
   gets a config dictionary, never a hardcoded G.O.D.O.T constant.
3. **One module per step, verified per step.** Extract in risk
   order (below), run the full autotest after each, so a regression
   has exactly one suspect.
4. **Game-specific stays in game/.** Wanted levels named cop/SWAT/
   military/tank, the Black Market's name, the flap-head look: data
   and game layer. Movement, combat math, save format: core.

## Extraction order (lowest coupling first)

1. `sfx_synth` (already a leaf, near-zero coupling)
2. `save_game` (bounded I/O, clear contract)
3. `data_loader` (everything downstream gets cleaner)
4. `upgrades` + `economy` (pure rules, autotest already covers them)
5. `wanted` / spawn director
6. `combat` (touches player, enemies, camera — mid risk)
7. `controller` + `follow_camera` (feel-critical; walk-fix code is the base)
8. `hud_kit` + minimap
9. `flap_rig` (character base class)
10. `city_builder` (biggest surface, last)

## The port test (how we know it worked)

After extraction, prove portability with a **smoke game**: a tiny
throwaway scene that boots the core with a *different* data set
(e.g. one weapon, one enemy type, different costs) and passes a
3-line autotest (move, shoot, buy). If a new game can't stand up
in an afternoon from core + data, the extraction isn't done.
The smoke game is a test fixture, not a shipped game.

## What this gate does NOT do

- No new features, no detail passes (deferred by Vee's direction —
  the Kimi-bar detail work comes after mastery).
- No renaming of the engine (Vee's slot).
- No change to G.O.D.O.T's numbers, controls, or look.
