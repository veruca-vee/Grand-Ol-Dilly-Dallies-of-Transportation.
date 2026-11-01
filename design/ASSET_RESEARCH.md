# Asset Research — grab/build options to upgrade G.O.D.O.T's look & feel

Date: 2026-11-01. Direction: Vee ("grab and or build more assets to
upgrade the look and feel"). This is research + pipeline proof only —
**nothing in `engine/` was changed, no gate was touched, and `main`
on GitHub is untouched** (verified head `f3258ca` before and after).

Method note: licence terms below were read on the source pages
themselves today (kenney.nl / kenney-assets.itch.io / quaternius.com /
quaternius.itch.io / polyhaven.com/license / docs.ambientcg.com/license),
and every size/count marked **[measured]** comes from a file actually
downloaded to this VM today (`~/workspace/felony-city/assets-src/`).
Anything else is marked **[page-stated]**.

Style guardrails that shaped the ranking: PS2-era low-poly (San
Andreas, 2004), one consistent flat-shaded look, and the characters
stay ours — the flap-heads are Vee's signature and no character pack
below is ranked for replacing them.

---

## 1. GRAB inventory

### Kenney (all CC0, one author = one style family)

Licence text is identical across every Kenney pack page checked, e.g.
Car Kit on itch.io: *"License: CC0 1.0 Universal. You're allowed to
use these game assets in any project including commercial ones.
There's no need to ask permission before using these and giving
attribution is not required (but is appreciated!)"* — and the
`License.txt` inside each downloaded zip says the same: *"License:
(Creative Commons Zero, CC0) … You can use this content for personal,
educational, and commercial purposes."*

| Pack (version in zip) | Contents | Formats in zip | Zip size |
|---|---|---|---|
| **Car Kit (3.1)** | 50 model files **[measured]**: sedan, sedan-sports, hatchback-sports, suv, suv-luxury, taxi, **police**, van, delivery (+flat), truck (+flat), firetruck, ambulance, garbage-truck, race, race-future, 3 tractors, 5 karts, 8 separate wheels, cones, box, 13 debris pieces. Page says "Over 40 models / 45 assets" **[page-stated]** | GLB + FBX + OBJ (50 each) **[measured]** | **4,814,237 B** (sha256 `fac7daca…f3d0c4`) **[measured]** |
| **City Kit — Roads (2.2)** | 95 GLB files **[measured]**: road tiles, bridges/pillars, highways, lightposts, traffic lights, construction barriers/cones/fences. Page: "Over 65 models" **[page-stated]** | GLB + FBX + OBJ (95 each) **[measured]**; itch also lists DAE/STL **[page-stated]** | **2,852,289 B** **[measured]** |
| **City Kit — Suburban (2.0)** | 40 GLB **[measured]**: building-type houses/shops, driveways, trees (`tree-large/small`). kenney.nl lists "40× files"; itch says "35+ models" **[page-stated]** | GLB + FBX + OBJ **[measured]** | **3,038,740 B** **[measured]** |
| **City Kit — Commercial (2.1)** | 41 GLB **[measured]**: `building-a…h`, skyscrapers, low-detail wide buildings (good far-background shells). kenney.nl lists "50× files" **[page-stated]** | GLB + FBX + OBJ **[measured]** | **4,096,974 B** **[measured]** |
| **City Kit — Industrial (2.0)** | 37 GLB **[measured]**: factories, warehouses, tanks, windmills/solar. kenney.nl lists "40× files" **[page-stated]** | GLB + FBX + OBJ **[measured]** | **5,045,077 B** **[measured]** |
| **Modular Buildings (2.1)** | 108 GLB **[measured]**: wall/corner/roof/window pieces to assemble buildings of any height — the variety multiplier for the fixed shells above. itch: "Over 90 models", OBJ/FBX/glTF **[page-stated]** | GLB + FBX + OBJ **[measured]** | **1,825,490 B** **[measured]** |
| **Nature Kit (2.1)** | 329 GLB **[measured]**: trees (many variants/seasons), rocks, foliage, fences, bridges. kenney.nl lists "330× files", CC0 **[page-stated + measured licence]** | GLB + FBX + OBJ **[measured]** | **10,537,521 B** **[measured]** |
| **Blocky Characters** | 20 files, animated blocky people **[page-stated, kenney.nl]**, CC0 | OBJ/FBX/glTF family | — not downloaded. **Not for our cast** (flap-heads stay); only conceivable use is animation reference. |

Download quirk worth knowing: kenney.nl direct zip links now 403
without a browser flow. Working route (used for all of the above):
fetch the page with a browser UA, call
`https://kenney.nl/download-link/<hex("assets/<slug>")>` for a signed
URL, then download that. The old-style
`kenney.nl/media/pages/assets/…/kenney_<slug>.zip` links are dead.

### Quaternius (CC0, second style family — slightly chunkier)

- **Downtown City MegaKit** — itch page, read today: *"a pack of over
  300 modular environment pieces for building full Boston/NYC style
  city blocks … Free to use in personal, educational and commercial
  projects. (CC0 License) … .FBX, .OBJ and .glTF formats"*, 7 pre-built
  example buildings, shared optimized texture sets. The **Source**
  version adds Unity/**Godot**/Unreal projects with a fake-window-
  interior shader, vertex-colour wear and simple collisions (Source is
  a paid/Patreon tier; the models themselves stay CC0). Free
  **Standard** is a subset of the pack (the author's own framing in
  catalogue coverage: ~60–70% free). A third-party project that
  measured the Standard download reports 142 Godot `.gltf` + 36 shared
  textures and a ~223 MB zip — **[third-party measured, not
  re-downloaded here: too big to pull casually, and it is textured
  PBR-ish, so it needs a style test before any bulk grab]**.
- **Cars Pack** — quaternius.com pack page, read today: **8 models**
  (incl. police car, taxi, SUV), textured, **formats FBX / OBJ / Blend
  only on the author's own page** — no glTF there. The same pack as a
  **glTF/GLB bundle is on Poly Pizza** ("Cars Bundle", 8 models),
  which states *"Licence: Public Domain (CC0)"* for it. So: grab via
  Poly Pizza for Godot-ready files, or convert OBJ→GLB ourselves.
- **Public Transport Pack** — 12 vehicles (ambulance, school bus,
  train…), CC0 per catalogue listings, FBX/OBJ/Blend. **[listing-
  verified only — read the pack page before use]**

Correction to our older notes: `assets/PREMADE.md` (2026-10-29)
carried a guide-based caution that Quaternius assets "do not
redistribute." Today's source pages state plain CC0 with no such
clause visible, and the CC0 deed itself permits redistribution. The
caution is **superseded by the source-page check**; treat Quaternius
as ordinary CC0. (KayKit, below, does print a courtesy *ask* — "please
don't resell unmodified copies or claim them as your own" — next to
its CC0 licence. An ask, not a licence bar; honour it anyway.)

### KayKit (Kay Lousberg) — CC0, third family

- **City Builder Bits** — modular city buildings, roads, vehicles,
  street props; itch bundle pages state *"Licensed for personal and
  commercial use, no attribution required. (CC0 License)"* and
  OBJ/FBX/GLTF formats. Stylistically chunkier/more toy-like than
  Kenney; a style-test candidate, not a first grab. Character packs
  (Adventurers etc.) are CC0 too but fantasy-themed and, per the
  guardrail above, not for our cast.

### CC0 textures (surfaces — where our procedural city is weakest)

- **ambientCG** — licence page (docs.ambientcg.com/license), read
  today: *"All ambientCG assets are provided under the Creative
  Commons CC0 1.0 Universal License … You can include the raw files
  in your project, for example a video game."* 2,000+ PBR materials
  with a free no-key API. **[measured]** `Asphalt012` **1K-JPG** set
  downloaded today: **8,507,722 B** zip containing Color,
  Displacement, NormalDX, NormalGL, Opacity, Roughness (+ `.blend`/
  `.usdc`). For a PS2 look we'd take the 1K colour map only and crush
  it to 256–512 px — period muddiness, honestly sourced.
- **Poly Haven** — licence page, read today: *"Our assets are all
  licensed as CC0 … You can use our assets for any purpose, including
  commercial work. You do not need to give credit … You can
  redistribute them."* Library size via its public API today:
  **869 textures, 997 HDRIs, 521 models [measured via API]**.
  **[measured via API]** `aerial_asphalt_01`: 1K diffuse JPG is
  635,143 B (2K 2,802,005 B; 8K 37,506,182 B — do not grab 8K for
  this game). HDRIs are the interesting half for us: one CC0 sky
  HDRI, downscaled, is a whole mood/lighting upgrade (see §4).
- Caution (not CC0): **Poly Pizza / Sketchfab** mix CC0 and
  **CC-BY per model** — filter to CC0 only, per model, every time.
  **FreePBR** is personal-use-only for free. Neither is ranked.

### CC0 audio (one line each — noted, not grabbed)

- **Kenney audio packs** (Impact Sounds — 130 files, CC0 on
  kenney.nl today; also Interface / Sci-fi / Digital Audio / RPG
  Audio, all CC0 `.ogg`): cohesive drop-in SFX for impacts/UI; no
  engine hum or siren loop in them.
- **Freesound, CC0 filter only**: the place for a real siren/engine/
  city ambience (700k+ sounds, per-sound licences CC0 / CC-BY /
  CC-BY-NC — the CC0 filter is mandatory, and full downloads need a
  free account).

### Top 5 for THIS game, ranked

1. **Kenney Car Kit** — replaces all three procedural car silhouettes
   with 17 real vehicles incl. police/taxi, wheels as separate named
   nodes (spin/steer code already expects that), and it's the pack
   **proven end-to-end in §2 today**.
2. **Kenney City Kit (Roads)** — traffic lights, lightposts, barriers,
   bridge pieces: exactly the street furniture our dressing pass fakes
   with boxes, for 2.9 MB.
3. **Quaternius Downtown City MegaKit (Standard)** — the single
   biggest building-variety jump available free (300+ modular pieces,
   shared textures); ranked third only because it's heavy and needs
   a style test against the flat Kenney look first.
4. **Kenney City Kit Commercial + Suburban (+ Industrial)** — building
   shells in the same style family as #1/#2, including low-detail
   wide buildings that read perfectly through PS2 fog as background.
5. **Kenney Modular Buildings** — 108 facade pieces for 1.8 MB; turns
   #4's fixed shells into mix-and-match variety so blocks stop
   repeating. (Runner-up: Nature Kit — 329 trees/rocks; our trees are
   cones on sticks, so this is a real upgrade too, just less urgent.)

Total cost of the full Kenney city stack above (Cars + Roads +
Suburban + Commercial + Industrial + Modular + Nature): **~32 MB of
zips, all already sitting in `assets-src/`**, all CC0.

---

## 2. PIPELINE PROOF — Kenney Car Kit `sedan.glb` in Godot 4.3

Pack chosen: Kenney Car Kit (smallest complete vehicle pack, and the
one we'd integrate first). Scratch project:
`~/workspace/felony-city/assets-src/scratch-import/` — the game's
`engine/` tree was not touched.

**Download.** Signed-link route (see §1). Zip: 4,814,237 B, sha256
`fac7dacac5c7874348cf19729af3ef205f3d366493edaf0a827d93f4fdf3d0c4`
— which matches the independently published Car Kit 3.1 archive hash
in another project's source manifest, a nice provenance cross-check.
Zip's `License.txt` = CC0 (quoted in §1). Extracted: 15 MB; the
`Models/GLB format/` folder is 5.5 MB for all 50 GLBs.

**Model facts (parsed from the GLB header/JSON directly):**
`sedan.glb` = 172,216 B, **2,032 triangles**, 3,184 verts, 5 meshes /
5 nodes — `body` + `wheel-front-left/right`, `wheel-back-left/right`
as separate named nodes (wheel spin and front-wheel steering map
straight onto our existing car code). Whole-kit average is 1,304
tris/model (65,235 tris across all 50 GLBs) — comfortably PS2-budget.

**⚠ The one real pipeline gotcha:** the GLB's texture is **external**
— `images[0].uri = "Textures/colormap.png"` (a single shared 512×512
palette atlas for the whole kit, one material named `colormap`,
metallic 0.0). Copy the `.glb` alone and it imports **untextured**.
The folder structure `Models/GLB format/Textures/colormap.png` must
be preserved (or the texture embedded) at integration time. This is
also a repo-hygiene point: the atlas is shared, so it should live in
the repo **once**, not per model.

**Import (headless, `godot --headless --import`):** clean, exit 0.
One non-fatal warning — *"Ignoring face with non-finite normal in
LOD generation"* (importer LOD pass; the mesh itself is fine, and
LOD generation can be disabled per-import if it ever matters).

**Run (headless):** verbatim output —

```
ASSET_LOADED: sedan.glb instanced, children=5
ASSET_TRIS: 2032
ASSET_AABB: size=(1.5, 1.3, 2.55) pos=(-0.75, 0, -1.3)
ASSET_MAT: body/s0: colormap albedo_texture=res://models/Textures/colormap.png ((512, 512))
ASSET_MAT: wheel-front-right/s0: colormap … (same shared material on all 5)
ASSET_RUN_OK frames=20
```

(The trailing dummy-renderer `mesh_get_surface_count` lines are the
known headless artifact from Gate 3D-0, not import errors.)

**Scale check — the second gotcha.** At native scale the sedan is
**1.5 wide × 1.3 high × 2.55 long**. Beside a flap-head person built
at FlapRig's exact dimensions (~1.49 tall) it looks toy-short, and
our current procedural cars are **1.8 × ~1.5 × 4.0** with a collision
box of 1.8×1.1×4.0. Integration will need a uniform **≈×1.55 scale**
(2.55 → ~3.95 long) or a deliberate decision to rescale the world
around Kenney proportions. Flagged, not decided — that's a gate-spec
question, and the collision shape must follow whichever wins.

**Screenshot (Xvfb, gl_compatibility, 1280×720):**
`assets-src/scratch-import/shot.png` — the sedan renders **textured**:
red body from the palette atlas, pale windshield, yellow headlights,
dark wheels with hub detail; the violet-shirted flap-head stands
beside it for scale. Pixel check (PIL): 1,531 unique colours in
frame; **2,950 red car-body pixels** (0.32 % of frame) and 1,428
near-white pixels (windshield/plate) — i.e. the colour is coming from
the atlas texture, not a flat material fallback. **Verdict: the
grab → import → render pipeline works, cleanly, in our exact Godot
4.3, with exactly two known integration tasks (preserve the
`Textures/` folder; decide the ×1.55 scale question).**

---

## 3. BINARY DELIVERY PROOF — real git over SSH from this VM

Question: the repo syncs via the connector's snapshot push, which
accepts UTF-8 text only. Can binaries live in the repo at all?
**Answer: YES — via real `git` over SSH from this VM. Proven
end-to-end today, then fully cleaned up.** It is, however, *flaky*:
see the timeout notes — budget retries into any future workflow.

Setup found on the VM: `~/.ssh/config` already has a `github.com`
host entry (ssh.github.com:443, key `~/.ssh/github-vee`, via the
CONNECT proxy helper `~/workspace/bin/github-ssh-proxy.py`), so
`GIT_SSH_COMMAND="ssh -F /home/hatch/.ssh/config"` is all git needs.

Step-by-step, actual outputs:

1. **Auth:** `ssh -T git@github.com` →
   *"Hi veruca-vee! You've successfully authenticated, but GitHub
   does not provide shell access."*
2. **Clone** (note the repo name ends in a period, so the URL has
   `..git`): `git clone git@github.com:veruca-vee/Grand-Ol-Dilly-Dallies-of-Transportation..git`
   → success; `git log` head =
   `f3258ca Playtest telemetry … + wanted pacing fix …`, i.e.
   `main` at `f3258ca38f6c89481088dea978c88d60a113c0bc` as expected.
3. **Branch + binary commit:** new branch `asset-pipeline-test`;
   added `assets-src-test/models/sedan.glb` (+ its
   `Textures/colormap.png` and the CC0 `License.txt`); commit
   `3cb8cfa2be82f16d4ac3f8600664437a6ff8b826`.
4. **Push — the flaky part.** First push and ~6 retries over ~15 min
   failed identically:
   `github-ssh-proxy.py line 39 … TimeoutError: timed out` →
   *"Connection closed by UNKNOWN port 65535 / fatal: Could not read
   from remote repository."* Root cause shape: the proxy helper
   allows a **20 s timeout on the egress proxy's CONNECT response**,
   and that handshake intermittently takes longer (the successful
   `ssh -T` took 17 s; the successful clone ~11 s). Reads *and*
   writes are equally affected — it's transport weather, not a
   permissions or size problem (the payload is 185 KB). The
   connector (HTTPS) confirmed mid-failure that the branch did
   **not** exist, so the failed pushes landed nothing.
   Then, on a further retry: *"*[new branch] asset-pipeline-test ->
   asset-pipeline-test"*, and `git ls-remote` showed
   `3cb8cfa2be82f… refs/heads/asset-pipeline-test` — the push lands
   whole or not at all; just retry.
5. **Verify via the GitHub connector** (`get_file_contents` with
   `ref=asset-pipeline-test` — the parameter is `ref`, not `branch`):
   *"successfully downloaded binary file (SHA:
   6bc9f1e3f9f30e51307c3454ff00cbbbb0d79d49)"* for `sedan.glb`, blob
   content starting with the `glTF` header; `colormap.png` blob
   `5c4b1857dafd7abd1ca9836285f1bd589f75ccb0`; `License.txt` blob
   `60bca66ec72bbcb23fc0894d36d0f4a174cccd3e`. All three **match
   `git hash-object` / `git ls-tree` on the local clone exactly** —
   the binary on GitHub is byte-for-byte the file tested in §2.
