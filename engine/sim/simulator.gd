extends SceneTree

# Headless balance simulator. Run:
#   godot --headless --path . --script sim/simulator.gd
# Reads the SAME res://data/*.json the game reads. No graphics, no scene.

func load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("SIM FAIL: cannot open ", path)
		quit(1)
		return {}
	return JSON.parse_string(f.get_as_text())

func _init() -> void:
	var weapons: Array = load_json("res://data/weapons.json").get("weapons", [])
	var upgrades: Array = load_json("res://data/upgrades.json").get("upgrades", [])
	var bundle := load_json("res://data/enemies_world_wanted.json")
	var wanted: Dictionary = bundle.get("wanted", {})
	var enemies: Array = bundle.get("enemies", [])
	var caps: Array = wanted.get("max_active_enemies_by_star", [])

	print("SIM == wanted table (fractional wanted, floor indexing) ==")
	var ok := true
	for w in [0.0, 0.3, 0.9, 1.0, 1.7, 3.15, 5.9, 6.0]:
		var stars := floori(w)
		if stars < 0 or stars >= caps.size():
			ok = false
			printerr("SIM FAIL: wanted ", w, " -> stars ", stars, " outside cap table")
		else:
			print("SIM   wanted %.2f -> %d stars, enemy cap %d" % [w, stars, int(caps[stars])])
	print("SIM wanted indexing: ", "PASS" if ok else "FAIL")

	print("SIM == combat: time-to-kill (seconds, no upgrades) ==")
	for e in enemies:
		var hp := float(e.get("hp", 0))
		var line := "SIM   vs %s (hp %d): " % [str(e.get("type", "")), int(hp)]
		for wp in weapons:
			if wp.get("melee", false):
				continue
			var shots: float = ceilf(hp / float(wp.get("dmg", 1)))
			var ttk: float = shots * float(wp.get("rate_frames", 60)) / 60.0
			line += "%s %.1fs  " % [str(wp.get("name", "")), ttk]
		print(line)

	print("SIM == economy: level-1 upgrade cost vs cash sources ==")
	var sources := {"ped": 10, "ped_runover": 15, "car_destroyed": 25, "cop": 20, "swat": 40, "tank": 100}
	for u in upgrades:
		var cost := int(u.get("base_cost", 0))
		print("SIM   %s $%d = %d peds / %d cars / %d tanks" % [str(u.get("name", "")), cost, ceili(cost / 10.0), ceili(cost / 25.0), ceili(cost / 100.0)])
	print("SIM cash sources (base, combo x1): ", sources)
	print("SIM DONE")
	quit(0 if ok else 1)
