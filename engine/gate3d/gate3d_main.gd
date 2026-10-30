extends Node3D

# G.O.D.O.T — Gate 3D-1
# Gate 3D-0's PS2-era greybox (third-person, low-poly primitives,
# fog 0.012 + camera far 160, seed-2004 city, hinge flap-heads,
# enter/drive cars) with the Gate 0 systems ported in: all 9 weapons,
# the wanted system, and the cash/combo economy. Every balance number
# comes from res://data/*.json via GameData, and the rules mirror
# engine/scripts/main.gd (the 2D implementation) — including its two
# HTML bug fixes:
#   1. wanted is stored as a FLOAT; every star/cap/type lookup uses
#      floori(wanted_level). The HTML indexed arrays with the float.
#   2. the fire cooldown ticks EVERY physics frame, on foot and
#      in-car. The HTML never ticked it in-car; drive-by fired once.
# 3D adaptations are labelled in gate3d/README.md (distance scale
# /15, speed ratio 5.0/3.8, camera-ray hitscan, weapon pickups).

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
var cam_yaw: float = 0.0
var state: String = "PLAYING"

var cash: int = 0
var score: int = 0
var kills: int = 0
var cars_destroyed: int = 0

var wanted_level: float = 0.0
var frames_since_crime: int = 0
var combo_count: int = 0
var combo_frames: int = 0

var hud_hp: ProgressBar = null
var hud_weapon: Label = null
var hud_cash: Label = null
var hud_stars: Label = null
var hud_combo: Label = null
var hud_center: Label = null

var fx: Array = []  # transient visuals: {node, ttl, max_ttl, grow}
var autotest: bool = false

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _ready() -> void:
	data = GameData.world_enemies_wanted()
	weapons = GameData.weapons()
	driveby_weapon = GameData.load_json("res://data/weapons.json").get("driveby_weapon", {})
	for e in data.get("enemies", []):
		enemy_stats[e.get("type", "")] = e
	wanted_cfg = data.get("wanted", {})
	car_stats = data.get("car", {})
	ped_stats = data.get("pedestrian", {})

	_setup_environment()
	_build_city()
	player = Player3D.new()
	player.position = Vector3(0, 0.2, 8)
	player.main = self
	add_child(player)
	player.max_hp = float(data.get("player", {}).get("base_hp", 100))
	player.hp = player.max_hp
	player.weapon_index = int(GameData.load_json("res://data/weapons.json").get("player_start_weapon_index", 1))
	player.refresh_gun(weapons[player.weapon_index])
	var car_colors := [Color(0.75, 0.25, 0.25), Color(0.25, 0.35, 0.8), Color(0.3, 0.65, 0.3), Color(0.8, 0.7, 0.2)]
	var car_spots := [Vector3(4, 0.2, -2), Vector3(-14, 0.2, -30), Vector3(20, 0.2, 24), Vector3(-30, 0.2, 18)]
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

	var args := OS.get_cmdline_user_args()
	if "--autotest" in args or "--autotest" in OS.get_cmdline_args():
		autotest = true
		_run_autotest()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.70, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.73, 0.79)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.4
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)

func _build_city() -> void:
	# ground slab with collision
	var ground := StaticBody3D.new()
	var gmesh := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(240, 1, 240)
	gmesh.mesh = gbox
	gmesh.position = Vector3(0, -0.5, 0)
	gmesh.material_override = _mat(Color(0.23, 0.25, 0.23))
	ground.add_child(gmesh)
	var gshape := CollisionShape3D.new()
	var gcol := BoxShape3D.new()
	gcol.size = Vector3(240, 1, 240)
	gshape.shape = gcol
	gshape.position = Vector3(0, -0.5, 0)
	ground.add_child(gshape)
	add_child(ground)
	# roads: flat dark strips on a grid (pitch 52, as the 2D block grid scaled)
	for i in range(-2, 3):
		_road(Vector3(i * 52, 0.02, 0), Vector3(10, 0.05, 240))
		_road(Vector3(0, 0.02, i * 52), Vector3(240, 0.05, 10))
	# buildings: seeded greybox towers on the blocks between roads
	var rng := RandomNumberGenerator.new()
	rng.seed = 2004  # San Andreas launch year, why not
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			if bx == 0 and bz == 0:
				continue  # spawn block stays open
			var h := rng.randf_range(6.0, 26.0)
			var cx := bx * 52 + rng.randf_range(-6, 6)
			var cz := bz * 52 + rng.randf_range(-6, 6)
			_building(Vector3(cx, 0, cz), Vector3(26, h, 26), Color.from_hsv(rng.randf_range(0.05, 0.12), 0.25, rng.randf_range(0.45, 0.7)))

