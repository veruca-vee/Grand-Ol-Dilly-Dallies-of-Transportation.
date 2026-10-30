# Felony City — Skeleton

Rule (Vee's brainstorming rule, 2026-10-20/25): slots are filled only with
what Vee said in plain words. Blanks stay blank. One open question at a time.
No files were built for the PS2-GTA idea in 2026-10-25 — this file is the
first scaffold, created 2026-10-29 at Vee's direction in this chat:
"Bring it out of HTML and into an actual scaffolding and an actual engine
and an actual simulator"

## Filled — from Vee

- **Name (Vee, 2026-10-29): G.O.D.O.T** — "G=Grand O=Ol D=Dilly-Dallies
  O=Of T=Transportation": **Grand Ol' Dilly-Dallies Of Transportation**.
  Repo: veruca-vee/Grand-Ol-Dilly-Dallies-of-Transportation. (the repo
  name on GitHub literally ends in a period — verified in search results
  2026-10-29, and its description is "G.O.D.O.T")
- **Form — SUPERSEDED 2026-10-29 by Vee, in her words:** "Let's ditch
  the top down and shoot for PlayStation two level. Like San Andreas.
  But like when it came out"
  → Current form: **PS2-era 3D, third-person, San Andreas at launch
  (2004) as the level to aim at** — not GTA 1 top-down, not modern AAA.
  [interpretation, labelled: low-poly 3D city, third-person on foot /
  in car, draw-distance fog and period texture/model budgets are what
  "PS2 level, like when it came out" points at; the budgets themselves
  are a Gate-3D spec still to write, not Vee's words.]
  The Gate 0 top-down greybox stays in the repo as the systems
  prototype (data, wanted, economy, simulator all carry over); its
  camera/view does NOT carry over.
- **Form — original, superseded (kept for history):** "like its
  predecessors with today's graphics but just like good old Grand
  Theft Vehicle number one" (Vee, 2026-10-29, earlier this chat)
- **Source of truth for systems:** the two HTML versions Vee pasted
  2026-10-29 (multi-mode v2 + mobile-only v1). All numbers in `data/`
  are copied from that HTML, not invented.
- **Asset pipeline [earlier proposal, not yet re-confirmed for this build]:**
  Vee, 2026-10-25: assets start as emojis, are "meticulously scaffolded"
  and filled with generated images, then saved. Continuity at asset
  creation via Gemini / apparently ChatGPT.

- **Character look (Gate 0 stipulation, Vee 2026-10-29):** "The characters
  must look similar to the way the Canadians look in South Park."
  [design translation, labelled: simple flat bodies, beady close-set eyes,
  and a head split horizontally at the mouth — the whole top half of the
  head flaps up/down when the character talks/shouts. Placeholder draw
  code implements the flap + beady eyes; no South Park art is copied.]
- **Build order (Vee approved 2026-10-29):** Gate 0 greybox in Godot —
  engine with placeholder assets first, then simulator, asset spec,
  one vertical-slice asset set, then bulk assets. Her words: "You can
  start Gate Zero"

## Blank — not decided

- **Engine:** Godot 4 — *in use for Gate 0 at Vee's "start Gate Zero"
  go-ahead on the Godot greybox option presented to her (2026-10-29);
  not separately re-named by her in words.*
- **Setting / city name & era:** ______ (HTML uses a generic 3600-unit
  grid city, no named setting)
- **Player character:** ______ (HTML is an unnamed green circle)
- **Platform target:** ______ (HTML ran mobile + desktop; engine export
  target not yet stated)

## Gate 0 status (2026-10-29, verified)

- Built in `engine/` (Godot 4.3): main/city/player/car/ped/enemy/bullet/
  pickup/HUD, data loaded from `engine/data/*.json`.
- Verified on the real surface, this VM, Godot 4.3.stable headless:
  simulator ran and printed PASS on fractional-wanted indexing plus
  combat/economy tables; the game itself ran 1200 frames with zero
  script errors after a one-time `--import` (builds the class cache).
  One parse fix was needed and made during verification (simulator
  type inference). Greybox visuals themselves are [unverified] — only
  Vee running it windowed can confirm the flap-head look reads right.
- Simulator caveat: shotgun time-to-kill counts one pellet per shot,
  the weapon fires 6 — its sim TTK is an overestimate by design of the
  simplification, noted here so nobody quotes it as exact.

## Settled in the HTML itself (receipt: code Vee pasted)

- Top-down, single player, start on foot in city centre
- Steal/drive any car, drive-by shooting, run over peds
- Wanted 0–6 stars, decays after 600 frames idle, cops→SWAT→military→tank
- 9 weapons, 5 Black Market upgrades, cash/score/combo, local save
