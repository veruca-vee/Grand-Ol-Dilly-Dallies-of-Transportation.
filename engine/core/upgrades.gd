class_name Upgrades
extends RefCounted

# ENGINE CORE — the shop model: upgrade definitions, owned levels,
# and the cost rule floor(base_cost * growth ^ level). Effects are
# data too: each def carries base + inc_per_level, and effect_value()
# is base + inc * level — how a game BINDS an effect to its actor
# (max hp, walk speed, ...) stays in the game layer.
#
# Extracted from gate3d_main.gd in the Engine Core gate (step 4).
# The defs come from the game's data file (data/upgrades.json in
# G.O.D.O.T); the growth factor is the game's config, read from its
# cost_formula there (1.4), passed in at setup.

var defs: Array = []
var by_id: Dictionary = {}
var levels: Dictionary = {}  # id -> int level
var growth: float = 1.4

func setup(defs_array: Array, cost_growth: float = 1.4) -> void:
	defs = defs_array
	growth = cost_growth
	by_id.clear()
	levels.clear()
	for d in defs:
		var uid := str(d.get("id", ""))
		by_id[uid] = d
		levels[uid] = 0

func has(uid: String) -> bool:
	return by_id.has(uid)

func def_of(uid: String) -> Dictionary:
	return by_id.get(uid, {})

func level(uid: String) -> int:
	return int(levels.get(uid, 0))

func cost(uid: String) -> int:
	var def: Dictionary = by_id.get(uid, {})
	if def.is_empty():
		return 0
	# floor(base_cost * growth ^ current_level)
	return int(floor(float(def.get("base_cost", 0)) * pow(growth, float(level(uid)))))

func record_purchase(uid: String) -> void:
	if by_id.has(uid):
		levels[uid] = level(uid) + 1

# base + inc_per_level * level, straight from the def.
func effect_value(uid: String) -> float:
	var def: Dictionary = by_id.get(uid, {})
	if def.is_empty():
		return 0.0
	return float(def.get("base", 0)) + float(def.get("inc_per_level", 0)) * float(level(uid))

func inc_of(uid: String) -> float:
	return float(def_of(uid).get("inc_per_level", 0))

func levels_snapshot() -> Dictionary:
	return levels.duplicate()

# Restore saved levels (only ids this game knows, clamped >= 0).
func restore_levels(saved: Dictionary) -> void:
	for uid in levels:
		if saved.has(uid):
			levels[uid] = maxi(0, int(saved[uid]))
