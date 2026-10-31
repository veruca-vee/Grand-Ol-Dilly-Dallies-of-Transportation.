class_name DataLoader
extends RefCounted

# ENGINE CORE — JSON data loading: a game's numbers live in JSON
# files and reach the engine as validated Dictionaries / Arrays.
# A file that cannot be opened, or whose top level is not a
# Dictionary, logs an error and yields {} — a game fails loudly in
# the log and runs on empty data rather than crashing on a bad path.
#
# Extracted from scripts/game_data.gd (the 2D prototype's loader,
# which stays with the 2D game) in the Engine Core gate, step 3.
# Same semantics; core callers pass their own paths, so a new game
# points the loader at ITS data folder.

static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DataLoader: %s did not parse as a Dictionary" % path)
		return {}
	return parsed

# Convenience for the common "top-level key holds the list" shape
# (e.g. weapons.json -> "weapons", upgrades.json -> "upgrades").
static func load_array(path: String, key: String) -> Array:
	return load_json(path).get(key, [])
