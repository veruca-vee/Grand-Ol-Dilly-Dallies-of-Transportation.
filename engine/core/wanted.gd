class_name Wanted
extends RefCounted

# ENGINE CORE — the wanted model: a FLOAT level (fractional gains
# accumulate; stars are floori(level) — indexing tables with the raw
# float was the source HTML's bug, fixed in every port since), the
# per-star active-enemy caps, the spawn-type table, the decay rule,
# and the spawn director's POLICY (may another enemy spawn, and does
# the spawn roll pass). Placement and instantiation stay in the game
# layer, which owns the scene and the enemy classes.
#
# Extracted from gate3d_main.gd in the Engine Core gate (step 5).
# All tables come from the game's data (G.O.D.O.T: the "wanted"
# block of data/enemies_world_wanted.json).

var level: float = 0.0
var frames_since_crime: int = 0
var max_stars: int = 6
var caps: Array = [0, 3, 6, 10, 15, 22, 30]
var spawn_types: Array = ["cop"]
var decay_frames: int = 600
# How much ONE decay step removes. Default 1.0 (a whole star, the
# original behaviour); a game whose pacing wants gentler decay
# passes its own value in the config (G.O.D.O.T's data: 0.25).
var decay_step: float = 1.0

func setup(cfg: Dictionary) -> void:
	max_stars = int(cfg.get("max_stars", 6))
	caps = cfg.get("max_active_enemies_by_star", caps)
	spawn_types = cfg.get("spawn_type_by_star_index_0_based", spawn_types)
	decay_frames = int(cfg.get("decay_frames_without_crime", 600))
	decay_step = float(cfg.get("decay_step", 1.0))

func add(amt: float) -> void:
	level = minf(float(max_stars), level + amt)
	frames_since_crime = 0

func stars() -> int:
	return mini(floori(level), max_stars)

func cap(stars_: int) -> int:
	return int(caps[mini(stars_, caps.size() - 1)])

func spawn_type(stars_: int) -> String:
	return str(spawn_types[mini(maxi(stars_ - 1, 0), spawn_types.size() - 1)])

# Per-physics-frame decay tick; true on the frame a decay step
# lands (a whole star at the default decay_step, less if the
# game's config says so — the level is a float either way).
func tick() -> bool:
	if level <= 0.0:
		return false
	frames_since_crime += 1
	if frames_since_crime > decay_frames:
		frames_since_crime = 0
		level = maxf(0.0, level - decay_step)
		return true
	return false

# --- spawn director policy ---
func can_spawn(stars_: int, active: int) -> bool:
	return stars_ > 0 and active < cap(stars_)

func spawn_roll(stars_: int, force: bool) -> bool:
	if force:
		return true
	return randf() < 0.02 + stars_ * 0.005