func _road(pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(Color(0.08, 0.08, 0.09))
	add_child(mi)

func _building(pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, 0, pos.z)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0, size.y / 2, 0)
	mi.material_override = _mat(color)
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = size
	shape.shape = col
	shape.position = Vector3(0, size.y / 2, 0)
	body.add_child(shape)
	buildings.append(Rect2(pos.x - size.x / 2, pos.z - size.z / 2, size.x, size.z))
	add_child(body)

# ---------- HUD ----------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.07, 0.17, 0.85)  # Midnight Circle panel
	panel.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.49, 1.0, 0.95)  # violet C77DFF
	fill.set_corner_radius_all(4)
	hud_hp = ProgressBar.new()
	hud_hp.position = Vector2(10, 10)
	hud_hp.custom_minimum_size = Vector2(220, 18)
	hud_hp.size = Vector2(220, 18)
	hud_hp.max_value = player.max_hp
	hud_hp.value = player.hp
	hud_hp.show_percentage = false
	hud_hp.add_theme_stylebox_override("background", panel)
	hud_hp.add_theme_stylebox_override("fill", fill)
	layer.add_child(hud_hp)
	hud_weapon = Label.new()
	hud_weapon.position = Vector2(10, 34)
	hud_weapon.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud_weapon)
	hud_combo = Label.new()
	hud_combo.position = Vector2(10, 58)
	hud_combo.add_theme_font_size_override("font_size", 16)
	hud_combo.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))  # candle gold FFD479
	layer.add_child(hud_combo)
	hud_cash = Label.new()
	hud_cash.position = Vector2(1020, 8)
	hud_cash.add_theme_font_size_override("font_size", 18)
	hud_cash.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	layer.add_child(hud_cash)
	hud_stars = Label.new()
	hud_stars.position = Vector2(1020, 34)
	hud_stars.add_theme_font_size_override("font_size", 20)
	hud_stars.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	layer.add_child(hud_stars)
	var help := Label.new()
	help.position = Vector2(10, 660)
	help.add_theme_font_size_override("font_size", 14)
	help.text = "WASD move/drive · mouse aims · LMB fire · 1-9 / Q weapons · E enter/exit car · hold T to talk"
	layer.add_child(help)
	var cross := Label.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7, -16)
	cross.add_theme_font_size_override("font_size", 20)
	cross.text = "+"
	layer.add_child(cross)
	hud_center = Label.new()
	hud_center.position = Vector2(490, 300)
	hud_center.add_theme_font_size_override("font_size", 42)
	hud_center.add_theme_color_override("font_color", Color(1.0, 0.33, 0.44))  # ember FF5370
	hud_center.visible = false
	layer.add_child(hud_center)

func refresh_hud() -> void:
	if player == null or hud_hp == null:
		return
	hud_hp.max_value = player.max_hp
	hud_hp.value = maxi(0, int(player.hp))
	hud_weapon.text = str(weapons[player.weapon_index].get("name", "")) if weapons.size() > 0 else ""
	hud_cash.text = "$%d   Score %d" % [cash, score]
	var stars := ""
	for i in range(6):
		stars += "★" if i < floori(wanted_level) else "☆"
	hud_stars.text = stars
	if combo_count > 1:
		hud_combo.text = "COMBO x%.1f (%d)" % [minf(5.0, 1.0 + combo_count * 0.5), combo_count]
	else:
		hud_combo.text = ""

# ---------- Wanted / combo (mirrors scripts/main.gd) ----------
func add_wanted(amt: float) -> void:
	wanted_level = minf(6.0, wanted_level + amt)
	frames_since_crime = 0
	refresh_hud()

func add_combo() -> float:
	combo_count += 1
	combo_frames = int(data.get("combo", {}).get("window_frames", 120))
	if combo_count > 1:
		return minf(5.0, 1.0 + combo_count * 0.5)
	return 1.0

func stars_now() -> int:
	return mini(floori(wanted_level), int(wanted_cfg.get("max_stars", 6)))

func enemy_cap(stars: int) -> int:
	var caps: Array = wanted_cfg.get("max_active_enemies_by_star", [0, 3, 6, 10, 15, 22, 30])
	return int(caps[mini(stars, caps.size() - 1)])

