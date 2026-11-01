# ASSETS STEP 1 — PLAN + TASKS: "Kenney fleet"

Spec: `design/ASSETS1_SPEC.md` (Vee's decision 2026-11-01:
cars first, city kits second). Research: `design/ASSET_RESEARCH.md`
§1–2 (CC0 verified; import proof; two gotchas — external atlas,
native scale).

## Baseline (measured 2026-11-01, before any change)

- Project autotest: all 8 PASS lines, exit 0. Smoketest: all
  lines PASS (see README gate section for the recorded run).
- Node census (`_scene_counts`): recorded in the README gate
  section; budget is < 900 total nodes.
- Current fleet: 6 `Car3D` at fixed spots, procedural bodies
  (Detail 1: 3 silhouettes × palette), ~29 nodes per car.

## Model → role mapping (from the actual kit, measured AABBs)

Native lengths parsed from the GLBs themselves (accessor
min/max, node transforms applied). Scale ×1.55 (spec statement
2) gives the visual length; the collision box stays 1.8×1.1×4.0
for every car, untouched.

| Role | Kit model | Native len | ×1.55 | In `cars[]`? |
|---|---|---|---|---|
| Drivable fleet (6 start spots) | sedan | 2.55 | 3.95 | yes |
| | hatchback-sports | 2.85 | 4.42 | yes |
| | taxi | 2.75 | 4.26 | yes |
| | van | 2.75 | 4.26 | yes |
| | truck | 2.95 | 4.57 | yes |
| | sedan-sports | 2.55 | 3.95 | yes |
| Parked dressing (static) | ambulance | 3.25 | 5.04 | no |
| | firetruck | 3.40 | 5.27 | no |
| | garbage-truck | 3.45 | 5.35 | no |
| | police | 3.10 | 4.81 | no |

Why the split: the drivable six are the models whose native
lengths keep the ×1.55 visual inside ±0.7 of the 4.0 collision
length (the scale-honesty tolerance the autotest asserts). The
service vehicles' native lengths (3.25–3.45) would put a
×1.55 visual 26–34 % past the collision box; the spec names
them "parked street dressing", so they are placed as static
visual instances (no `Car3D`, not enterable, no collision —
the same treatment as other street dressing) on road strips.
Making them drivable later is a gameplay decision, not an
asset swap; it is noted in the README, not silently dropped.
There are no AI-driven cars in the current build (traffic is
parked cars; cops are on foot), so "AI cars" in spec statement
1 is the same fleet — nothing else exists to convert.

