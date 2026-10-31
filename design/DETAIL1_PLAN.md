# DETAIL PASS 1 — PLAN

Spec: `design/DETAIL1_SPEC.md` ("The street feels inhabited").
Method: `design/METHOD.md` — this doc is steps 1 (PLAN) + 2
(TASKS). Implementation is step 3 (per-task TDD: red → green →
refactor), validation/review is step 4.

## Baseline (measured 2026-10-30, before any change)

- Autotest: all 3 contract lines PASS (project, headless).
- Smoketest: all 4 SMOKETEST PASS lines.
- `--countnodes`: **nodes = 714, multimesh_instances = 623**.
  Spec statement 4 therefore means: instances ≥ **1246** (2×623),
  nodes < **900** (headroom = 186 nodes over baseline).

## Technical approach per spec statement

### 1. Walk cycle → `core/flap_rig.gd` + call sites
- In `FlapRig._build_body`, the two leg boxes and two arm boxes
  move onto pivot `Node3D`s at the hips (±0.11, 0.52, 0) and
  shoulders (±0.33, 1.095, 0); box sizes unchanged, child offsets
  chosen so the limb spans match the old static boxes
  (legs ≈ 0.02–0.52, arms ≈ 0.545–1.095). Head, hinge pivot,
  eyes, cap: **code untouched**.
- New core API on FlapRig: `walk_phase` (radians, advances with
  distance), `walk_swing` (current max |limb rotation|, for
  tests), `walk_stride` (rad per world unit, default 2.4 — a
  knob), and `tick_walk(delta)`: planar speed from the body's own
  `velocity`; phase += speed × delta × stride; a blend factor
  eases 0→1 while moving (8/s) and 1→0 when stopped, so limbs
  settle to neutral instead of freezing mid-swing. Legs swing
  ±sin(phase)·0.55·blend, arms ∓sin(phase)·0.38·blend (arm
  opposite the same-side leg).
- Call sites: `Player3D`, `Ped3D`, `Enemy3D` call `tick_walk`
  right after `move_and_slide()`, beside `tick_flap`.
  `Tank3D` extends `CharacterBody3D` directly (not FlapRig) —
  no limbs, unaffected.

