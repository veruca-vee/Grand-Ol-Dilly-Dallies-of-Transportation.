class_name SaveGame
extends RefCounted

# ENGINE CORE — versioned JSON persistence to a user:// path.
#
# The module owns only the I/O contract: write a Dictionary payload
# as JSON, read it back, delete it. WHICH fields a game persists is
# the game layer's business; the payload is expected to carry a
# "version" key so future games can migrate old saves.
#
# Extracted from gate3d_main.gd's save_game()/load_game() in the
# Engine Core gate (step 2); the file format a game writes through
# this class is unchanged from what its own code wrote before.

var path: String = ""

func _init(p: String = "user://save.json") -> void:
	path = p

func write_payload(payload: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	return true

# Returns the parsed payload, or {} when the file is missing or does
# not parse as a Dictionary — callers treat {} as "no save".
func read_payload() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func exists() -> bool:
	return FileAccess.file_exists(path)

func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