Copied into `engine/assets/kenney_car_kit/` (only what's used):
the 10 GLBs above + `Textures/colormap.png` (the shared atlas
the GLBs reference by relative path — folder structure kept
exactly, per research gotcha 1) + `License.txt` (CC0).

## How Car3D hosts a GLB

- `Car3D.model_name: String` is set by the spawner BEFORE
  `add_child` (same seam as `body_style` today). `_ready`
  loads `res://assets/kenney_car_kit/<model_name>.glb`,
  instances it as `model_root`, scale ×1.55, at the car
  origin. Wheel geometry: kit wheel centres sit at native
  y 0.30 with radius 0.30, so at ×1.55 the wheels touch y=0
  exactly at the car origin — no vertical offset needed.
- Collision shape, physics, driving, bonk, kill-plane: the
  existing code paths, byte-identical. The GLB is a visual
  child only.
- Wheels: kit nodes are named `wheel-front-left/right`,
  `wheel-back-left/right` (verified in the GLB JSON of every
  model used; extras like the SUV's spare `wheel-back`,
  `spoiler`, `grill`, `door`, `arm` are ignored). Car3D
  collects the four into `glb_wheels` ({node, front}) and
  drives them from the existing spin state:
  `spin_angle -= speed * delta / WHEEL_R` with
  `WHEEL_R = 0.30 × 1.55 = 0.465` (the GLB wheel radius, so
  the roll rate is honest). Per frame each wheel node gets
  `rotation.x = spin_angle`; front wheels additionally get
  `rotation.y = steer_visual` (Godot's default YXZ euler
  order yaws the axle, then spins — the Detail 1 contract,
  on the new nodes). Front = the pair on the car's forward
  end; which raw axis that is gets settled by a probe of the
  imported scene (glTF→Godot Z conversion) before the code
  is written, and the probe result is recorded in the README.
- `set_dead_visual()`: unchanged contract — it darkens
  `body_meshes`; that array now collects the model's
  non-wheel MeshInstance3Ds and gets the same dark material
  override (per-node override; the shared atlas material is
  not mutated).
- Test seam: `drive_override: Vector2` on Car3D, mirroring
  `Player3D.move_override` exactly (NaN = real input). The
  assets1 steer check drives through it; gameplay input
  still comes from `Controller.read_drive_input()`.

## Procedural builder disposition: REMOVED

The box-body builder, `PALETTE`/`paint_colors`, `body_style`
and `car_color` are deleted from `car3d.gd`, and the spawner
in `gate3d_main.gd` sets `model_name` instead. Why removal,
not a bypass flag: spec statement 1 says the procedural
bodies retire and must not be left as a second fleet; a dead
builder kept behind a flag is exactly the kind of silent
second system the method forbids. The 2D Gate 0 car
(`scripts/car.gd`) is a different game layer and is untouched.

## The supersession (spec statement 5), precisely

- `gate3d_main.gd` autotest section (b) `car_variants` checks
  (≥3 `body_style` values, palette ≥8, ≥3 paints seen, and
  the procedural wheel-spin check) are REMOVED from `fails4`.
  The detail1 PASS line still prints verbatim —
  `AUTOTEST PASS: detail1 walk_cycle car_variants signage
  density_budget` — now asserting walk_cycle / signage /
  density_budget only.
- The fleet contract moves to a new section (fails9) and a
  new line: `AUTOTEST PASS: assets1 kenney_fleet scale
  wheels_spin atlas`, asserting: ≥5 distinct `model_name`s
  across `cars[]`; every fleet car's visual AABB length
  within ±0.7 of the 4.0 collision length; atlas file exists
  at `res://assets/kenney_car_kit/Textures/colormap.png`
  and at least one car's body material has a non-null
  albedo texture at runtime; a driven car's GLB wheel
  `rotation.x` advances with speed and its front wheels'
  `rotation.y` follows steering (rear wheels stay unyawed).
- The README gate section states the supersession in plain
  words: what changed, why (Vee's phased-hybrid decision,
  2026-11-01), and where the checks went.

## Export / atlas verification plan

1. `godot --headless --import` so the GLBs + atlas get
   `.import` data; confirm no import errors beyond the known
   non-fatal LOD-normal warning from the research.
2. Full suite in project: autotest (9 lines) + smoketest.
3. Export Linux preset → `../builds/GODOT-Linux/GODOT.x86_64`.
4. **Clean-dir proof**: copy the export dir to
   `/tmp/clean-run`, run the binary there (`--headless
   --autotest`) with the source tree unreachable in practice
   (different cwd; res:// resolves inside the packed binary)
   — all 9 lines PASS, including `assets1 … atlas`.
5. 1200-frame run of the project: 0 script errors.
6. Xvfb screenshots: standard `--screenshot` street scene +
   a new `--carshot` flag (mirrors `--markshot`: park the
   player facing the first fleet car) for a close textured
   frame; PIL checks (unique colours, non-grey car pixels).
7. Node census + fleet triangle estimate (kit average
   1,304 tris/model from research; fleet of 10 instanced
   models ≈ 15–20 k tris — trivially inside the PS2 budget).

## What deliberately does NOT change

- Physics, speeds, collision, enter/exit, run-over, bonk,
  kill-plane, wanted, economy, telemetry, save format.
- Flap-heads, peds, enemies, city, HUD.
- The 2D Gate 0 layer (`scripts/`, `Main.tscn`) and the
  smoketest (its lines stay verbatim; it does not load cars).
- No git commands, no pushes (HQ runs the dual-track sync).
  `assets-src/` stays outside the engine tree; only the
  copied selection above enters `engine/assets/`.

## Completion (2026-11-01)

All tasks executed in order. Deviations from this plan,
each documented in the README gate section: (1) the
service dressing also got a plain static collision box
(plan said "no collision" by analogy to props — walking
through a firetruck read as broken; the box is 2 extra
nodes per vehicle and the census still fell 801 -> 724).
(2) The police GLB was included in the dressing (plan's
table had it; spec's out-of-scope note permits parked).
(3) The atlas autotest probe changed FileAccess ->
ResourceLoader after the first clean-dir run proved the
FileAccess probe wrong about the packed export (the
atlas was packed as .ctex + remap all along). (4) No T4
refactor was taken — the only duplication was a two-line
GLB load; recorded in the README. Final evidence: 9
AUTOTEST lines in project AND clean-dir export, smoketest
verbatim, 1200 frames 0 script errors, nodes 724, build
sha256 `1cedd8e3…67809`, zip `GODOT-Linux-Assets1.zip`.

## Tasks (ordered, each independently verifiable)

- **T1 — RED.** Add the assets1 section (fails9) + PASS line
  to the autotest; strip the car_variants sub-checks from
  fails4 per the supersession; run: assets1 FAILs recorded
  verbatim (no GLB fleet yet), all other lines PASS.
- **T2 — Copy assets.** The 10 GLBs + atlas + License into
  `engine/assets/kenney_car_kit/`; `--import`; probe the
  imported sedan (node names, wheel transforms, front axis,
  material texture) and record findings.
- **T3 — GREEN.** Car3D GLB hosting + wheel driving +
  `drive_override` seam; spawner model mapping; service
  dressing placement; procedural builder removed. Full
  suite green (9 autotest lines + smoketest).
- **T4 — REFACTOR.** Only if T3 leaves duplication (e.g.
  dressing placement vs fleet spawn); suite identically
  green after.
- **T5 — VALIDATE.** Screenshots + pixel checks, 1200-frame
  run, node census, export, clean-dir run, zip, README +
  SKELETON updates.