func spawn_type(stars: int) -> String:
	var types: Array = wanted_cfg.get("spawn_type_by_star_index_0_based", ["cop"])
	return str(types[mini(maxi(stars - 1, 0), types.size() - 1)])

func try_spawn_enemy(force: bool = false) -> bool:
	var stars := stars_now()
	if stars <= 0:
		return false
	if enemies.size() >= enemy_cap(stars):
		return false
	if not force and randf() >= 0.02 + stars * 0.005:
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
	var weapon: Dictionary = driveby_weapon if driveby else weapons[player.weapon_index]
	var rate := float(weapon.get("rate_frames", 8))
	var range3d := float(weapon.get("range", 400)) / SCALE
	var shooter: Node3D = player.driving if driveby and player.driving != null else player
	var muzzle := shooter.global_position + Vector3(0, 1.25, 0)
	if not driveby:
		player.rotation.y = cam_yaw  # face where the camera aims
	if weapon.get("melee", false):
		_melee_attack(weapon)
		player.fire_cooldown = rate
		return
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	if player.driving != null:
		exclude.append(player.driving.get_rid())
	var cam_from := camera.global_position
	var cam_dir := -camera.global_transform.basis.z
	var spread := float(weapon.get("spread", 0.0))
	var color := Color(weapon.get("color", "#ffdd88"))
	if weapon.get("rocket", false):
		var aim := _ray_end(space, cam_from, cam_dir, range3d, exclude)
		var dir := (aim - muzzle).normalized()
		var b := Bullet3D.new()
		add_child(b)
		b.setup(muzzle, dir * 40.0, float(weapon.get("dmg", 200)), true, true, float(weapon.get("range", 800)) / 10.0, player, self, color)
		_spawn_flash(muzzle, color)
		player.fire_cooldown = rate
		player.fire_flap_time = 0.15
		return
	for i in range(int(weapon.get("count", 1))):
		var dir_i := cam_dir
		if spread > 0.0:
			dir_i = (cam_dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * spread).normalized()
		var aim := _ray_end(space, cam_from, dir_i, range3d, exclude)
		var q := PhysicsRayQueryParameters3D.create(muzzle, aim, 7, exclude)
		var hit := space.intersect_ray(q)
		var end := aim
		if not hit.is_empty():
			end = hit.position
			_apply_hitscan_hit(hit.collider, weapon)
		_spawn_tracer(muzzle, end, color)
	_spawn_flash(muzzle, color)
	player.fire_cooldown = rate
	player.fire_flap_time = 0.15

func _ray_end(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, dist: float, exclude: Array[RID]) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 7, exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	return from + dir * dist

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
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and origin.distance_to(p.global_position) < 2.6 and facing.dot((p.global_position - origin).normalized()) > 0.2:
			kill_ped(p, false)
	for e in enemies:
		if not e.dead and origin.distance_to(e.global_position) < 2.8 and facing.dot((e.global_position - origin).normalized()) > 0.2:
			e.take_damage(dmg)
	for c in cars:
		if not c.dead and c != player.driving and origin.distance_to(c.global_position) < 3.4 and facing.dot((c.global_position - origin).normalized()) > 0.2:
			c.take_damage(dmg)
	player.fire_flap_time = 0.15

func enemy_shoot_3d(e: Node3D) -> void:
	if player == null:
		return
	var from: Vector3 = e.gun_position()
	var target := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	dir = (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.15).normalized()  # 2D aim jitter
	var b := Bullet3D.new()
	add_child(b)
	b.setup(from, dir * 72.0, float(e.dmg), false, false, float(e.bullet_life_frames), e, self, Color(1, 0.27, 0.27))

func resolve_bullet3d(b: Bullet3D) -> void:
	# Same order as the 2D resolve_bullet: cars, peds, enemies, player.
	# Hit distances are the 2D radii / 15, measured to body centres.
	var pos := b.global_position
	for c in cars:
		if c.dead:
			continue
		if b.is_player and player != null and player.driving == c:
			continue
		if pos.distance_to(c.global_position + Vector3(0, 0.6, 0)) < 1.9:
			c.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 110, b.damage * 0.8, b)
			b.queue_free()
			return
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and pos.distance_to(p.global_position + Vector3(0, 0.9, 0)) < 0.95:
			kill_ped(p, false)
			if b.is_rocket:
				explode_3d(pos, 80, b.damage * 0.5, b)
			b.queue_free()
			return
	for e in enemies:
		if not e.dead and e != b.shooter and pos.distance_to(e.global_position + Vector3(0, 0.9, 0)) < 1.2:
			e.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 90, b.damage * 0.6, b)
			b.queue_free()
			return
	if not b.is_player and player != null and not player.dead and player.driving == null:
		if pos.distance_to(player.global_position + Vector3(0, 0.9, 0)) < 1.05:
			player.take_damage(b.damage * 0.5)  # 2D halves enemy bullet damage to the player
			b.queue_free()

