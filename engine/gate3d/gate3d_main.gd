extends Node3D

# G.O.D.O.T — the GAME LAYER (Engine Core gate, 2026-10-30)
#
# This file used to be the whole game (1,562 lines: camera, combat,
# wanted, economy, shop, save, HUD, city generation, autotest).
# The Engine Core gate extracted every reusable system into
# res://core/ (see core/README.md); what remains here is wiring
# plus the rules that are truly G.O.D.O.T's: the kill economy hooks,
# BUSTED, car entry/exit, the Black Market panel, spawn placement,
# and the --autotest contract. Numbers still come from
# res://data/*.json; the two HTML bug fixes still hold (float
# wanted + floori() lookups via core Wanted; the fire cooldown
# ticking EVERY physics frame in both modes).
# History (Gates 3D-0/1/2) lives in gate3d/README.md.

const SCALE := 15.0  # 2D world units per 3D unit (3600 -> 240)

var data: Dictionary = {}
var weapons: Array = []
var driveby_weapon: Dictionary = {}
var enemy_stats: Dictionary = {}  # kind -> stats dict
var wanted_cfg: Dictionary = {}
var car_stats: Dictionary = {}
var ped_stats: Dictionary = {}

var player: Player3D = null
var cars: Array[Car3D] = []
var enemies: Array = []  # Enemy3D / Tank3D, duck-typed like the 2D code
var buildings: Array = []  # Rect2 XZ footprints, for spawn placement
var camera: Camera3D = null
# Engine Core step 7: the follow-cam rig (and its yaw state) lives
# in core FollowCamera; cam_yaw forwards to it — the player reads
# it via main.get("cam_yaw") and the shooter faces along it.
var follow_cam := FollowCamera.new()
var cam_yaw: float:
	get:
		return follow_cam.yaw
	set(v):
		follow_cam.yaw = v
var state: String = "PLAYING"

# Engine Core step 4: cash/score/combo state lives in core Economy;
# these properties forward to it, so game code (and the autotest)
# keeps reading and writing the same names as before the move.
var economy := Economy.new()
var cash: int:
	get:
		return economy.cash
	set(v):
		economy.cash = v
var score: int:
	get:
		return economy.score
	set(v):
		economy.score = v
var kills: int = 0
var cars_destroyed: int = 0

# Engine Core step 5: the wanted model (float level, floor stars,
# caps, decay, spawn policy) lives in core Wanted; these properties
# forward to it so game code keeps the old names.
var wanted_sys := Wanted.new()
var combat := Combat.new()
# Live wanted gains, from the data's wanted.gains block (the
# wanted_pacing fix, 2026-11-01: the HTML gains in gains_in_html
# stay as the historical record; these are the tuned 3D values).
# Fallbacks in the kill paths are the HTML numbers.
var wanted_gains: Dictionary = {}
var wanted_level: float:
	get:
		return wanted_sys.level
	set(v):
		wanted_sys.level = v
var frames_since_crime: int:
	get:
		return wanted_sys.frames_since_crime
	set(v):
		wanted_sys.frames_since_crime = v
var combo_count: int:
	get:
		return economy.combo_count
	set(v):
		economy.combo_count = v
var combo_frames: int:
	get:
		return economy.combo_frames
	set(v):
		economy.combo_frames = v

var hud_hp: ProgressBar = null
var hud_weapon: Label = null
var hud_cash: Label = null
var hud_stars: Label = null
var hud_combo: Label = null
var hud_center: Label = null

var fx: Array = []  # transient visuals: {node, ttl, max_ttl, grow}
var autotest: bool = false

# ---------- Gate 3D-2: upgrades / save / shop / sfx / minimap ----------
var city: CityBuilder = null  # ENGINE CORE: builds the world (step 10)
var upgrade_defs: Array = []  # from data/upgrades.json, in file order
# Engine Core step 4: defs/levels/costs/effects live in core Upgrades;
# upgrade_levels forwards to it for the shop UI and the autotest.
var upgrades: Upgrades = null
var upgrade_levels: Dictionary:
	get:
		return upgrades.levels
	set(v):
		upgrades.levels = v
var unlocked_weapons: Array = []  # weapon indices available (3D-1: all)
var base_hp_data: float = 100.0  # data: player.base_hp
const SAVE_PATH := "user://godot_save.json"
const SAVE_PATH_TEST := "user://godot_save_autotest.json"
var save_path: String = SAVE_PATH
var save_frames: int = 0
var frame_counter: int = 0
var shop_open: bool = false
var shop_panel: PanelContainer = null
var shop_cash_label: Label = null
var shop_rows: Dictionary = {}  # id -> {level: Label, buy: Button}
var minimap: Minimap = null
var sfx_streams: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var last_hurt_sfx_frame: int = -100
var last_boom_sfx_frame: int = -100

# ---------- Playtest telemetry (TELEMETRY_SPEC) ----------
# The logger is ENGINE CORE (core/debug_log.gd); this layer
# picks the directory + build label and feeds it state and
# events. Local files only — nothing leaves the machine.
const BUILD_LABEL := "Detail1+Telemetry"
var debug_log: DebugLog = null
var telemetry_dir: String = "user://playtest"
var last_wanted_stars: int = 0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # so _input can close the shop while the tree is paused
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args or "--autotest" in OS.get_cmdline_args()
	if autotest:
		# Autotest never touches the player's real save file.
		save_path = SAVE_PATH_TEST
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	# Playtest telemetry: session starts before anything can
	# happen worth logging. A failed start disables the logger
	# silently (core rule) — the game runs identically either
	# way. Autotest sessions go to their own dir, like the save.
	debug_log = DebugLog.new()
	telemetry_dir = "user://playtest"
	var env_dir := OS.get_environment("GODOT_TELEMETRY_DIR")
	if env_dir != "":
		telemetry_dir = env_dir
	if autotest:
		telemetry_dir = "user://playtest_autotest"
	debug_log.frame_provider = _telemetry_grab_frame
	if debug_log.start_session(telemetry_dir, BUILD_LABEL):
		debug_log.event("SESSION_START", {"build": BUILD_LABEL})
	data = DataLoader.load_json("res://data/enemies_world_wanted.json")
	weapons = DataLoader.load_array("res://data/weapons.json", "weapons")
	driveby_weapon = DataLoader.load_json("res://data/weapons.json").get("driveby_weapon", {})
	for e in data.get("enemies", []):
		enemy_stats[e.get("type", "")] = e
	wanted_cfg = data.get("wanted", {})
	wanted_gains = wanted_cfg.get("gains", {})
	car_stats = data.get("car", {})
	ped_stats = data.get("pedestrian", {})
	base_hp_data = float(data.get("player", {}).get("base_hp", 100))
	upgrade_defs = DataLoader.load_array("res://data/upgrades.json", "upgrades")
	upgrades = Upgrades.new()
	# growth 1.4: the exponent in data/upgrades.json's cost_formula
	upgrades.setup(upgrade_defs, 1.4)
	economy.setup(data.get("combo", {}))
	wanted_sys.setup(wanted_cfg)
	# GODOT's projectile hit radii: the 2D radii / 15 (see README)
	combat.setup_projectiles({
		"car_offset": Vector3(0, 0.6, 0), "car_radius": 1.9,
		"ped_offset": Vector3(0, 0.9, 0), "ped_radius": 0.95,
		"enemy_offset": Vector3(0, 0.9, 0), "enemy_radius": 1.2,
		"player_offset": Vector3(0, 0.9, 0), "player_radius": 1.05,
	})
	for i in range(weapons.size()):
		unlocked_weapons.append(i)
	city = CityBuilder.new()
	load_game()

	buildings = city.build_world(self)
	_setup_sfx()
	player = Player3D.new()
	player.position = Vector3(0, 0.2, 8)
	player.main = self
	add_child(player)
	player.max_hp = base_hp_data
	apply_upgrades()
	player.hp = player.max_hp
	player.weapon_index = int(DataLoader.load_json("res://data/weapons.json").get("player_start_weapon_index", 1))
	player.refresh_gun(weapons[player.weapon_index])
	var car_spots := [Vector3(4, 0.2, -2), Vector3(-14, 0.2, -30), Vector3(20, 0.2, 24), Vector3(-30, 0.2, 18), Vector3(30, 0.2, -34), Vector3(-24, 0.2, 44)]
	for i in range(car_spots.size()):
		var car := Car3D.new()
		# Detail Pass 1: deterministic spread of silhouettes + paints
		car.body_style = i % 3
		car.car_color = Car3D.PALETTE[i % Car3D.PALETTE.size()]
		car.position = car_spots[i]
		car.rotation.y = randf() * TAU
		car.main = self
		car.hp = float(car_stats.get("hp", 100))
		car.max_hp = car.hp
		add_child(car)
		cars.append(car)
	for i in range(8):
		var ped := Ped3D.new()
		ped.position = Vector3((randf() - 0.5) * 90, 0.2, (randf() - 0.5) * 90)
		ped.main = self
		add_child(ped)
	camera = Camera3D.new()
	camera.far = 160.0  # PS2 draw distance: short on purpose
	camera.position = Vector3(0, 3, 15)
	add_child(camera)
	_build_hud()
	refresh_hud()

	if "--screenshot" in args or "--screenshot" in OS.get_cmdline_args():
		_take_screenshot()
	if "--markshot" in args or "--markshot" in OS.get_cmdline_args():
		_take_markshot()
	if "--countnodes" in args or "--countnodes" in OS.get_cmdline_args():
		var counts := _scene_counts()
		print("NODECOUNT: nodes=", counts.x, " multimesh_instances=", counts.y)
	if autotest:
		_run_autotest()