### 2. Car variants → `gate3d/car3d.gd` + `gate3d_main.gd`
- `Car3D` gains `const PALETTE` (10 paints) with an instance
  mirror `paint_colors` (so tests can duck-read it), and
  `body_style: int` (set before `add_child`, read in `_ready`).
  Style 0 = sedan (today's geometry, verbatim). Style 1 =
  hatchback (3.3-long body, taller cabin shifted rearward).
  Style 2 = van (tall body, near-full-length glass cabin, flat
  roof). **Collision shape identical for all styles** —
  silhouette is visual only; physics and car numbers untouched.
- Wheels already rotate ∝ speed (Gate 3D-2: `spin_angle -=
  speed·delta/0.36`); this pass adds the autotest contract that
  locks that behavior in.
- `gate3d_main` assigns style = i % 3 and colour =
  PALETTE[i % size] across the 6 spawned cars (deterministic).

### 3. Signage + facade variance → `core/city_dressing.gd`, `core/city_builder.gd`
- `CityDressing.make_sign_material(accent, seed)`: generates a
  256×64 texture — dark panel, accent border, blocky glyph bars
  (name-like shapes) in accent + warm white — and returns an
  emissive material (emission from the same texture). Accent
  palette is Midnight-Circle-adjacent: violet C77DFF, gold
  FFD479, moonwater 7FDBCA, ember FF5370, herb 82C99A.
- `CityBuilder._building`: when a storefront band is placed,
  chance 0.55 (builder rng) to mount ONE sign: a single
  MeshInstance box (3.4 × 0.85 × 0.12) on the building face
  pointing away from the cluster centre (toward the pad edge /
  road), y = 3.1. One node per sign. Builder keeps registries
  for tests: `sign_count`, `sign_accents`, `sign_positions`.
- Facades: `CityDressing._make_facade` gains a `lit_ratio`
  parameter (was hard-coded 0.28); new
  `make_facade_material(base, seed, lit_ratio)` builds a
  per-building texture from its own seeded RNG. `_building`
  picks a **unique seed per building** (stronger than the spec's
  "adjacent differ") and lit_ratio ∈ [0.08, 0.50] from the
  builder rng; registries `facade_seeds`, `facade_lit_ratios`
  kept on the builder. The 6 shared facade materials stay for
  other core users. ~48 unique 128×192 textures ≈ 4.7 MB — fine.

### 4. Density → `core/city_builder.gd` (+ meshes in `core/city_dressing.gd`)
All new clutter is MultiMesh (1 node per type), placed with the
existing `_point_free` building-avoidance:
- **Bollards** along road edges (both sides, ±6.6, every 13
  units, both road orientations) ≈ 360 instances.
- **Traffic cones** scattered near roads ≈ 70.
- **Trash bags** near pads/dumpsters ≈ 90 (squashed spheres —
  `CityDressing.xf` gains a Vector3-scale sibling `xf3`).
- **Bushes** on pad edges ≈ 90 (foliage mesh, small scale).
- **Newspaper boxes** near cluster corners ≈ 36.
- **Cardboard piles** (flat boxes) ≈ 50.
- Increases: trees skip-chance 0.45 → 0.20 (~+35), crates/
  barriers attempts 26 → 70 (~+30), streetlight segments
  6 → 8 (~+28 heads+poles).
Estimated total ≈ 623 + ~790 ≈ **1410 instances** (slack for
`_point_free` rejections), nodes ≈ 714 + ~18 signs + 6 new
MultiMesh nodes ≈ **738** < 900.

## What does NOT change
- All gameplay numbers and data files (weapons, wanted, economy,
  upgrades, costs), the save file shape, controls, collision
  shapes (characters, cars, buildings), flap-head geometry /
  hinge / eye placement, the tank, scene structure, smoketest.
- Existing PASS lines are contracts: verbatim at every green.

## Risks (Celeron UHD 600 perf)
- MultiMesh instances cost vertex load only, 1 draw call per
  type; new meshes are ≤ SphereMesh 7×4 / short cylinders — the
  cheapest geometry in the scene. Node budget is the real
  constraint and is tested, not assumed.
- Per-building facade textures: one-time startup generation
  (48 × 128×192 fills), no per-frame cost; +48 materials on
  buildings that were already individually drawn.
- Signs are emissive materials, no new light nodes (the scene
  still has exactly one DirectionalLight).

## Tasks (each independently verifiable; TDD per task)
- **T0** Baseline: record counts + full suite green. *(done —
  this doc's Baseline section)*
- **T1 RED**: add autotest section 8 (`detail1`) with ALL spec
  checks written against duck-typed seams (`.get()`), run it,
  record the red output in the README gate section.
- **T2** Walk cycle (approach 1) → section-8 walk checks green.
- **T3** Car variants (approach 2) → car checks green.
- **T4** Signage + facade variance (approach 3) → signage
  checks green.
- **T5** Density (approach 4) → density checks green; full
  suite green.
- **T6 REFACTOR**: only after all green — tidy any duplication
  the four tasks introduced; suite identically green after.
- **T7 VALIDATE & REVIEW**: Xvfb screenshot framed on the first
  sign (the `--screenshot` debug path aims at
  `city.sign_positions[0]`), PIL pixel-check for accent colours;
  1200-frame run, zero script errors; smoketest; edge-case
  review (save compat, BUSTED, tank, firing-while-walking);
  export + in-export autotest; zip; README + SKELETON docs.

## Completion (2026-10-31)

- **T1 RED** — recorded: 12 FAIL lines (quoted in the README gate
  section). Head-guard checks (hinge pivot height, upper-head
  child count) and the wheel-spin check passed even in red, by
  design — they are regression guards.
- **T2–T5 GREEN** in order; one test-design fix en route: the
  ped walk check originally re-enabled a parked ped from the
  8-body pile at (100,100); a probe showed the ped depenetrates
  on top of the pile (y 0.2 → 1.86, planar velocity 0) and never
  walks — that tested pile physics, not the walk cycle. The
  check now spawns a fresh wandering ped in open space. The
  contract it verifies is unchanged.
- **T6 REFACTOR** — scene-census traversal deduplicated into
  `gate3d_main._scene_counts()` (used by `--countnodes` and the
  autotest); `FlapRig._limb()` replaces repeated pivot+box
  construction. Suite identically green after.
- **T7** — screenshot framed on sign #1: PIL pixel check found
  its accent (violet C77DFF) at 1,536 sampled pixels (≈6,100
  actual), glyph warm-whites 549, void panel 917. 1200-frame
  run: 0 script errors (419 headless artifacts). Final counts:
  **nodes = 796, MultiMesh instances ≈ 1,320** (2.1× baseline).
  Export verified in-binary (300 frames clean, all 4 autotest
  lines, all 4 smoketest lines). Zip:
  `builds/GODOT-Linux-Detail1.zip`.
