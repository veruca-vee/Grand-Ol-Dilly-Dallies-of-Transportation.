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
	data = DataLoader.load_json("res://data/enemies_world_wanted.json")
	weapons = DataLoader.load_array("res://data/weapons.json", "weapons")
	driveby_weapon = DataLoader.load_json("res://data/weapons.json").get("driveby_weapon", {})
	for e in data.get("enemies", []):
		enemy_stats[e.get("type", "")] = e
	wanted_cfg = data.get("wanted", {})
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
	var car_colors := [Color(0.75, 0.25, 0.25), Color(0.25, 0.35, 0.8), Color(0.3, 0.65, 0.3), Color(0.8, 0.7, 0.2), Color(0.55, 0.57, 0.62), Color(0.45, 0.2, 0.55)]
	var car_spots := [Vector3(4, 0.2, -2), Vector3(-14, 0.2, -30), Vector3(20, 0.2, 24), Vector3(-30, 0.2, 18), Vector3(30, 0.2, -34), Vector3(-24, 0.2, 44)]
	for i in range(car_spots.size()):
		var car := Car3D.new()
		car.car_color = car_colors[i]
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
	if "--countnodes" in args or "--countnodes" in OS.get_cmdline_args():
		var mm_instances := 0
		var stack: Array = [self]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MultiMeshInstance3D and n.multimesh != null:
				mm_instances += n.multimesh.instance_count
			for ch in n.get_children():
				stack.append(ch)
		print("NODECOUNT: nodes=", get_tree().get_node_count(), " multimesh_instances=", mm_instances)
	if autotest:
		_run_autotest()

# ---------- Debug: windowed screenshot for visual checks ----------
func _take_screenshot() -> void:
	# Used with a real (Xvfb) display, NOT headless: lets a human or
	# the assistant eyeball the dressed city. Saves + quits.
	for i in range(100):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://gate3d_shot.png"
	img.save_png(path)
	print("SCREENSHOT: ", ProjectSettings.globalize_path(path), " ", img.get_size())
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
	var help := HudKit.make_label("WASD move/drive · mouse aims · LMB fire · 1-9 / Q weapons · E enter/exit car · B black market · hold T to talk", Vector2(10, 660), 14)
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
	add_wanted(0.15)
	spawn_pickup_3d(p.global_position, "cash")
	refresh_hud()

func kill_car(c: Car3D) -> void:
	if c.dead:
		return
	c.dead = true
	c.speed = 0.0
	c.set_dead_visual()
	cars_destroyed += 1
	add_wanted(0.3)
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
	add_wanted(0.1)
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
		player.visible = false
		player.set_physics_process(false)
		if player.body_shape != null:
			player.body_shape.disabled = true
		refresh_hud()

func _exit_car() -> void:
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
			pk.queue_free()
			refresh_hud()
	refresh_hud()

func _process(delta: float) -> void:
	if shop_open:
		return
	_update_fx(delta)
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
	get_tree().quit(0 if fails.is_empty() and fails2.is_empty() and fails3.is_empty() else 1)