6. **Cleanup:** `git push origin --delete asset-pipeline-test` →
   *" - [deleted] asset-pipeline-test"* (first try). `git ls-remote`
   afterwards shows only `main`, still at
   `f3258ca38f6c89481088dea978c88d60a113c0bc` — **main untouched**.
   The connector now answers *"could not resolve ref
   asset-pipeline-test"* for the deleted branch. Test clone removed.

**Consequences for the workflow** (for HQ/Vee to decide, not decided
here): asset integration means a **dual-track repo workflow** —
text/code keeps the snapshot-push route; binary assets go through
real git (clone → add → commit → push, with a retry loop for the
CONNECT timeouts, and pull/fetch-back verification per the standing
full-workflow rule). One hygiene flag: `assets-src/` (46 MB of zips
and extracted packs) currently sits *inside* the felony-city tree —
it must stay out of any snapshot-push manifest (like `builds/`),
whether or not the curated subset later moves into the repo via git.

---

## 4. BUILD-side options — what our procedural pipeline can still add

If grabbing is deferred, these are the cheapest look/feel wins the
existing GDScript dressing pipeline can grow on its own:

- **Sky + lighting mood pass (S)** — one `WorldEnvironment`: gradient
  or downscaled CC0 HDRI sky, warm low sun, matched fog colour. Our
  fog already exists; giving it a sky to blend *into* is the single
  biggest atmosphere-per-line change available.
