# G.O.D.O.T — Gate 0 Greybox (Godot 4.3)

> 2026-10-29 pivot (Vee): the target is no longer top-down — it's
> PS2-level 3D, like San Andreas at launch. This Gate 0 project is the
> top-down **systems prototype** (data/wanted/economy/sim carry over);
> its 2D view does not. See ../SKELETON.md.

Status: Gate 0, greybox with placeholder assets. No generated art.
Characters are drawn in code (`scripts/flappy_person.gd`) to Vee's
stipulation: South-Park-Canadian-style — flat simple bodies, beady
close-set eyes, head split at the mouth, whole top half flaps while
talking/shouting (fleeing peds, shooting player/enemies flap).

## Run it

```
godot --path .            # editor / play (F6/F5), or open project.godot
godot --headless --path . --script sim/simulator.gd   # balance sim
```

Controls (Gate 0, physical keys in code):
WASD/arrows move · mouse aims · left mouse fires · E enter/exit car ·
Q cycle weapon. Cars: WASD drives, mouse drive-by.

## What's in Gate 0

- City grid from the HTML numbers (3600 / block 340 / road 100)
- On foot + steal/drive cars + drive-by, run-overs
- Shooting for all 9 weapons from `data/weapons.json`
- Wanted as a float with floor() table lookups (HTML bug fixed),
  decay 600 frames, cop→SWAT→military→tank caps from the data file
- Combo, cash, score, pickups, explosions, HUD (HP/weapon/cash/stars)
- Death → BUSTED screen → fresh run

## Not in Gate 0 (later gates, deliberately)

- Save/Black Market UI (data is loaded, spending is Gate 1)
- InputMap / touch + mouse-only modes (HTML v2 had them; Gate 1)
- Real/generated assets (asset spec is Gate 2, slice is Gate 3)
- Sound (HTML had a WebAudio synth; Gate 1+)
