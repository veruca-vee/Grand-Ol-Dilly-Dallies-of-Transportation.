# Pre-made assets — checked shortlist (2026-10-29)

Yes, there are pre-made assets we can use. Best fits for a PS2-level
Godot city game, licences checked from the sources below. Nothing is
downloaded or integrated yet — see the binary warning at the end.

## Tier 1 — CC0, use freely, no attribution required

- **Kenney City Kit (Roads)** — 65+ road models (barriers, highways,
  lightposts, construction), OBJ/FBX/DAE/STL/glTF, "works with Godot",
  licence CC0. https://kenney-assets.itch.io/city-kit-roads
- **Kenney City Kits (Suburban / Industrial / Building Kit / Modular
  Buildings)** — same author, same CC0 terms, same formats. One author
  = one consistent style across the whole city, which matters more
  than any single model.
- **Kenney Starter Kit: City Builder (Godot)** — a Godot 4 city-builder
  template using GridMap, models + sounds CC0, code MIT, on the Godot
  Asset Library and GitHub. Even if we don't use the template, its
  GridMap layout is the proven way to place Kenney city tiles.
- **KayKit (Kay Lousberg)** — low-poly character packs, rigged and
  animated, free packs are CC0 per the guides checked; GLTF/FBX/OBJ.
  Characters are fantasy-themed (adventurers etc.), so: rigs and
  animations are reusable, the outfits mostly are not our setting.

## Tier 2 — free, but licence has a string

- **Quaternius** — Ultimate Animated Character Pack (50+ characters)
  and city/vehicle-adjacent packs. Licence per guides checked: free
  for commercial use, no attribution, but **do not redistribute the
  asset files themselves** — which means don't commit the raw packs
  to this public repo; keep them local / gitignored, ship only inside
  a built game.

## Tier 3 — closest to the PS2 look, check every pack

- **PSX/retro packs on itch.io** (e.g. Elbolilloduro's Characters PSX,
  PSX-style cars/buildings) — visually nearest to "San Andreas when it
  came out", but licences vary pack by pack. Nothing from here goes
  in until its own licence page is read.

## Textures / surfaces

- **Poly Haven / AmbientCG** — CC0 textures and HDRIs. Mostly too
  high-res for PS2 level; usable downscaled, which is also how you
  get period-correct muddiness honestly.

## Binary warning (hard limit, not a preference)

The GitHub connector push used for this repo only accepts UTF-8 text
files. Model files (.glb/.fbx/.blend) and textures are binary and
**cannot** be pushed that way. Integrating a pack therefore needs a
real `git clone → add → push` from a machine with Vee's GitHub login
(her laptop), or the packs stay local and gitignored while the code
that loads them is pushed. Decide at integration time, not before.