- **Runtime grunge textures (M)** — generate asphalt/concrete/brick
  albedos procedurally at load (noise + wear blotches + edge darkening
  on the existing facade generator), downscaled-res and tiled. Attacks
  the same flatness textures would, with zero binary files — the
  snapshot-push route stays sufficient.
- **Decal wear layer (M)** — MultiMesh'd flat quads: oil stains,
  cracks, posters, graffiti-ish colour blocks, manhole covers, tyre
  arcs at corners. Cheap instances, huge street-readability payoff,
  same system as Detail Pass 1's clutter.
- **Sign & prop variety round 2 (S)** — more sign glyph palettes/
  shapes (vertical blades, awnings with text-ish bars), plus 3–4 new
  prop families (hydrant, mailbox, phone booth, hot-dog cart) from
  the existing box/cylinder vocabulary.
- **Vertex-colour dirt gradient on buildings (S)** — darken facades
  toward street level and vary per-face tint in `city_builder` —
  kills the "clean toy block" read that makes the current city look
  newer than 2004.

---

## Bottom line

Grabbing is **unblocked**: the best packs are CC0, tiny, already
downloaded and licence-checked; a Kenney model imports and renders
textured in our Godot today; and binaries **can** live in the repo
via git-over-SSH (with retry tolerance), even though the snapshot
push can't carry them. The two honest integration costs are the
shared-atlas folder structure and the ≈×1.55 vehicle scale decision.
Nothing was integrated — that's the next gate's call.
