# DETAIL PASS 1 — SPEC: "The street feels inhabited"

Status: direction is Vee's (Kimi-bar detail work, unlocked after
the Engine Core gate, 2026-10-30; "and go" given 2026-10-30).
This spec's specific statements are the assistant's first draft
under METHOD.md step 0/1 — Vee can strike or amend any line; the
rest proceeds. All work runs METHOD.md: tasks are TDD, red first.

## Behavior statements (each must be checkable)

1. **People move like people.** On-foot characters (player, peds,
   enemies) swing arms and legs in a walk cycle while moving;
   swing phase advances with distance travelled and stops when
   they stop. The flap-head rig is untouched (heads, hinge, eyes
   identical).
2. **Cars are not one car.** At least 3 distinct body silhouettes
   (e.g. sedan / hatch / boxy van-ish) in a paint palette of at
   least 8 colors; wheels visibly rotate proportional to speed.
3. **Buildings have something to say.** Storefronts carry
   emissive signage: at least 12 signs across the city, generated
   textures (name-like glyphs/shapes, Midnight-Circle-adjacent
   accent colors allowed), readable as lit signs at dusk fog
   distance. Per-building lit-window ratio varies (no two
   adjacent buildings share the same facade seed).
4. **Streets have clutter density.** Prop instances (all
   MultiMesh/shared-geometry) at least double the Gate 3D-2 count
   while total scene node count stays under 900 and the dressed
   scene still runs the standard verification (1200 frames, zero
   script errors).
5. **Nothing regresses.** All existing AUTOTEST PASS lines print
   verbatim; SMOKETEST still passes; existing numbers, controls,
   save format unchanged. New checks print as a new PASS line:
   `AUTOTEST PASS: detail1 walk_cycle car_variants signage density_budget`.

## Out of scope for this pass

- Interiors, enterable buildings, day/night cycle, new weapons
  or enemies, any change to the save file shape.
- Building collision changes (props stay non-colliding, as
  labelled since Gate 3D-2).

## Success criteria

- The new PASS line above, in the project AND the exported
  binary, preceded by a recorded RED run of the same checks
  (METHOD.md evidence rule).
- One Xvfb screenshot of a signed storefront street, pixel-checked
  for the sign accent colors (the Gate 3D-2 precedent).
- Perf figures reported: node count, MultiMesh instance count.
