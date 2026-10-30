class_name GameData
extends RefCounted

# Loads the same numbers the HTML ran on, from res://data/*.json.
# Source of truth: ../data/ in the felony-city folder (copied in here
# because a Godot project reads inside its own res:// tree).

static func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("GameData: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: %s did not parse as a Dictionary" % path)
		return {}
	return parsed

static func weapons() -> Array:
	return load_json("res://data/weapons.json").get("weapons", [])

static func world_enemies_wanted() -> Dictionary:
	return load_json("res://data/enemies_world_wanted.json")