func explode_3d(pos: Vector3, radius2d: float, dmg: float, source: Object) -> void:
	# 2D explode(): cars/enemies take dmg * (1 - d/r) * 1.5, peds die
	# within r * 0.8, the player takes dmg * 0.4 within r * 0.7.
	var radius := radius2d / SCALE
	_spawn_explosion_fx(pos, radius)
	for c in cars:
		if not c.dead and c != source and pos.distance_to(c.global_position) < radius:
			c.take_damage(dmg * (1.0 - pos.distance_to(c.global_position) / radius) * 1.5)
	for e in enemies:
		if not e.dead and e != source and pos.distance_to(e.global_position) < radius:
			e.take_damage(dmg * (1.0 - pos.distance_to(e.global_position) / radius) * 1.5)
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
	cash += int(base * mult)
	score += int(float(ped_stats.get("score", 20)) * mult)
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
	cash += int(float(car_stats.get("cash_on_destroy", 25)) * mult)
	score += int(float(car_stats.get("score", 50)) * mult)
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
	cash += int(float(stats.get("cash_on_kill", 20)) * mult)
	score += int(float(stats.get("score", 100)) * mult)
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
	refresh_hud()

func on_player_death() -> void:
	if state != "PLAYING":
		return
	state = "GAMEOVER"
	player.dead = true
	if player.driving != null:
		_exit_car()
	explode_3d(player.global_position, 80, 50, player)
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
	if player == null or state != "PLAYING":
		return
	# The cooldown ticks EVERY physics frame in both modes.
	# (HTML bug fixed here, as in Gate 0: in-car it never ticked.)
	if player.fire_cooldown > 0.0:
		player.fire_cooldown -= 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.fire_cooldown <= 0.0 and not player.dead:
		player_shoot_3d(player.driving != null)
	if combo_frames > 0:
		combo_frames -= 1
		if combo_frames <= 0:
			combo_count = 0
	if wanted_level > 0.0:
		frames_since_crime += 1
		var decay := int(wanted_cfg.get("decay_frames_without_crime", 600))
		if frames_since_crime > decay:
			frames_since_crime = 0
			wanted_level = maxf(0.0, wanted_level - 1.0)
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
			if pk.kind == "health":
				player.hp = minf(player.max_hp, player.hp + 30.0)
			elif pk.kind == "weapon":
				if weapons.size() > 1:
					player.weapon_index = randi_range(1, weapons.size() - 1)
					player.refresh_gun(weapons[player.weapon_index])
			else:
				cash += 15
			pk.queue_free()
			refresh_hud()
	refresh_hud()

func _process(delta: float) -> void:
	_update_fx(delta)
	if player == null or camera == null or autotest:
		return
	var actor: Node3D = player.driving if player.driving != null else player
	if player.driving != null:
		player.global_position = player.driving.global_position + Vector3(0, 0.3, 0)
	# follow camera: behind + above the actor, yaw lerps to the actor's
	var actor_yaw := actor.global_transform.basis.get_euler().y
	cam_yaw = lerp_angle(cam_yaw, actor_yaw, delta * 4.0)
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))  # behind a -Z-facing actor is +Z in its yaw frame
	var dist := 9.0 if player.driving != null else 6.5
	var height := 4.0 if player.driving != null else 3.0
	var target_pos := actor.global_position + back * dist + Vector3(0, height, 0)
	camera.global_position = camera.global_position.lerp(target_pos, delta * 8.0)
	camera.look_at(actor.global_position + Vector3(0, 1.4, 0), Vector3.UP)

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

	if fails.is_empty():
		print("AUTOTEST PASS: smg_ped_kill cash+score+combo | smg_cop_damage+kill | wanted_floor caps spawn_types | driveby_cooldown_ticks")
	else:
		for f in fails:
			print("AUTOTEST FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() else 1)
