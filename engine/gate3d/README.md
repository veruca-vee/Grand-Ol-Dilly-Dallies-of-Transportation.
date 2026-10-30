# Gate 3D-0 — PS2-era greybox

Run it (from the `engine/` folder):

```
godot --path . res://gate3d/Gate3D.tscn
```

WASD move / drive · **E** enter/exit nearest car · hold **T** to talk
and watch the head flap. Peds talk to themselves at random — same flap.

## The PS2 brief, as built here

- Primitives only: box buildings, box-and-cylinder cars, box people
- Camera far plane 160 + exponential fog (density 0.012) — the draw
  distance *is* the period look, like San Andreas at launch
- Flat colours, one directional light, no textures yet

## The Canadian look in 3D

`flappy_person3d.gd`: head split at the mouth line; the upper head
(beady eyes on it, close-set black spheres) hangs on a hinge pivot at
the back of the jaw and rotates open while talking. Max opening
0.55 rad. That's the 2D flap translated to a 3D hinge.

## Scope honesty

This gate proves world + third-person + driving + flap-heads.
Weapons, wanted, economy stay in the 2D Gate 0 / data files until a
later gate ports them into 3D.
