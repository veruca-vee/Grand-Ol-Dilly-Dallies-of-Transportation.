# The Engine Core — a reusable Godot 4.3 game engine

Credit: **Veruca Velharin**

This folder is the engine that G.O.D.O.T (Grand Ol' Dilly-Dallies Of
Transportation) runs on, extracted from its game code in the Engine
Core gate (2026-10-30) so a new game can stand up from `core/` +
its own data files instead of copying a 1,562-line monolith. The
engine's name is intentionally blank — naming it is the author's
call, not this document's.

Everything here is plain GDScript, generated/procedural, no binary
assets. Core modules contain NO game-specific numbers: a module
that needs a number takes it from the game's JSON data or from a
config Dictionary passed at setup.

## Starting a new game on this engine

1. Copy `core/` into your Godot 4.3 project (keep the `res://core/`
   path or update the class references — the modules find each
   other by `class_name`, so paths are flexible).
2. Write your data files (below) and load them with `DataLoader`.
3. Build a main scene that wires the modules the way
   `gate3d/gate3d_main.gd` does: create the state modules
   (Economy, Wanted, Upgrades), a Combat instance, a FollowCamera,
   build the world with CityBuilder (or your own builder), spawn
   FlapRig-based characters, and drive the HUD with HudKit/Minimap.
4. Steal the test pattern too: `smoketest/` is a working minimal
   game on this core (its own 1-weapon / 1-enemy data) that checks
   move / shoot / buy headlessly. Copy it, point it at your data,
   and you have a port test from day one.

## Data a game must provide

Any shape your rules need, but the core modules expect these
conventions (G.O.D.O.T's files in `res://data/` are the reference):

- **weapons.json** — `{"weapons": [ {name, dmg, range, rate_frames,
  count, spread, color, melee?, rocket?}, ... ], "driveby_weapon":
  {...}, "player_start_weapon_index": int}`. Ranges/damage in your
  source units; Combat converts with your scale.
- **upgrades.json** — `{"upgrades": [ {id, name, desc, base_cost,
  base, inc_per_level}, ... ], "cost_formula": "floor(base_cost *
  1.4 ^ current_level)"}`. The 1.4 growth is passed to
  `Upgrades.setup(defs, growth)` — your game, your exponent.
- **enemies_world_wanted.json** — `{"enemies": [ {type, hp, dmg,
  speed, fire_rate_frames, range, cash_on_kill, score, color}, ...],
  "wanted": {"max_stars", "max_active_enemies_by_star": [...],
  "spawn_type_by_star_index_0_based": [...],
  "decay_frames_without_crime": int}, "combo": {"window_frames":
  int}, "player": {"base_hp": ...}, ...}` — plus whatever else
  your game layer reads (cars, pedestrians) via DataLoader.

## The modules

| File | Class | What it does | Key knobs |
|---|---|---|---|
| `data_loader.gd` | `DataLoader` | JSON file → validated Dictionary/Array; errors logged, `{}` on failure | paths are the caller's |
| `save_game.gd` | `SaveGame` | Versioned JSON payload ↔ a `user://` file (write/read/exists/delete) | the path; payload shape is the game's |
| `sfx_synth.gd` | `SfxSynth` | Synthesized `AudioStreamWAV` effects (gunshot, explosion, pickup, hurt, busted) — no audio files | seeds/waveforms in code; playback pool is game wiring |
| `economy.gd` | `Economy` | cash/score state + combo rule `min(cap, 1 + count × 0.5)` inside a frame window | `setup({window_frames})`, `combo_cap` |
| `upgrades.gd` | `Upgrades` | Shop model: defs, owned levels, `floor(base_cost × growth^level)`, `effect_value = base + inc × level` | defs + growth at `setup()` |
| `wanted.gd` | `Wanted` | Float wanted level, `floori` stars, per-star enemy caps, spawn-type table, decay tick, spawn policy (`can_spawn`/`spawn_roll`) | the whole wanted table at `setup(cfg)` |
| `combat.gd` | `Combat` | Weapon math under multipliers, camera-ray hitscan, melee target selection, explosion falloff, projectile hit selection (cars → peds → enemies → player) | `setup_projectiles({radii/offsets})`, collision mask 7 convention (1 world / 2 characters / 4 cars) |
| `controller.gd` | `Controller` | Physical-key input readers (walk/drive) + camera-relative movement math (`move_dir(input, yaw)`) | — (wrap the readers to remap) |
| `follow_camera.gd` | `FollowCamera` | Follow-cam rig: yaw state, lerp rates, `update(camera, actor, delta, dist, height)`, `aim_direction()` | `yaw_rate`, `pos_rate`, `aim_height`; dist/height per call |
| `hud_kit.gd` | `HudKit` | Panel styles, labels, HP bar, star/combo text formats | all colors/sizes are arguments |
| `minimap.gd` | `Minimap` | `_draw` top-down minimap (no SubViewport); duck-typed data source (`player`/`cars`/`enemies`) | `configure({world_size, grid_pitch, road_width, grid_lo/hi, col_*})`, defaults = G.O.D.O.T's city |
| `flap_rig.gd` | `FlapRig` | The hinge-head character rig: box body builder, beady eyes on the upper head, `tick_flap()`, `face_direction()`; subclass it for player/peds/enemies | `shirt_color`/`pants_color`/`skin_color`, optional cap |
| `city_dressing.gd` | `CityDressing` | Procedural textures/materials/meshes (facades with lit windows, asphalt, props) + MultiMesh builder | seeds/palette in code |
| `city_builder.gd` | `CityBuilder` | Seeded city generation: sky/fog/sun, ground, roads + markings, building clusters, props; returns building footprints for spawn placement | layout constants in code (52 pitch / 240 extent / seed 2004 — G.O.D.O.T's city) |
| `debug_log.gd` | `DebugLog` | Playtest telemetry: session log (header + timed snapshots + events), capped frame captures with rotation (frame files carry the session stamp, so sessions sharing a dir cannot overwrite each other), core-owned timing via `tick()`; local files only, disables itself silently on an unwritable dir | `snapshot_interval` / `frame_interval` / `frame_cap` (engine defaults 0.5 s / 20 s / 90); dir + build label and a `frame_provider` Callable at `start_session` |

## Rules the core lives by

1. **Data is the interface.** No G.O.D.O.T constants in core. If a
   module needs a number, it arrives via JSON or a config dict.
2. **Selection in core, consequences in the game.** Combat decides
   what was hit; the game decides what a hit means (damage, money,
   wanted). Wanted decides whether/what may spawn; the game decides
   where and builds it. Upgrades price the shop; the game binds
   effects to its actor.
3. **State modules are plain objects.** Economy/Wanted/Upgrades are
   RefCounted and unit-testable without a scene — the smoketest
   buys an upgrade with no world at all.

## Verification pattern (steal this too)

- A `--autotest` in the game layer that drives the REAL paths
  (fire/spawn/buy/walk) and prints PASS/FAIL lines; run it after
  every change, in the project and in the exported binary.
- A disposable smoke game (`smoketest/`) proving the core boots a
  different data set. G.O.D.O.T's prints:

```
SMOKETEST PASS: move camera_relative
SMOKETEST PASS: shoot damage_dealt
SMOKETEST PASS: buy upgrade_purchase
SMOKETEST PASS: wanted_floor save_roundtrip flap_rig sfx_synth
SMOKETEST PASS: telemetry debug_log
```
