# Engine — Godot 4 (in use since Gate 0, 2026-10-29)

This file was the pre-decision comparison. Godot 4 is the engine the
Gate 0 greybox was built and verified in, and it stays the engine for
the PS2-level 3D pivot (Godot 4 does 3D; low-poly + fog + capped draw
distance is exactly the PS2-era look). The comparison below is kept
as the record of why.

Vee's ask (2026-10-29): out of HTML, into "an actual engine", GTA 1 form
(top-down) with today's graphics.

## Recommendation: Godot 4

- Top-down 2D is its home turf: TileMap city grid, 2D lights/shadows,
  particles, shaders — that's the "today's graphics" layer on a GTA 1
  skeleton without going 3D.
- Free / open source, no licence or royalty trap, runs natively on Linux
  (Vee's platform), exports to Linux / Windows / Android from one project.
- One project replaces both HTML versions: InputMap actions cover
  touch joystick, WASD+mouse, and mouse-only as three mappings of the
  same actions — exactly what v2 of the HTML was hand-rolling.
- Scenes = the scaffold: Player / Car / Ped / Enemy / Bullet / Pickup
  are each a scene + script, data comes from `../data/*.json`.

## Alternatives, and why they're second

- **Unity:** capable, but heavier, account/licence friction, worse fit
  for a small Linux-first 2D project.
- **Unreal:** 3D-first overkill for GTA 1 top-down; huge builds.
- **Bevy / raw Rust, LÖVE, Phaser:** real engines, but either much more
  hand-built scaffolding (Bevy) or staying in the web/JS world Vee just
  asked to leave (Phaser).

## What changes once Vee picks one

Only then: `project.godot` (or equivalent), scene tree, input map, and
the simulator harness get created under `engine/`. Until then this file
is a prepared choice, not a decision.
