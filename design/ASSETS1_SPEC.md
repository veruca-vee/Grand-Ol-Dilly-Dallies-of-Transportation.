# ASSETS STEP 1 — SPEC: "Kenney fleet"

Status: Vee's decision 2026-11-01 ("a = step 1, b = step 2, or
basically c" — cars first, city kits second, phased hybrid).
Runs under METHOD.md (TDD, red first). Research basis:
design/ASSET_RESEARCH.md (licenses CC0 verified on source pages;
import proof passed; binary git delivery proven with retries).

## Behavior statements (each checkable)

1. **The fleet is models now.** Drivable/parked/AI cars render
   Kenney Car Kit GLBs: at least 5 distinct models in the live
   fleet (from sedan / hatchback / taxi / van / truck as the kit
   names them), plus service vehicles (ambulance / firetruck /
   garbage-truck) as parked street dressing where the kit
   provides them. Procedural car bodies retire (the Detail 1
   dressed-box builder is removed or bypassed, not left as a
   second fleet).
2. **Scale honesty.** Models scale x1.55 (research measurement:
   native sedan length 2.55 vs our 4.0) so the visual matches
   the EXISTING collision box; physics, speeds, enter/exit,
   run-over, bonk — all unchanged.
3. **Wheels still spin.** The kit's wheels are separate named
   nodes; they rotate proportional to speed and front wheels
   steer, same contract as Detail 1, now on the GLB nodes.
4. **The atlas travels.** engine/assets/kenney_car_kit/ holds
   the GLBs + Textures/colormap.png + License.txt; the exported
   binary renders textured cars with no access to the source
   tree (verified by running the export from a clean dir).
5. **Contract supersession, on the record.** Detail 1's
   car_variants sub-checks (3 procedural silhouettes / 8 paint
   colors) are superseded by statement 1-3 and move to a new
   PASS line: `AUTOTEST PASS: assets1 kenney_fleet scale
   wheels_spin atlas`. The detail1 line keeps asserting
   walk_cycle / signage / density_budget verbatim; the change
   and its reason are written in the gate README, never silent.
6. **Nothing else regresses.** All other PASS lines verbatim;
   node budget < 900 still holds; 1200-frame run 0 script
   errors; telemetry untouched.

## Out of scope (Step 2, later)

- City kits (roads/buildings), Quaternius, textures, audio.
- Cop cars as pursuers (the police GLB may appear parked;
  enemy cars are a gameplay gate, not an asset swap).