# Scene census shared by --countnodes and the autotest density
# check: (total tree nodes, total MultiMesh instances).
func _scene_counts() -> Vector2i:
	var mm_instances := 0
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MultiMeshInstance3D and n.multimesh != null:
			mm_instances += n.multimesh.instance_count
		for ch in n.get_children():
			stack.append(ch)
	return Vector2i(get_tree().get_node_count(), mm_instances)

# ---------- Debug: windowed screenshot for visual checks ----------
func _take_screenshot() -> void:
	# Used with a real (Xvfb) display, NOT headless: lets a human or
	# the assistant eyeball the dressed city. Saves + quits.
	# Detail Pass 1: frame the first storefront sign (stand on the
	# road side of it, face it, let the follow-cam settle behind)
	# so the visual check can pixel-test its accent colours.
	if city != null and not city.sign_positions.is_empty():
		var sp: Vector3 = city.sign_positions[0]
		var centre := Vector3(roundf(sp.x / 52.0) * 52.0, 0, roundf(sp.z / 52.0) * 52.0)
		var outward := sp - centre
		outward.y = 0.0
		outward = outward.normalized()
		player.global_position = sp + outward * 8.0 + Vector3(0, 0.2, 0)
		player.look_at(Vector3(sp.x, player.global_position.y, sp.z), Vector3.UP)
	for i in range(100):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://gate3d_shot.png"
	img.save_png(path)
	print("SCREENSHOT: ", ProjectSettings.globalize_path(path), " ", img.get_size())
	get_tree().quit()

# Detail 1 markings fix: frame a road with dashes — stand on the
# vertical road south of the centre intersection, look north down
# its centre line (dashes + crosswalk ahead, on asphalt now).
func _take_markshot() -> void:
	player.global_position = Vector3(0, 0.2, 15)
	player.look_at(Vector3(0, 0.2, 4), Vector3.UP)
	for i in range(100):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://gate3d_markshot.png"
	img.save_png(path)
	print("MARKSHOT: ", ProjectSettings.globalize_path(path), " ", img.get_size())
	get_tree().quit()

# ---------- HUD ----------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Widgets are ENGINE CORE (core/hud_kit.gd); the theme values
	# (Midnight Circle) and layout positions are this game's.
	var panel := HudKit.panel_style(Color(0.09, 0.07, 0.17, 0.85), 4)  # Midnight Circle panel
	var fill := HudKit.panel_style(Color(0.78, 0.49, 1.0, 0.95), 4)  # violet C77DFF
	hud_hp = HudKit.make_hp_bar(Vector2(10, 10), Vector2(220, 18), player.max_hp, player.hp, panel, fill)
	layer.add_child(hud_hp)
	hud_weapon = HudKit.make_label("", Vector2(10, 34), 16)
	layer.add_child(hud_weapon)
	hud_combo = HudKit.make_label("", Vector2(10, 58), 16, Color(1.0, 0.83, 0.47))  # candle gold FFD479
	layer.add_child(hud_combo)
	hud_cash = HudKit.make_label("", Vector2(1020, 8), 18, Color(1.0, 0.83, 0.47))
	layer.add_child(hud_cash)
	hud_stars = HudKit.make_label("", Vector2(1020, 34), 20, Color(1.0, 0.83, 0.47))
	layer.add_child(hud_stars)
	var help := HudKit.make_label("WASD move/drive · mouse aims · LMB fire · 1-9 / Q weapons · E enter/exit car · B black market · hold T to talk · F9 mark a moment", Vector2(10, 660), 14)
	layer.add_child(help)
	var cross := Label.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7, -16)
	cross.add_theme_font_size_override("font_size", 20)
	cross.text = "+"
	layer.add_child(cross)
	hud_center = HudKit.make_label("", Vector2(490, 300), 42, Color(1.0, 0.33, 0.44))  # ember FF5370
	hud_center.visible = false
	layer.add_child(hud_center)
	# Gate 3D-2: minimap (core widget), bottom-right
	minimap = Minimap.new()
	minimap.source = self
	minimap.position = Vector2(1090, 522)
	layer.add_child(minimap)
	_build_shop(layer)

