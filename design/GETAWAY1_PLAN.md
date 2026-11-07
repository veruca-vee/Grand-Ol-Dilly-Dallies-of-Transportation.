# GETAWAY 1 — plan (from GETAWAY1_SPEC)
Base main 7e492ba, branch getaway1-kimi-sedan. TDD per task.

## T0 intake + probe — DONE 2026-11-07
- sha256/size verified against the delivery confirmation
  (fae37011..., 165,424 bytes; preview PNG 69b2a993..., 860,197).
- GLB parsed in Python: nodes/materials/tris/dims/wheels/forward
  all measured; results recorded in GETAWAY1_SPEC (probe section).
  Delivery-note claims matched except length 4.80 claimed vs
  4.759 measured — measured wins.

## T1 RED — autotest section 14 first
Write section 14 in gate3d_main.gd per S1-S5 (find cars[0],
assert model, scale AABB bounds, FL/FR wheel z<0 orientation
evidence + wheel set size 4, spin: drive the car and measure a
front wheel's basis change, steer: front yaw vs rear via basis).
Run autotest on the branch WITHOUT the asset/config: record the
FAIL lines here.
### RED record
2026-11-07, branch getaway1-kimi-sedan, section 14 written, no
asset/config yet: autotest exit 1, the 9 existing PASS lines all
printed, section 14 FAIL lines:
- kimi_sedan: fleet spot 0 is 'sedan', expected the getaway sedan
- kimi_sedan: res://assets/kimi_getaway/Felony_City_Getaway_Sedan.glb does not resolve in the tree
- scale: getaway sedan visual width 2.33, expected within 0.3 of the 1.8 collision width (measured on the Kenney sedan currently at spot 0)
- wheels_spin: getaway rear axle tilt 0.88 under steering, expected ~0 (on kit wheels the axle measure conflates spin; under axle-mode spin the axle is spin-invariant by construction — the check is written for the sedan's wheel mode, S4)
Log: results-getaway1/red_autotest.log (test workspace).

## T2 GREEN — minimum integration
- Copy GLB -> engine/assets/kimi_getaway/ + PROVENANCE.md.
- Car3D: per-model config table keyed by model_name:
  {dir, scale, flip_y, wheel_r, wheel_mode}. Kenney entries carry
  today's exact values (kenney_car_kit, 1.55, PI flip, 0.465,
  "kit"). Sedan entry: kimi_getaway dir, scale 0.8406, no flip,
  wheel_r 0.40 (native; effective divisor = wheel_r x scale),
  wheel_mode "axle".
- Wheel collection: kit mode keeps name match wheel-front-*/
  wheel-back-*; axle mode matches Wheel_FL/FR (front) and
  Wheel_RL/RR, storing each wheel's home basis.
- Physics loop: kit mode unchanged; axle mode composes
  basis = Basis(UP, yaw_if_front) * home * Basis(Z, spin_angle)
  with spin_angle integrated exactly like the kit path
  (spin_angle -= speed*delta/(wheel_r*scale) for this model —
  implemented as per-model spin divisor).
- gate3d_main: car_models[0] -> "getaway_sedan" (model_name key);
  fleet list otherwise unchanged.
### GREEN record
2026-11-07: asset + PROVENANCE.md in engine/assets/kimi_getaway/
(sha256 of the in-repo copy re-verified fae37011...). Car3D
per-model config shipped as spec'd (Kenney entries carry the old
constants; MODEL_SCALE restored as a public const mid-task —
gate3d_main's service dressing references Car3D.MODEL_SCALE, a
parse error the first GREEN run caught and this fixed).
gate3d_main: spot 0 -> getaway_sedan; section 13 atlas probe
walks the whole fleet (labelled test-design correction in code:
the contract is "atlas on a fleet car", spot 0 is now the
untextured sedan). Result: import 0 errors, autotest exit 0,
10/10 PASS lines including the new getaway1 line verbatim.
One catch during the run: an early GREEN attempt hung because
the parse error left the main scene unloadable — the import log
named it exactly (MODEL_SCALE), fixed before the passing run.

## T3 REFACTOR
Suite identically green (10 AUTOTEST lines), 1200 frames clean,
data hashes unchanged, parity + parser tests still PASS.
### Record
2026-11-07: full harness suite2 run (results-getaway1/suite2):
C1-C6 all PASS — import 0 errors, smoketest 5/5, autotest
10/10, 1200 frames 0 script errors, data hashes unchanged.
DATA PARITY PASS and PARSER SELFTEST PASS re-run on the branch.
(The first harness attempt was interrupted mid-autotest by a
service restart; re-run from scratch rather than trusted.)

## T4 verification beyond the suite
- C1-C6 via run_checks.sh at 4.7.2 on this branch.
- Export with isolated 4.7.2 templates; clean-dir (binary alone)
  autotest 10/10; Xvfb --carshot/--screenshot/--markshot on the
  exported binary; carshot = sedan framed (cars[0]).
### Record
2026-11-07: export exit 0 (binary sha256 aa48d045...b005bc).
Clean-dir proof: binary alone in /tmp/clean-getaway1 — autotest
10/10 exit 0, getaway1 line inside the binary. Xvfb on the
exported binary: --carshot (frames cars[0] = the sedan) exit 0,
1280x720, 6,889 unique colours, the dark sedan visible in frame
at its spot; --screenshot and --markshot also exit 0. Real-
hardware look stays [unverified] until Vee plays it.

## T5 ship
Commit on getaway1-kimi-sedan (asset, PROVENANCE, spec, plan,
Car3D, gate3d_main, SKELETON + gate README status), push branch,
fetch-verify; fast-forward main ONLY if every check above is
green; fetch/pull back and verify local == remote by hash +
connector content spot-check (spec files + project state; the
GLB itself rides real git).
### Record
Shipped 2026-11-07: commit 3265dae81b79b0e643e68a1569e36e9144fe895a
on getaway1-kimi-sedan, pushed (local == remote), pre-FF guard
main still 7e492ba, fast-forward main 7e492ba -> 3265dae,
fetch/pull back local main == origin/main == ls-remote ==
3265dae, tree clean. Connector spot-check: GETAWAY1_SPEC.md
blob 4377800d == local; PROVENANCE.md present on main; in-repo
GLB sha256 fae37011... matches intake. (Post-ship doc edit: this
record itself rides a follow-up commit.)