# ---------- Black Market (Gate 3D-2) ----------
func _build_shop(layer: CanvasLayer) -> void:
	shop_panel = PanelContainer.new()
	shop_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # clickable while paused
	shop_panel.position = Vector2(400, 120)
	shop_panel.custom_minimum_size = Vector2(480, 0)
	shop_panel.visible = false
	var bg := HudKit.panel_style(Color(0.09, 0.07, 0.17, 0.97), 6, 14.0)  # Midnight Circle panel
	shop_panel.add_theme_stylebox_override("panel", bg)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	shop_panel.add_child(vbox)
	var title := Label.new()
	title.text = "BLACK MARKET"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	vbox.add_child(title)
	shop_cash_label = Label.new()
	shop_cash_label.add_theme_font_size_override("font_size", 16)
	shop_cash_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.96))
	vbox.add_child(shop_cash_label)
	for def in upgrade_defs:
		var uid := str(def.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l := Label.new()
		name_l.text = str(def.get("name", uid))
		name_l.custom_minimum_size = Vector2(140, 0)
		name_l.add_theme_font_size_override("font_size", 16)
		row.add_child(name_l)
		var lvl_l := Label.new()
		lvl_l.custom_minimum_size = Vector2(70, 0)
		lvl_l.add_theme_font_size_override("font_size", 16)
		lvl_l.add_theme_color_override("font_color", Color(0.78, 0.49, 1.0))
		row.add_child(lvl_l)
		var desc_l := Label.new()
		desc_l.text = str(def.get("desc", ""))
		desc_l.custom_minimum_size = Vector2(150, 0)
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
		row.add_child(desc_l)
		var buy_b := Button.new()
		buy_b.custom_minimum_size = Vector2(96, 0)
		buy_b.add_theme_font_size_override("font_size", 15)
		buy_b.pressed.connect(_on_buy_pressed.bind(uid))
		row.add_child(buy_b)
		vbox.add_child(row)
		shop_rows[uid] = {"level": lvl_l, "buy": buy_b}
	var hint := Label.new()
	hint.text = "Keys 1-5 buy · B or Esc closes"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
	vbox.add_child(hint)
	layer.add_child(shop_panel)

func _on_buy_pressed(uid: String) -> void:
	buy_upgrade(uid)
	refresh_shop()

func toggle_shop(open: bool) -> void:
	shop_open = open
	shop_panel.visible = open
	get_tree().paused = open
	if open:
		refresh_shop()

func refresh_shop() -> void:
	if shop_panel == null:
		return
	shop_cash_label.text = "Cash: $%d" % cash
	for uid in shop_rows:
		var row: Dictionary = shop_rows[uid]
		var lvl: Label = row["level"]
		lvl.text = "Lv %d" % int(upgrade_levels.get(uid, 0))
		var buy: Button = row["buy"]
		var cost := upgrade_cost(uid)
		buy.text = "BUY $%d" % cost
		buy.disabled = cash < cost

# ---------- Upgrades (data/upgrades.json) ----------
func upgrade_level(uid: String) -> int:
	return upgrades.level(uid)

func upgrade_cost(uid: String) -> int:
	# core rule: floor(base_cost * 1.4 ^ current_level), from the data
	return upgrades.cost(uid)

func damage_mult() -> float:
	return upgrades.effect_value("damage")

func firerate_mult() -> float:
	return upgrades.effect_value("firerate")

func regen_stat() -> float:
	return upgrades.effect_value("regen")

func apply_upgrades() -> void:
	if player == null:
		return
	var new_max := base_hp_data + upgrades.inc_of("hp") * float(upgrade_level("hp"))
	var delta := new_max - player.max_hp
	player.max_hp = new_max
	if delta > 0.0:
		player.hp = minf(player.hp + delta, new_max)
	# 2D speed: 3.8 + 0.4/level; 3D base is 5.0 (ratio 5.0/3.8, the
	# same adaptation as every other speed in this port)
	var spd_base := float(upgrades.def_of("speed").get("base", 3.8))
	player.walk_speed = 5.0 * upgrades.effect_value("speed") / spd_base

func buy_upgrade(uid: String) -> bool:
	if not upgrades.has(uid):
		return false
	var cost := upgrade_cost(uid)
	if cash < cost:
		return false
	cash -= cost
	upgrades.record_purchase(uid)
	apply_upgrades()
	_telemetry_event("UPGRADE", {"id": uid, "level": upgrade_level(uid), "cost": cost})
	save_game()
	play_sfx("pickup", -10.0)
	refresh_hud()
	return true

# ---------- Save / load (user://godot_save.json) ----------
# Rule (also in gate3d/README.md): cash, total score, upgrade levels
# and the unlocked-weapon set are the persistent profile. BUSTED
# resets the RUN (wanted, enemies, position) via scene reload, but
# cash/score/upgrades carry over — the HTML saved progress the same
# way. Autosave: on purchase, every 1800 physics frames, on BUSTED.
func save_game() -> void:
	var payload := {
		"version": 1,
		"cash": cash,
		"score": score,
		"upgrades": upgrade_levels.duplicate(),
		"unlocked_weapons": unlocked_weapons.duplicate(),
	}
	# Engine Core step 2: the JSON I/O lives in core/save_game.gd;
	# this game layer still decides WHICH fields are the profile.
	if not SaveGame.new(save_path).write_payload(payload):
		push_warning("GODOT: cannot write save file %s" % save_path)

func load_game() -> void:
	var p: Dictionary = SaveGame.new(save_path).read_payload()
	if p.is_empty():
		return
	cash = maxi(0, int(p.get("cash", 0)))
	score = maxi(0, int(p.get("score", 0)))
	upgrades.restore_levels(p.get("upgrades", {}))
	var unl: Array = p.get("unlocked_weapons", [])
	if not unl.is_empty():
		unlocked_weapons.clear()
		for idx in unl:
			var i := int(idx)
			if i >= 0 and i < weapons.size() and not unlocked_weapons.has(i):
				unlocked_weapons.append(i)

# ---------- Synthesized SFX (sfx.gd) ----------
func _setup_sfx() -> void:
	sfx_streams = {
		"gunshot": SfxSynth.gunshot(),
		"explosion": SfxSynth.explosion(),
		"pickup": SfxSynth.pickup(),
		"hurt": SfxSynth.hurt(),
		"busted": SfxSynth.busted(),
	}
	var holder := Node.new()
	holder.name = "SFX"
	add_child(holder)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # shop chime plays while paused
		p.bus = "Master"
		holder.add_child(p)
		sfx_players.append(p)

func play_sfx(sname: String, vol_db: float = -12.0, pitch: float = 1.0) -> void:
	if not sfx_streams.has(sname):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_streams[sname]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

func refresh_hud() -> void:
	if player == null or hud_hp == null:
		return
	hud_hp.max_value = player.max_hp
	hud_hp.value = maxi(0, int(player.hp))
	hud_weapon.text = str(weapons[player.weapon_index].get("name", "")) if weapons.size() > 0 else ""
	hud_cash.text = "$%d   Score %d" % [cash, score]
	hud_stars.text = HudKit.stars_text(floori(wanted_level))
	hud_combo.text = HudKit.combo_text(combo_count, economy.combo_mult_now())

# ---------- Wanted / combo (mirrors scripts/main.gd) ----------
func add_wanted(amt: float) -> void:
	wanted_sys.add(amt)
	_telemetry_wanted_check()
	refresh_hud()

func add_combo() -> float:
	return economy.add_combo()

func stars_now() -> int:
	return wanted_sys.stars()

func enemy_cap(stars: int) -> int:
	return wanted_sys.cap(stars)

func spawn_type(stars: int) -> String:
	return wanted_sys.spawn_type(stars)

# Placement + instantiation stay in the game layer (it owns the
# scene and the enemy classes); core Wanted decides IF spawning
# may happen and WHAT kind, this decides WHERE and builds it.
func try_spawn_enemy(force: bool = false) -> bool:
	var stars := stars_now()
	if not wanted_sys.can_spawn(stars, enemies.size()):
		return false
	if not wanted_sys.spawn_roll(stars, force):
		return false
	_spawn_enemy(spawn_type(stars), _spawn_position())
	return true

func _spawn_position() -> Vector3:
	# 2D spawns on a 500-900 unit ring around the player; /15 -> 33-60.
	# Ring pushed out a little so spawns land outside the camera's
	# immediate view in the smaller 3D city; buildings are avoided.
	for attempt in range(12):
		var ang := randf() * TAU
		var d := 42.0 + randf() * 22.0
		var p := player.global_position + Vector3(cos(ang), 0, sin(ang)) * d
		p.x = clamp(p.x, -112, 112)
		p.z = clamp(p.z, -112, 112)
		p.y = 0.2
		var inside := false
		for r in buildings:
			if r.grow(2.0).has_point(Vector2(p.x, p.z)):
				inside = true
				break
		if not inside:
			return p
	return Vector3(60, 0.2, 60)

func _spawn_enemy(kind: String, pos: Vector3) -> void:
	var e: Node3D
	if kind == "tank":
		e = Tank3D.new()
	else:
		e = Enemy3D.new()
	e.setup(kind, enemy_stats.get(kind, {}))
	e.position = pos
	e.main = self
	add_child(e)
	enemies.append(e)

# ---------- Shooting ----------
func player_shoot_3d(driveby: bool) -> void:
	if state != "PLAYING" or player == null or player.dead or camera == null:
		return
	# Gate 3D-2: Black Market multipliers — damage x(1 + 0.15/level),
	# cooldown / (1 + 0.10/level), from data/upgrades.json.
	var weapon: Dictionary = (driveby_weapon if driveby else weapons[player.weapon_index]).duplicate()
	weapon["dmg"] = Combat.effective_damage(weapon, damage_mult())
	var rate := Combat.effective_rate(weapon, firerate_mult())
	var range3d := Combat.range_units(weapon, SCALE)
	var shooter: Node3D = player.driving if driveby and player.driving != null else player
	var muzzle := shooter.global_position + Vector3(0, 1.25, 0)
	if not driveby:
		player.rotation.y = cam_yaw  # face where the camera aims
	if weapon.get("melee", false):
		_melee_attack(weapon)
		player.fire_cooldown = rate
		return
	play_sfx("gunshot", -13.0, randf_range(0.92, 1.08) * (1.7 if str(weapon.get("name", "")) == "LASER" else 1.0))
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	if player.driving != null:
		exclude.append(player.driving.get_rid())
	var cam_from := camera.global_position
	var cam_dir := FollowCamera.aim_direction(camera)
	var spread := float(weapon.get("spread", 0.0))
	var color := Color(weapon.get("color", "#ffdd88"))
	if weapon.get("rocket", false):
		var aim := Combat.ray_end(space, cam_from, cam_dir, range3d, exclude)
		var dir := (aim - muzzle).normalized()
		var b := Bullet3D.new()
		add_child(b)
		b.setup(muzzle, dir * 40.0, float(weapon.get("dmg", 200)), true, true, float(weapon.get("range", 800)) / 10.0, player, self, color)
		_spawn_flash(muzzle, color)
		player.fire_cooldown = rate
		player.fire_flap_time = 0.15
		return
	var hits := Combat.hitscan(space, cam_from, cam_dir, muzzle, range3d, int(weapon.get("count", 1)), spread, exclude)
	for h in hits:
		var col: Object = h.get("collider")
		if col != null:
			_apply_hitscan_hit(col, weapon)
		_spawn_tracer(muzzle, h["end"], color)
	_spawn_flash(muzzle, color)
	player.fire_cooldown = rate
	player.fire_flap_time = 0.15

func _apply_hitscan_hit(collider: Object, weapon: Dictionary) -> void:
	var dmg := float(weapon.get("dmg", 10))
	if collider is Ped3D:
		if not collider.dead:
			kill_ped(collider, false)
	elif collider is Enemy3D or collider is Tank3D:
		if not collider.dead:
			collider.take_damage(dmg)
	elif collider is Car3D:
		if not collider.dead and collider != player.driving:
			collider.take_damage(dmg)
	# buildings / ground: impact only

func _melee_attack(weapon: Dictionary) -> void:
	# 2D fists: a hit point 28 units ahead, radii 22/25/30 per target.
	var dmg := float(weapon.get("dmg", 12))
	var origin := player.global_position
	var facing := -player.global_transform.basis.z
	# target selection is core Combat; the effects are game rules
	for p in Combat.melee_targets(origin, facing, get_tree().get_nodes_in_group("peds3d"), 2.6, 0.2):
		kill_ped(p, false)
	for e in Combat.melee_targets(origin, facing, enemies, 2.8, 0.2):
		e.take_damage(dmg)
	var car_targets: Array = []
	for c in cars:
		if c != player.driving:
			car_targets.append(c)
	for c in Combat.melee_targets(origin, facing, car_targets, 3.4, 0.2):
		c.take_damage(dmg)
	player.fire_flap_time = 0.15

func enemy_shoot_3d(e: Node3D) -> void:
	if player == null:
		return
	var from: Vector3 = e.gun_position()
	var target := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	dir = Combat.jitter_dir(dir, 0.15)  # 2D aim jitter
	var b := Bullet3D.new()
	add_child(b)
	b.setup(from, dir * 72.0, float(e.dmg), false, false, float(e.bullet_life_frames), e, self, Color(1, 0.27, 0.27))

func resolve_bullet3d(b: Bullet3D) -> void:
	# Hit SELECTION (order cars, peds, enemies, player, and the hit
	# radii) lives in core Combat; the CONSEQUENCES (damage, kill
	# economy, rocket explosions) are game rules and stay here.
	var pos := b.global_position
	var res := combat.resolve_projectile(pos, b.is_player, b.shooter, {
		"cars": cars,
		"peds": get_tree().get_nodes_in_group("peds3d"),
		"enemies": enemies,
		"player": player,
	})
	if res.is_empty():
		return
	var t: Variant = res["target"]
	match str(res["kind"]):
		"car":
			t.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 110, b.damage * 0.8, b)
		"ped":
			kill_ped(t, false)
			if b.is_rocket:
				explode_3d(pos, 80, b.damage * 0.5, b)
		"enemy":
			t.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 90, b.damage * 0.6, b)
		"player":
			t.take_damage(b.damage * 0.5)  # 2D halves enemy bullet damage to the player
	b.queue_free()

func explode_3d(pos: Vector3, radius2d: float, dmg: float, source: Object) -> void:
	# 2D explode(): cars/enemies take dmg * (1 - d/r) * 1.5, peds die
	# within r * 0.8, the player takes dmg * 0.4 within r * 0.7.
	var radius := radius2d / SCALE
	_spawn_explosion_fx(pos, radius)
	if frame_counter - last_boom_sfx_frame > 6:  # chain kills: one boom per beat
		last_boom_sfx_frame = frame_counter
		play_sfx("explosion", -9.0, randf_range(0.9, 1.05))
	for c in cars:
		if not c.dead and c != source:
			var dc := pos.distance_to(c.global_position)
			if dc < radius:
				c.take_damage(Combat.explosion_falloff(dmg, dc, radius))
	for e in enemies:
		if not e.dead and e != source:
			var de := pos.distance_to(e.global_position)
			if de < radius:
				e.take_damage(Combat.explosion_falloff(dmg, de, radius))
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and pos.distance_to(p.global_position) < radius * 0.8:
			kill_ped(p, false)
	if player != null and not player.dead and pos.distance_to(player.global_position) < radius * 0.7:
		player.take_damage(dmg * 0.4)

# ---------- Deaths / economy (mirrors scripts/main.gd) ----------
func kill_ped(p: Ped3D, run_over: bool) -> void:
	if p.dead:
		return
	p.die()
	var mult := add_combo()
	var base := float(ped_stats.get("cash_runover", 15) if run_over else ped_stats.get("cash_on_kill", 10))
	economy.award(base, float(ped_stats.get("score", 20)), mult)
	add_wanted(float(wanted_gains.get("kill_ped_runover" if run_over else "kill_ped", 0.15)))
	spawn_pickup_3d(p.global_position, "cash")
	refresh_hud()

func kill_car(c: Car3D) -> void:
	if c.dead:
		return
	c.dead = true
	c.speed = 0.0
	c.set_dead_visual()
	cars_destroyed += 1
	add_wanted(float(wanted_gains.get("destroy_car", 0.3)))
	var mult := add_combo()
	economy.award(float(car_stats.get("cash_on_destroy", 25)), float(car_stats.get("score", 50)), mult)
	if player != null and player.driving == c:
		_exit_car()
	explode_3d(c.global_position, 90, 80, c)
	spawn_pickup_3d(c.global_position, "cash" if randf() < 0.5 else "health")
	refresh_hud()
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(c):
			cars.erase(c)
			c.queue_free())

func kill_enemy(e: Node3D) -> void:
	if e.dead:
		return
	e.dead = true
	kills += 1
	add_wanted(float(wanted_gains.get("kill_enemy", 0.1)))
	var mult := add_combo()
	var stats: Dictionary = enemy_stats.get(e.kind, {})
	economy.award(float(stats.get("cash_on_kill", 20)), float(stats.get("score", 100)), mult)
	explode_3d(e.global_position, 120 if e.kind == "tank" else 60, 100 if e.kind == "tank" else 40, e)
	if e.kind == "tank":
		spawn_pickup_3d(e.global_position, "health")
	elif randf() < 0.25:
		# Gate 3D-1 adaptation (labelled): the 2D code has no weapon
		# pickups; a quarter of non-tank enemy drops are weapons.
		spawn_pickup_3d(e.global_position, "weapon")
	else:
		spawn_pickup_3d(e.global_position, "cash")
	enemies.erase(e)
	e.queue_free()
	refresh_hud()

func spawn_pickup_3d(pos: Vector3, kind: String) -> void:
	if randf() >= 0.3:  # HTML spawnPickup gate, kept from the 2D code
		return
	var pk := Pickup3D.new()
	pk.kind = kind
	pk.position = Vector3(pos.x, 0.55, pos.z)
	add_child(pk)

# ---------- Player events ----------
func on_player_damaged() -> void:
	if frame_counter - last_hurt_sfx_frame > 12:
		last_hurt_sfx_frame = frame_counter
		play_sfx("hurt", -12.0)
	refresh_hud()

func on_player_death() -> void:
	if state != "PLAYING":
		return
	state = "GAMEOVER"
	_telemetry_event("BUSTED", {"score": score, "cash": cash})
	if debug_log != null:
		debug_log.capture_now()
	player.dead = true
	if player.driving != null:
		_exit_car()
	explode_3d(player.global_position, 80, 50, player)
	save_game()  # profile (cash/score/upgrades) survives the BUSTED
	play_sfx("busted", -10.0)
	hud_center.text = "BUSTED\nScore %d  Cash $%d" % [score, cash]
	hud_center.visible = true
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()

# ---------- Cars (Gate 3D-0 behaviour, unchanged) ----------
func _try_enter_car() -> void:
	var best: Car3D = null
	var best_d := 4.0
	for car in cars:
		if car.dead:
			continue
		var d := player.global_position.distance_to(car.global_position)
		if d < best_d:
			best_d = d
			best = car
	if best != null:
		player.driving = best
		best.driven = true
		_telemetry_event("CAR_ENTER", {})
		player.visible = false
		player.set_physics_process(false)
		if player.body_shape != null:
			player.body_shape.disabled = true
		refresh_hud()

func _exit_car() -> void:
	_telemetry_event("CAR_EXIT", {})
	var car := player.driving
	car.driven = false
	player.driving = null
	player.global_position = car.global_position + car.global_transform.basis.x * 2.2 + Vector3(0, 0.3, 0)
	player.visible = true
	player.set_physics_process(true)
	if player.body_shape != null:
		player.body_shape.disabled = false
	refresh_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Telemetry: F9 is Vee's "it broke right here" button —
		# a MARKER line plus a forced frame in the session log.
		if event.keycode == KEY_F9:
			if debug_log != null:
				debug_log.marker()
			return
		# Gate 3D-2: Black Market keys take over while the shop is open
		if shop_open:
			if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
				toggle_shop(false)
			elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
				var sidx: int = event.keycode - KEY_1
				if sidx < upgrade_defs.size():
					buy_upgrade(str(upgrade_defs[sidx].get("id", "")))
					refresh_shop()
			return
		if event.keycode == KEY_B:
			if state == "PLAYING" and player != null and not player.dead:
				toggle_shop(true)
			return
		if event.keycode == KEY_E:
			if player != null and player.driving != null:
				_exit_car()
			elif player != null:
				_try_enter_car()
		elif event.keycode == KEY_Q:
			if player != null and weapons.size() > 0:
				player.weapon_index = (player.weapon_index + 1) % weapons.size()
				player.refresh_gun(weapons[player.weapon_index])
				refresh_hud()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if player != null and idx < weapons.size():
				player.weapon_index = idx
				player.refresh_gun(weapons[player.weapon_index])
				refresh_hud()

# ---------- Per-frame ----------
func _physics_process(_delta: float) -> void:
	if player == null or state != "PLAYING" or shop_open:
		return
	frame_counter += 1
	# Gate 3D-2: periodic autosave (30 s of physics frames)
	if not autotest:
		save_frames += 1
		if save_frames >= 1800:
			save_frames = 0
			save_game()
	# Adrenaline (data/upgrades.json): regen only while wanted == 0,
	# + regen_stat * 0.05 hp/frame (the rule as written in the data).
	if regen_stat() > 0.0 and wanted_level == 0.0 and not player.dead and player.hp < player.max_hp:
		player.hp = minf(player.max_hp, player.hp + regen_stat() * 0.05)
	# The cooldown ticks EVERY physics frame in both modes.
	# (HTML bug fixed here, as in Gate 0: in-car it never ticked.)
	if player.fire_cooldown > 0.0:
		player.fire_cooldown -= 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.fire_cooldown <= 0.0 and not player.dead:
		player_shoot_3d(player.driving != null)
	economy.tick_combo()
	if wanted_level > 0.0:
		if wanted_sys.tick():
			refresh_hud()
		_telemetry_wanted_check()
		if not autotest:
			try_spawn_enemy()
	# run-overs by the driven car (2D: any car moving fast; in the 3D
	# greybox only the player's car is driven, so it is the checker)
	if player.driving != null and abs(player.driving.speed) > 6.0:
		var car := player.driving
		for p in get_tree().get_nodes_in_group("peds3d"):
			if not p.dead and car.global_position.distance_to(p.global_position) < 1.8:
				kill_ped(p, true)
	# pickups
	for pk in get_tree().get_nodes_in_group("pickups3d"):
		if not pk.collected and player.global_position.distance_to(pk.global_position) < 1.6:
			pk.collected = true
			play_sfx("pickup", -13.0)
			if pk.kind == "health":
				player.hp = minf(player.max_hp, player.hp + 30.0)
			elif pk.kind == "weapon":
				if weapons.size() > 1:
					player.weapon_index = randi_range(1, weapons.size() - 1)
					player.refresh_gun(weapons[player.weapon_index])
					if not unlocked_weapons.has(player.weapon_index):
						unlocked_weapons.append(player.weapon_index)
			else:
				economy.add_cash(15)
			var pk_data := {"kind": pk.kind}
			if pk.kind == "weapon":
				pk_data["weapon"] = str(weapons[player.weapon_index].get("name", ""))
			_telemetry_event("PICKUP", pk_data)
			pk.queue_free()
			refresh_hud()
	refresh_hud()

func _process(delta: float) -> void:
	if shop_open:
		return
	_update_fx(delta)
	# Telemetry ticks even under --autotest (the autotest drives
	# this by hand to prove the wiring); the follow camera below
	# stays disabled there, as before.
	if debug_log != null and state == "PLAYING":
		debug_log.tick(delta, _telemetry_state())
	if player == null or camera == null or autotest:
		return
	var actor: Node3D = player.driving if player.driving != null else player
	if player.driving != null:
		player.global_position = player.driving.global_position + Vector3(0, 0.3, 0)
	# follow camera (core rig): behind + above the actor, yaw lerps
	# to the actor's facing; the distances are this game's config
	var dist := 9.0 if player.driving != null else 6.5
	var height := 4.0 if player.driving != null else 3.0
	follow_cam.update(camera, actor, delta, dist, height)

# ---------- Transient visuals (tracers / flashes / explosions) ----------
func _fx_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m

func _spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var len := from.distance_to(to)
	if len < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, len)
	mi.mesh = bm
	mi.material_override = _fx_material(Color(color, 0.85))
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	fx.append({"node": mi, "ttl": 0.06, "max": 0.06, "grow": 0.0})

func _spawn_flash(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _fx_material(Color(1, 0.9, 0.5, 0.95))
	mi.position = pos
	add_child(mi)
	fx.append({"node": mi, "ttl": 0.05, "max": 0.05, "grow": 0.0})

func _spawn_explosion_fx(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _fx_material(Color(1, 0.5, 0, 0.75))
	mi.position = pos + Vector3(0, 0.6, 0)
	add_child(mi)
	fx.append({"node": mi, "ttl": 0.35, "max": 0.35, "grow": radius})

func _update_fx(delta: float) -> void:
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f["ttl"] = float(f["ttl"]) - delta
		var node: MeshInstance3D = f["node"]
		if float(f["ttl"]) <= 0.0:
			node.queue_free()
			fx.remove_at(i)
			continue
		var frac := float(f["ttl"]) / float(f["max"])
		var grow := float(f["grow"])
		if grow > 0.0:
			var s := grow * (1.0 - frac)
			node.scale = Vector3(s, s, s)
		var mat := node.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.85 * frac if grow == 0.0 else 0.75 * frac

# ---------- Telemetry feeds (game side of core DebugLog) ----------
func _telemetry_grab_frame() -> Image:
	# The frame provider: the live viewport. Under a headless
	# dummy renderer this yields an empty image, which
	# DebugLog.capture_frame refuses — real pixels are proven
	# under Xvfb (see the gate notes).
	var tex := get_viewport().get_texture()
	if tex == null:
		return null
	return tex.get_image()

func _telemetry_state() -> Dictionary:
	var pos := Vector3.ZERO
	var vy := 0.0
	var hp_now := 0.0
	var in_car := false
	if player != null:
		pos = player.global_position
		vy = player.velocity.y
		hp_now = player.hp
		if player.driving != null:
			in_car = true
			vy = player.driving.velocity.y
	return {
		"pos": pos, "vy": vy,
		"fps": int(Performance.get_monitor(Performance.TIME_FPS)),
		"wanted": wanted_level, "in_car": in_car,
		"hp": hp_now, "cash": cash,
	}

func _telemetry_event(event_name: String, data: Dictionary = {}) -> void:
	if debug_log != null:
		debug_log.event(event_name, data)

func _telemetry_wanted_check() -> void:
	if debug_log == null:
		return
	var s := floori(wanted_level)
	if s != last_wanted_stars:
		debug_log.event("WANTED", {"from": last_wanted_stars, "to": s, "level": wanted_level})
		last_wanted_stars = s

# ---------- Autotest helpers (telemetry section) ----------
func _telemetry_test_files(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d != null:
		for fn in d.get_files():
			out.append(fn)
	return out

func _telemetry_test_wipe(dir_path: String) -> void:
	var g := ProjectSettings.globalize_path(dir_path)
	var d := DirAccess.open(dir_path)
	if d != null:
		for fn in d.get_files():
			DirAccess.remove_absolute(g + "/" + fn)
	if DirAccess.dir_exists_absolute(g):
		DirAccess.remove_absolute(g)

# ---------- Autotest (--autotest) ----------
func _run_autotest() -> void:
	# Exercises the REAL fire / spawn / economy paths headlessly and
	# prints AUTOTEST PASS / AUTOTEST FAIL lines. Camera follow is
	# disabled while this runs (see _process); the camera is placed
	# by hand so the camera-ray shots are deterministic.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fails: Array[String] = []
	player.hp = 100000.0  # test scaffolding: survive stray enemy fire
	player.max_hp = 100000.0
	# Park the ambient peds in a corner so the firing line is clean.
	for p in get_tree().get_nodes_in_group("peds3d"):
		p.set_physics_process(false)
		p.global_position = Vector3(100, 0.2, 100)

	# --- 1. SMG kills a ped; cash + score + combo move by the data ---
	player.weapon_index = 3  # SMG
	player.refresh_gun(weapons[3])
	var ped := Ped3D.new()
	ped.main = self
	add_child(ped)
	ped.set_physics_process(false)
	ped.global_position = player.global_position + Vector3(0, 0, -6)
	camera.global_position = player.global_position + Vector3(0, 2.2, 5)
	camera.look_at(ped.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	var cash0 := cash
	var score0 := score
	var shots := 0
	while not ped.dead and shots < 40:
		player.fire_cooldown = 0.0
		player_shoot_3d(false)
		shots += 1
		await get_tree().physics_frame
	if not ped.dead:
		fails.append("SMG did not kill the ped after %d shots" % shots)
	if cash != cash0 + 10:
		fails.append("ped kill cash: expected %d, got %d" % [cash0 + 10, cash])
	if score != score0 + 20:
		fails.append("ped kill score: expected %d, got %d" % [score0 + 20, score])
	if combo_count < 1:
		fails.append("combo did not increment on ped kill (count=%d)" % combo_count)

	# --- 2. SMG damages, then kills, a cop ---
	_spawn_enemy("cop", player.global_position + Vector3(0, 0, -10))
	var cop = enemies[enemies.size() - 1]
	camera.look_at(cop.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	var cop_hp0: float = cop.hp
	shots = 0
	var saw_damage := false
	var cop_died := false
	while shots < 60:
		if not is_instance_valid(cop):
			cop_died = true
			break
		if cop.dead:
			cop_died = true
			break
		player.fire_cooldown = 0.0
		player_shoot_3d(false)
		shots += 1
		if is_instance_valid(cop) and cop.hp < cop_hp0:
			saw_damage = true
		await get_tree().physics_frame
	if is_instance_valid(cop) and cop.dead:
		cop_died = true
	if not is_instance_valid(cop):
		cop_died = true  # kill_enemy freed it — that IS the death
	if not saw_damage:
		fails.append("SMG never damaged the cop (hp stuck at %f)" % cop_hp0)
	if not cop_died:
		fails.append("SMG did not kill the cop after %d shots" % shots)
	if combo_count < 2:
		fails.append("combo did not reach 2 after two kills (count=%d)" % combo_count)

	# --- 3. Wanted: float storage, floor stars, caps, spawn types ---
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	wanted_level = 0.0
	add_wanted(1.4)
	if floori(wanted_level) != 1:
		fails.append("floor(1.4) gave %d stars, expected 1" % floori(wanted_level))
	if enemy_cap(1) != 3:
		fails.append("cap at 1 star is %d, expected 3" % enemy_cap(1))
	if enemy_cap(3) != 10:
		fails.append("cap at 3 stars is %d, expected 10" % enemy_cap(3))
	var spawned := 0
	for i in range(5):
		if try_spawn_enemy(true):
			spawned += 1
	if spawned != 3:
		fails.append("forced spawns at 1 star: expected 3 (cap), got %d" % spawned)
	for e in enemies:
		if e.kind != "cop":
			fails.append("1-star spawn kind is %s, expected cop" % e.kind)
	if spawn_type(3) != "swat":
		fails.append("spawn_type(3) is %s, expected swat" % spawn_type(3))
	if spawn_type(6) != "tank":
		fails.append("spawn_type(6) is %s, expected tank" % spawn_type(6))

	# --- 4. Drive-by: cooldown ticks in-car (HTML bug #2) ---
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	wanted_level = 0.0
	player.global_position = cars[0].global_position + Vector3(1, 0.3, 0)
	_try_enter_car()
	if player.driving == null:
		fails.append("autotest could not enter a car")
	else:
		player.fire_cooldown = 8.0
		for i in range(10):
			await get_tree().physics_frame
		if player.fire_cooldown >= 8.0:
			fails.append("drive-by cooldown did not tick in car (still %f)" % player.fire_cooldown)
		player.fire_cooldown = 0.0
		player_shoot_3d(true)
		if player.fire_cooldown != 8.0:
			fails.append("drive-by fire did not set cooldown 8 (got %f)" % player.fire_cooldown)
		_exit_car()

	# --- 5. Black Market: purchase, cost scaling, effects (Gate 3D-2) ---
	var fails2: Array[String] = []
	cash = 10000
	if upgrade_cost("hp") != 150:
		fails2.append("hp upgrade cost at level 0 is %d, expected 150" % upgrade_cost("hp"))
	if not buy_upgrade("hp"):
		fails2.append("buy_upgrade(hp) failed with $10000")
	if upgrade_level("hp") != 1:
		fails2.append("hp level is %d after purchase, expected 1" % upgrade_level("hp"))
	if cash != 10000 - 150:
		fails2.append("cash after hp purchase is %d, expected %d" % [cash, 10000 - 150])
	if player.max_hp != 125.0:
		fails2.append("max_hp after hp upgrade is %f, expected 125 (100 + 25)" % player.max_hp)
	if upgrade_cost("hp") != 210:
		fails2.append("hp upgrade cost at level 1 is %d, expected 210 (floor(150 x 1.4))" % upgrade_cost("hp"))
	if not buy_upgrade("damage"):
		fails2.append("buy_upgrade(damage) failed")
	if absf(damage_mult() - 1.15) > 0.001:
		fails2.append("damage_mult at level 1 is %f, expected 1.15" % damage_mult())
	if not buy_upgrade("firerate"):
		fails2.append("buy_upgrade(firerate) failed")
	if absf(firerate_mult() - 1.10) > 0.001:
		fails2.append("firerate_mult at level 1 is %f, expected 1.10" % firerate_mult())
	cash = 10
	if buy_upgrade("regen"):
		fails2.append("buy_upgrade(regen) succeeded with only $10 (cost 400)")
	if upgrade_level("regen") != 0:
		fails2.append("regen level changed after a failed purchase")

	# --- 6. Save / load roundtrip (Gate 3D-2) ---
	cash = 777
	score = 4321
	unlocked_weapons = [0, 1, 3]
	save_game()
	cash = 0
	score = 0
	for k in upgrade_levels:
		upgrade_levels[k] = 0
	unlocked_weapons = [0]
	load_game()
	apply_upgrades()
	if cash != 777:
		fails2.append("save/load: cash is %d, expected 777" % cash)
	if score != 4321:
		fails2.append("save/load: score is %d, expected 4321" % score)
	if upgrade_level("hp") != 1 or upgrade_level("damage") != 1:
		fails2.append("save/load: upgrade levels not restored (hp=%d damage=%d)" % [upgrade_level("hp"), upgrade_level("damage")])
	if unlocked_weapons.size() != 3 or not unlocked_weapons.has(3):
		fails2.append("save/load: unlocked weapons not restored (%s)" % str(unlocked_weapons))
	if player.max_hp != 125.0:
		fails2.append("save/load: max_hp is %f after restore, expected 125" % player.max_hp)
	# leave no test save behind
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# --- 7. WASD is camera-relative on foot (Gate 3D-2 walk fix) ---
	# Camera yaw -PI/2 makes camera forward +X (world east), NOT the
	# old world -Z. Walking "forward" must displace along +X, and
	# strafing right must displace along camera right (+Z here).
	var fails3: Array[String] = []
	if player.driving != null:
		_exit_car()
	cam_yaw = -PI / 2.0
	var expect_fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var expect_right := expect_fwd.cross(Vector3.UP)
	player.global_position = Vector3(0, 0.2, 8)  # open centre block
	player.velocity = Vector3.ZERO
	for i in range(3):
		await get_tree().physics_frame
	var walk_start := player.global_position
	player.move_override = Vector2(0, 1)  # forward
	for i in range(30):
		await get_tree().physics_frame
	player.move_override = Vector2(NAN, NAN)
	var disp := player.global_position - walk_start
	disp.y = 0.0
	if disp.length() < 1.5:
		fails3.append("walk forward: barely moved (%.2f units in 30 frames)" % disp.length())
	else:
		var dn := disp.normalized()
		if dn.dot(expect_fwd) <= 0.8:
			fails3.append("walk forward: displacement %s not along camera forward %s (dot %.2f)" % [str(dn), str(expect_fwd), dn.dot(expect_fwd)])
		if dn.dot(Vector3(0, 0, -1)) >= 0.3:
			fails3.append("walk forward: displacement %s still biased to world -Z (dot %.2f)" % [str(dn), dn.dot(Vector3(0, 0, -1))])
	var strafe_start := player.global_position
	player.move_override = Vector2(1, 0)  # strafe right
	for i in range(30):
		await get_tree().physics_frame
	player.move_override = Vector2(NAN, NAN)
	var sdisp := player.global_position - strafe_start
	sdisp.y = 0.0
	if sdisp.length() < 1.5:
		fails3.append("strafe right: barely moved (%.2f units in 30 frames)" % sdisp.length())
	elif sdisp.normalized().dot(expect_right) <= 0.8:
		fails3.append("strafe right: displacement %s not along camera right %s (dot %.2f)" % [str(sdisp.normalized()), str(expect_right), sdisp.normalized().dot(expect_right)])

	# --- 8. Detail Pass 1: walk cycle, car variants, signage, density ---
	# Checks read new APIs through .get() duck seams so a missing
	# feature fails as an assertion, not a parse error (the RED run
	# of this section is recorded in gate3d/README.md).
	var fails4: Array[String] = []
	# (a) walk cycle: phase advances with distance while walking,
	# swing is present while moving and settles when stopped; the
	# flap head (pivot height, upper-head children) is untouched.
	if player.driving != null:
		_exit_car()
	player.global_position = Vector3(0, 0.2, 8)
	player.velocity = Vector3.ZERO
	for i in range(3):
		await get_tree().physics_frame
	var phase0: Variant = player.get("walk_phase")
	player.move_override = Vector2(0, 1)  # forward, camera-relative
	var max_swing := 0.0
	for i in range(40):
		await get_tree().physics_frame
		var sw: Variant = player.get("walk_swing")
		if sw != null:
			max_swing = maxf(max_swing, float(sw))
	player.move_override = Vector2(NAN, NAN)
	var phase1: Variant = player.get("walk_phase")
	if phase0 == null or phase1 == null:
		fails4.append("walk_cycle: player has no walk_phase (walk API missing)")
	elif float(phase1) - float(phase0) < 1.0:
		fails4.append("walk_cycle: phase advanced %.2f rad over 40 walking frames, expected > 1.0" % (float(phase1) - float(phase0)))
	if max_swing < 0.15:
		fails4.append("walk_cycle: max limb swing %.2f rad while walking, expected > 0.15" % max_swing)
	for i in range(40):
		await get_tree().physics_frame
	var settle: Variant = player.get("walk_swing")
	if settle == null or float(settle) > 0.05:
		fails4.append("walk_cycle: swing did not settle when stopped (walk_swing=%s after 40 idle frames)" % str(settle))
	if player.upper_pivot == null:
		fails4.append("walk_cycle: upper_pivot missing (flap rig changed?)")
	else:
		if absf(player.upper_pivot.position.y - FlapRig.MOUTH_Y) > 0.001:
			fails4.append("walk_cycle: upper_pivot y is %.3f, expected MOUTH_Y %.2f" % [player.upper_pivot.position.y, FlapRig.MOUTH_Y])
		if player.upper_pivot.get_child_count() != 3:
			fails4.append("walk_cycle: upper head has %d children, expected 3 (head box + 2 eyes)" % player.upper_pivot.get_child_count())
	# a wandering ped walks too. A FRESH ped in open space: the
	# parked ambient peds sit in an 8-body pile at (100,100), where
	# a re-enabled ped just depenetrates on top of the pile and
	# never walks (probe-verified, see README) — that tests pile
	# physics, not the walk cycle.
	var wped := Ped3D.new()
	wped.main = self
	add_child(wped)
	wped.global_position = Vector3(6, 0.2, 16)  # open centre block
	var pp0: Variant = wped.get("walk_phase")
	for i in range(50):
		await get_tree().physics_frame
	var pp1: Variant = wped.get("walk_phase")
	if pp0 == null or pp1 == null or float(pp1) - float(pp0) <= 0.3:
		fails4.append("walk_cycle: a wandering ped's walk_phase did not advance")
	wped.queue_free()
	# and a chasing enemy
	_spawn_enemy("cop", player.global_position + Vector3(0, 0, -20))
	var ecop = enemies[enemies.size() - 1]
	var ep0: Variant = ecop.get("walk_phase")
	for i in range(40):
		await get_tree().physics_frame
	var ep1: Variant = ecop.get("walk_phase")
	if ep0 == null or ep1 == null or float(ep1) - float(ep0) < 0.3:
		fails4.append("walk_cycle: chasing enemy's walk_phase did not advance")
	ecop.queue_free()
	enemies.erase(ecop)

	# (b) car variants: >= 3 silhouettes, palette >= 8 colours,
	# wheels rotate proportional to speed (spin tracks speed / r)
	var styles := {}
	var car_colors_seen := {}
	for c in cars:
		var st: Variant = c.get("body_style")
		if st != null:
			styles[int(st)] = true
		car_colors_seen[c.car_color] = true
	if styles.size() < 3:
		fails4.append("car_variants: %d distinct body_style values across spawned cars, expected >= 3" % styles.size())
	var pal: Variant = cars[0].get("paint_colors")
	if pal == null:
		fails4.append("car_variants: cars expose no paint palette, expected >= 8 colours")
	elif (pal as Array).size() < 8:
		fails4.append("car_variants: paint palette has %d colours, expected >= 8" % (pal as Array).size())
	if car_colors_seen.size() < 3:
		fails4.append("car_variants: only %d distinct paint colours on spawned cars, expected >= 3" % car_colors_seen.size())
	var wc: Car3D = cars[0]
	wc.global_position = Vector3(-6, 0.2, 20)
	wc.rotation.y = 0.0
	wc.velocity = Vector3.ZERO
	for i in range(3):
		await get_tree().physics_frame
	wc.speed = 12.0
	var spin0: float = wc.spin_angle
	for i in range(10):
		await get_tree().physics_frame
	var dspin: float = wc.spin_angle - spin0
	if absf(dspin) < 2.0:
		fails4.append("car_variants: wheel spin changed %.2f rad in 10 frames at speed 12, expected > 2.0 (speed/r)" % dspin)
	wc.speed = 0.0

	# (c) signage + facade variance (registries live on CityBuilder)
	var sign_count_v: Variant = city.get("sign_count")
	if sign_count_v == null or int(sign_count_v) < 12:
		fails4.append("signage: sign_count is %s, expected >= 12" % str(sign_count_v))
	var accents_v: Variant = city.get("sign_accents")
	var acc_set := {}
	if accents_v != null:
		for a in accents_v:
			acc_set[a] = true
	if acc_set.size() < 4:
		fails4.append("signage: %d distinct sign accent colours, expected >= 4" % acc_set.size())
	var fseeds_v: Variant = city.get("facade_seeds")
	if fseeds_v == null or (fseeds_v as Array).size() < 20:
		fails4.append("signage: facade seed registry has %s entries, expected >= 20 buildings" % (str((fseeds_v as Array).size()) if fseeds_v != null else "none"))
	else:
		var seen := {}
		var dup := false
		for s in fseeds_v:
			if seen.has(s):
				dup = true
			seen[s] = true
		if dup:
			fails4.append("signage: facade seeds are not unique per building")
	var frat_v: Variant = city.get("facade_lit_ratios")
	var rset := {}
	if frat_v != null:
		for r in frat_v:
			rset[r] = true
	if rset.size() < 10:
		fails4.append("signage: only %d distinct lit-window ratios, expected >= 10 (variance)" % rset.size())

	# (d) density budget: >= 2x the 623-instance Gate 3D-2/Engine
	# Core baseline in MultiMesh instances, scene nodes < 900
	var counts := _scene_counts()
	var mm_instances: int = counts.y
	var node_count: int = counts.x
	if mm_instances < 1246:
		fails4.append("density_budget: %d MultiMesh instances, expected >= 1246 (2x the 623 baseline)" % mm_instances)
	if node_count >= 900:
		fails4.append("density_budget: %d scene nodes, expected < 900" % node_count)

	# --- 9. Detail 1 fix: road markings lie on the road surface ---
	# Vee's playtest (2026-10-31, iwantitnow, with screenshots):
	# "The markings for the road are on the sidewalks." The model is
	# CityBuilder's own layout math (is_asphalt / in_intersection_
	# box, shared with placement): a marking is on the road when it
	# sits on a road strip whose asphalt is the topmost surface —
	# where a block pad overlaps a strip, the higher top wins, so
	# markings under a taller pad paint pavement, not asphalt.
	var fails5: Array[String] = []
	var dash_v: Variant = city.get("dash_positions")
	if dash_v == null or (dash_v as Array).is_empty():
		fails5.append("markings_on_roads: no dash registry on CityBuilder")
	else:
		var off_road := 0
		var first_off := Vector3.ZERO
		for dp in dash_v:
			if not city.is_asphalt(dp.x, dp.z):
				off_road += 1
				if off_road == 1:
					first_off = dp
		if off_road > 0:
			fails5.append("markings_on_roads: %d of %d lane dashes are not on exposed asphalt (first at %s)" % [off_road, (dash_v as Array).size(), str(first_off)])
	var cw_v: Variant = city.get("crosswalk_positions")
	if cw_v == null or (cw_v as Array).is_empty():
		fails5.append("markings_on_roads: no crosswalk registry on CityBuilder")
	else:
		var off_cw := 0
		var first_cw := Vector3.ZERO
		for sp in cw_v:
			if not city.is_asphalt(sp.x, sp.z) and not city.in_intersection_box(sp.x, sp.z):
				off_cw += 1
				if off_cw == 1:
					first_cw = sp
		if off_cw > 0:
			fails5.append("markings_on_roads: %d of %d crosswalk stripes are not on asphalt or an intersection box (first at %s)" % [off_cw, (cw_v as Array).size(), str(first_cw)])

	# --- 10. Playtest telemetry (TELEMETRY_SPEC): DebugLog core
	# contract + the game's wiring. The logger is reached through
	# a load() seam and the game's logger through a get() duck
	# seam, so a missing module/wiring fails as assertions, not
	# a parse error (the Detail-1 precedent).
	var fails6: Array[String] = []
	var DL = load("res://core/debug_log.gd")
	if DL == null:
		fails6.append("telemetry_log: res://core/debug_log.gd is missing")
	else:
		var tdir := "user://telemetry_autotest_unit"
		_telemetry_test_wipe(tdir)
		var dl = DL.new()
		var snap_state := {"pos": Vector3(1.5, 0.2, -3.0), "vy": -0.5, "fps": 60, "wanted": 1.4, "in_car": true, "hp": 87.5, "cash": 42}
		if not dl.start_session(tdir, "AUTOTEST"):
			fails6.append("telemetry_log: start_session failed in a writable temp dir")
		else:
			var txt := FileAccess.get_file_as_string(dl.session_path)
			var first_nl := txt.find("\n")
			var header := txt.substr(0, first_nl) if first_nl >= 0 else txt
			if not header.begins_with("# GODOT-TELEMETRY"):
				fails6.append("telemetry_log: session header is '%s', expected a # GODOT-TELEMETRY line" % header)
			if not header.contains("build=AUTOTEST"):
				fails6.append("telemetry_log: header lacks the build label")
			dl._test_now = 1.25
			dl.snapshot(snap_state)
			dl.event("TEST_EVENT", {"k": 7, "word": "yes"})
			txt = FileAccess.get_file_as_string(dl.session_path)
			if not txt.contains("t=1.25 SNAPSHOT pos=1.50,0.20,-3.00"):
				fails6.append("telemetry_log: snapshot line missing or misformatted")
			for frag in ["vy=-0.50", "fps=60", "wanted=1.40", "in_car=true", "hp=87.5", "cash=42"]:
				if not txt.contains(frag):
					fails6.append("telemetry_log: snapshot line lacks %s" % frag)
			if not txt.contains("t=1.25 EVENT TEST_EVENT") or not txt.contains("k=7") or not txt.contains("word=yes"):
				fails6.append("telemetry_log: event line missing or misformatted")
			# core owns the timing: tick() accumulates to the
			# snapshot interval before writing the next snapshot
			var snaps_before: int = txt.count("SNAPSHOT")
			dl._test_now = 3.0
			dl.tick(0.3, snap_state)
			txt = FileAccess.get_file_as_string(dl.session_path)
			if txt.count("SNAPSHOT") != snaps_before:
				fails6.append("telemetry_log: tick(0.3) wrote a snapshot before the 0.5 s interval")
			dl.tick(0.3, snap_state)
			txt = FileAccess.get_file_as_string(dl.session_path)
			if txt.count("SNAPSHOT") != snaps_before + 1 or not txt.contains("t=3.00 SNAPSHOT"):
				fails6.append("telemetry_log: tick() did not emit exactly one snapshot at the interval")
			# marker: MARKER event + a forced frame via the provider
			var cap_img := Image.create(8, 8, false, Image.FORMAT_RGB8)
			cap_img.fill(Color(0.9, 0.2, 0.2))
			dl.frame_provider = func() -> Image: return cap_img
			dl._test_now = 20.0
			dl.marker()
			txt = FileAccess.get_file_as_string(dl.session_path)
			if not txt.contains("t=20.00 EVENT MARKER"):
				fails6.append("telemetry_log: marker() wrote no MARKER event")
			if dl.frames.size() != 1 or not str(dl.frames[0]).ends_with("frame-20.00.png"):
				fails6.append("telemetry_log: marker() kept frames %s, expected one frame-20.00.png" % str(dl.frames))
			# an empty image is refused (headless safety)
			if dl.capture_frame(Image.new()):
				fails6.append("telemetry_log: capture_frame accepted an empty image")
			# rotation: past the cap, the oldest frames are deleted
			dl.frame_cap = 3
			for ft in [30.0, 31.0, 32.0, 33.0]:
				dl._test_now = ft
				if not dl.capture_frame(cap_img):
					fails6.append("telemetry_log: capture_frame refused a real image at t=%.0f" % ft)
			if dl.frames.size() != 3:
				fails6.append("telemetry_log: rotation kept %d frames, expected the cap of 3" % dl.frames.size())
			if FileAccess.file_exists(tdir + "/frame-20.00.png"):
				fails6.append("telemetry_log: rotation did not delete the oldest frame file")
			if not FileAccess.file_exists(tdir + "/frame-33.00.png"):
				fails6.append("telemetry_log: newest frame file frame-33.00.png missing")
			dl.end_session()
		_telemetry_test_wipe(tdir)
	# wiring: the game itself started a session at _ready, ticks
	# snapshots from _process, and logs its real events
	var gdl = get("debug_log")
	if gdl == null:
		fails6.append("telemetry_log: game has no debug_log (telemetry not wired)")
	else:
		var gpath: String = gdl.session_path
		if gpath == "" or not FileAccess.file_exists(gpath):
			fails6.append("telemetry_log: game session file does not exist")
		else:
			var gtxt := FileAccess.get_file_as_string(gpath)
			if not gtxt.contains("build=Detail1+Telemetry"):
				fails6.append("telemetry_log: game session header lacks build=Detail1+Telemetry")
			_process(0.6)
			_process(0.6)
			gtxt = FileAccess.get_file_as_string(gpath)
			if not gtxt.contains("SNAPSHOT") or not gtxt.contains("pos="):
				fails6.append("telemetry_log: game _process ticking wrote no snapshot")
			var f9 := InputEventKey.new()
			f9.keycode = KEY_F9
			f9.pressed = true
			_input(f9)
			gtxt = FileAccess.get_file_as_string(gpath)
			if not gtxt.contains("EVENT MARKER"):
				fails6.append("telemetry_log: F9 produced no MARKER event in the game session")
			# BUSTED is the last wiring check: it reloads the
			# scene on a 2.5 s timer, and the prints + quit below
			# land well before that fires.
			on_player_death()
			gtxt = FileAccess.get_file_as_string(gpath)
			if not gtxt.contains("EVENT BUSTED"):
				fails6.append("telemetry_log: player death wrote no BUSTED event")
			if FileAccess.file_exists(save_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# --- 11. Wanted pacing (2026-11-01, Vee's real playtest:
	# many ped kills, never a star, never a cop) ---
	# The realistic chain the older sections never exercised:
	# kills minutes apart with wanted ticking in between (they
	# injected add_wanted(1.4) directly). Contract: three ped
	# kills through the REAL kill_ped path, each followed by 300
	# crime-free frames (5 s at 60 fps), must reach a star; from
	# that state a forced spawn must actually produce a cop; and
	# one decay step must be PARTIAL (the data's decay_step),
	# not a whole star.
	var fails7: Array[String] = []
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	wanted_level = 0.0
	frames_since_crime = 0
	for k in range(3):
		var wp := Ped3D.new()
		wp.main = self
		add_child(wp)
		wp.set_physics_process(false)
		wp.global_position = Vector3(90, 0.2, 90 + k * 3)
		kill_ped(wp, false)
		if not wp.dead:
			fails7.append("wanted_pacing: kill_ped #%d did not kill the ped" % (k + 1))
		for i in range(300):
			wanted_sys.tick()
	if stars_now() < 1:
		fails7.append("wanted_pacing: 3 ped kills 300 frames apart gave level %.2f (%d stars), expected >= 1 star" % [wanted_level, stars_now()])
	var enemies_before := enemies.size()
	if not try_spawn_enemy(true):
		fails7.append("wanted_pacing: try_spawn_enemy(true) at %d stars (level %.2f) spawned nothing" % [stars_now(), wanted_level])
	elif enemies.size() != enemies_before + 1:
		fails7.append("wanted_pacing: forced spawn added %d enemies, expected 1" % (enemies.size() - enemies_before))
	elif enemies[enemies.size() - 1].kind != "cop":
		fails7.append("wanted_pacing: first spawn at 1 star is %s, expected cop" % enemies[enemies.size() - 1].kind)
	# decay: 1.2 set via adds, then 601 crime-free frames must
	# cost exactly one decay_step (~0.25), landing at ~0.95
	wanted_level = 0.0
	frames_since_crime = 0
	add_wanted(1.2)
	for i in range(601):
		wanted_sys.tick()
	if absf(wanted_level - 0.95) > 0.01:
		fails7.append("wanted_pacing: decay from 1.20 after 601 crime-free frames gave %.2f, expected ~0.95 (one partial decay_step)" % wanted_level)

	if fails.is_empty():
		print("AUTOTEST PASS: smg_ped_kill cash+score+combo | smg_cop_damage+kill | wanted_floor caps spawn_types | driveby_cooldown_ticks")
	else:
		for f in fails:
			print("AUTOTEST FAIL: ", f)
	if fails2.is_empty():
		print("AUTOTEST PASS: upgrade_purchase cost_scaling effects | save_load_roundtrip")
	else:
		for f in fails2:
			print("AUTOTEST FAIL: ", f)
	if fails3.is_empty():
		print("AUTOTEST PASS: wasd_camera_relative")
	else:
		for f in fails3:
			print("AUTOTEST FAIL: ", f)
	if fails4.is_empty():
		print("AUTOTEST PASS: detail1 walk_cycle car_variants signage density_budget")
	else:
		for f in fails4:
			print("AUTOTEST FAIL: ", f)
	if fails5.is_empty():
		print("AUTOTEST PASS: markings_on_roads")
	else:
		for f in fails5:
			print("AUTOTEST FAIL: ", f)
	if fails6.is_empty():
		print("AUTOTEST PASS: telemetry_log session snapshots events frames marker wiring")
	else:
		for f in fails6:
			print("AUTOTEST FAIL: ", f)
	if fails7.is_empty():
		print("AUTOTEST PASS: wanted_pacing ped_chain_star cop_spawn decay_partial")
	else:
		for f in fails7:
			print("AUTOTEST FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() and fails2.is_empty() and fails3.is_empty() and fails4.is_empty() and fails5.is_empty() and fails6.is_empty() and fails7.is_empty() else 1)
