extends Node2D

# Felony City — Gate 0 greybox main.
# All balance numbers come from res://data/*.json (copied from the HTML).

var data: Dictionary = {}
var weapons: Array = []
var enemy_stats: Dictionary = {}  # kind -> stats dict
var wanted_cfg: Dictionary = {}
var car_stats: Dictionary = {}
var ped_stats: Dictionary = {}

var world: World = null
var player: Player = null
var camera: Camera2D = null
var hud: Dictionary = {}
var state: String = "PLAYING"

var cash: int = 0
var score: int = 0
var kills: int = 0
var cars_destroyed: int = 0

# Wanted is stored as a FLOAT (HTML gains are 0.1 / 0.15 / 0.3) and every
# table lookup uses floori(wanted_level). The HTML indexed arrays with the
# float and got undefined — that bug is fixed here, not copied.
var wanted_level: float = 0.0
var frames_since_crime: int = 0
var combo_count: int = 0
var combo_frames: int = 0
var shake: float = 0.0

func _ready() -> void:
	data = GameData.world_enemies_wanted()
	weapons = GameData.weapons()
	for e in data.get("enemies", []):
		enemy_stats[e.get("type", "")] = e
	wanted_cfg = data.get("wanted", {})
	car_stats = data.get("car", {})
	ped_stats = data.get("pedestrian", {})

	world = World.new()
	add_child(world)

	player = Player.new()
	player.global_position = Vector2(World.SIZE / 2, World.SIZE / 2)
	player.world = world
	player.main = self
	add_child(player)

	camera = Camera2D.new()
	camera.global_position = player.global_position
	add_child(camera)
	camera.make_current()

	_build_hud()

	var car_colors := [Color(0.8, 0.27, 0.27), Color(0.27, 0.27, 0.8), Color(0.27, 0.65, 0.27), Color(0.8, 0.8, 0.27), Color(0.55, 0.55, 0.55), Color(0.65, 0.3, 0.8)]
	for i in range(int(data.get("world", {}).get("start_cars", 18))):
		var car := Car.new()
		car.global_position = _random_pos()
		car.rotation = randf() * TAU
		car.car_color = car_colors[randi() % car_colors.size()]
		car.world = world
		car.main = self
		car.ai = randf() < 0.5
		add_child(car)
	for i in range(int(data.get("world", {}).get("start_peds", 50))):
		var ped := Ped.new()
		ped.global_position = _random_pos()
		ped.world = world
		ped.main = self
		add_child(ped)
	refresh_hud()

func _random_pos() -> Vector2:
	for attempt in range(20):
		var p := Vector2(200 + randf() * (World.SIZE - 400), 200 + randf() * (World.SIZE - 400))
		if not world.is_blocked(p, 34):
			return p
	return Vector2(World.SIZE / 2 + 100, World.SIZE / 2)

func player_weapon_index() -> int:
	return player.weapon_index if player != null else 0

# ---------- HUD ----------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	for key in ["hp", "weapon", "cash", "stars", "center"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 28 if key == "center" else 16)
		layer.add_child(label)
		hud[key] = label
	hud["hp"].position = Vector2(10, 8)
	hud["weapon"].position = Vector2(10, 32)
	hud["cash"].position = Vector2(1050, 8)
	hud["stars"].position = Vector2(1050, 32)
	hud["center"].position = Vector2(540, 320)
	hud["center"].visible = false

func refresh_hud() -> void:
	if player == null or hud.is_empty():
		return
	hud["hp"].text = "HP %d" % maxi(0, int(player.hp))
	hud["weapon"].text = str(weapons[player.weapon_index].get("name", "")) if weapons.size() > 0 else ""
	hud["cash"].text = "$%d  Score %d" % [cash, score]
	var stars := ""
	for i in range(6):
		stars += "★" if i < floori(wanted_level) else "☆"
	hud["stars"].text = stars

# ---------- Wanted / combo ----------
func add_wanted(amt: float) -> void:
	wanted_level = minf(6.0, wanted_level + amt)
	frames_since_crime = 0
	refresh_hud()

func add_combo() -> float:
	combo_count += 1
	combo_frames = 120
	if combo_count > 1:
		return minf(5.0, 1.0 + combo_count * 0.5)
	return 1.0

# ---------- Shooting ----------
func player_shoot(from_pos: Vector2, angle: float, driveby: bool) -> void:
	var weapon: Dictionary
	if driveby:
		weapon = GameData.load_json("res://data/weapons.json").get("driveby_weapon", {})
	else:
		weapon = weapons[player.weapon_index]
	if weapon.get("melee", false):
		var hit := from_pos + Vector2(cos(angle), sin(angle)) * 28.0
		for p in get_tree().get_nodes_in_group("peds"):
			if not p.dead and hit.distance_to(p.global_position) < 22.0:
				kill_ped(p, false)
		for e in get_tree().get_nodes_in_group("enemies"):
			if not e.dead and hit.distance_to(e.global_position) < 25.0:
				e.take_damage(float(weapon.get("dmg", 12)))
		for c in get_tree().get_nodes_in_group("cars"):
			if not c.dead and hit.distance_to(c.global_position) < 30.0:
				c.take_damage(float(weapon.get("dmg", 12)))
		player.fire_cooldown = float(weapon.get("rate_frames", 25))
		return
	var muzzle := from_pos + Vector2(cos(angle), sin(angle)) * 18.0
	for i in range(int(weapon.get("count", 1))):
		var b := Bullet.new()
		add_child(b)
		b.setup(muzzle, angle + (randf() - 0.5) * float(weapon.get("spread", 0.0)), weapon, true, 1.0, self)
	player.fire_cooldown = float(weapon.get("rate_frames", 8))

func enemy_shoot(e: Enemy) -> void:
	var weapon := {"dmg": e.dmg, "range": e.range_, "rocket": false, "color": "#ff4444", "spread": 0.0}
	var b := Bullet.new()
	add_child(b)
	b.setup(e.global_position, e.rotation + (randf() - 0.5) * 0.15, weapon, false, 1.0, self)

func resolve_bullet(b: Bullet) -> void:
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		return
	var pos := b.global_position
	if world.hits_building(pos):
		if b.is_rocket:
			explode(pos, 100, b.damage, b)
		b.queue_free()
		return
	for c in get_tree().get_nodes_in_group("cars"):
		if c.dead or in_car_bullet_skip(c, b):
			continue
		if pos.distance_to(c.global_position) < 28.0:
			c.take_damage(b.damage)
			if b.is_rocket:
				explode(pos, 110, b.damage * 0.8, b)
			b.queue_free()
			return
	for p in get_tree().get_nodes_in_group("peds"):
		if not p.dead and pos.distance_to(p.global_position) < 14.0:
			kill_ped(p, false)
			if b.is_rocket:
				explode(pos, 80, b.damage * 0.5, b)
			b.queue_free()
			return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and pos.distance_to(e.global_position) < 18.0:
			e.take_damage(b.damage)
			if b.is_rocket:
				explode(pos, 90, b.damage * 0.6, b)
			b.queue_free()
			return
	if not b.is_player and player != null and not player.dead and not player.in_car:
		if pos.distance_to(player.global_position) < 16.0:
			player.take_damage(b.damage * 0.5)
			b.queue_free()

func in_car_bullet_skip(c: Car, b: Bullet) -> bool:
	# A player bullet should not instantly hit the car the player is driving.
	return b.is_player and player != null and player.in_car and player.vehicle == c

# ---------- Deaths / economy ----------
func kill_ped(p: Ped, run_over: bool) -> void:
	if p.dead:
		return
	p.dead = true
	var mult := add_combo()
	var gain := int(float(ped_stats.get("cash_runover", 15) if run_over else ped_stats.get("cash_on_kill", 10)) * mult)
	cash += gain
	score += int(20 * mult)
	add_wanted(0.15)
	spawn_pickup(p.global_position, "cash")
	p.queue_free()
	refresh_hud()

func kill_car(c: Car) -> void:
	if c.dead:
		return
	c.dead = true
	c.speed = 0.0
	cars_destroyed += 1
	add_wanted(0.3)
	var mult := add_combo()
	cash += int(float(car_stats.get("cash_on_destroy", 25)) * mult)
	score += int(50 * mult)
	explode(c.global_position, 90, 80, c)
	spawn_pickup(c.global_position, "cash" if randf() < 0.5 else "health")
	refresh_hud()
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void: if is_instance_valid(c): c.queue_free())

func kill_enemy(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	kills += 1
	add_wanted(0.1)
	var mult := add_combo()
	var stats: Dictionary = enemy_stats.get(e.kind, {})
	cash += int(float(stats.get("cash_on_kill", 20)) * mult)
	score += int(float(stats.get("score", 100)) * mult)
	explode(e.global_position, 120 if e.kind == "tank" else 60, 100 if e.kind == "tank" else 40, e)
	spawn_pickup(e.global_position, "health" if e.kind == "tank" else "cash")
	e.queue_free()
	refresh_hud()

func check_car_runovers(c: Car) -> void:
	for p in get_tree().get_nodes_in_group("peds"):
		if not p.dead and c.global_position.distance_to(p.global_position) < 26.0:
			kill_ped(p, true)

func spawn_pickup(pos: Vector2, kind: String) -> void:
	if randf() >= 0.3:  # HTML spawnPickup gate
		return
	var pk := Pickup.new()
	pk.kind = kind
	pk.global_position = pos
	add_child(pk)

func explode(pos: Vector2, radius_: float, dmg: float, source: Object) -> void:
	shake = minf(30.0, shake + 15.0)
	var fx := Explosion.new()
	fx.max_radius = radius_
	fx.global_position = pos
	add_child(fx)
	for c in get_tree().get_nodes_in_group("cars"):
		if not c.dead and c != source and pos.distance_to(c.global_position) < radius_:
			c.take_damage(dmg * (1.0 - pos.distance_to(c.global_position) / radius_) * 1.5)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e != source and pos.distance_to(e.global_position) < radius_:
			e.take_damage(dmg * (1.0 - pos.distance_to(e.global_position) / radius_) * 1.5)
	for p in get_tree().get_nodes_in_group("peds"):
		if not p.dead and pos.distance_to(p.global_position) < radius_ * 0.8:
			kill_ped(p, false)
	if player != null and not player.dead and pos.distance_to(player.global_position) < radius_ * 0.7:
		player.take_damage(dmg * 0.4)

# ---------- Player events ----------
func on_player_damaged() -> void:
	shake = minf(20.0, shake + 8.0)
	refresh_hud()

func on_player_death() -> void:
	if state != "PLAYING":
		return
	state = "GAMEOVER"
	player.dead = true
	if player.in_car:
		player.exit_car()
	explode(player.global_position, 80, 50, player)
	hud["center"].text = "BUSTED\nScore %d  Cash $%d" % [score, cash]
	hud["center"].visible = true
	# Gate 0: no save/menu flow yet (that was localStorage in the HTML).
	# Scene reloads after the bust screen, fresh run.
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()

# ---------- Per-frame ----------
func _process(_delta: float) -> void:
	if state != "PLAYING" or player == null:
		return
	if wanted_level > 0.0:
		frames_since_crime += 1
		var decay := int(wanted_cfg.get("decay_frames_without_crime", 600))
		if frames_since_crime > decay:
			frames_since_crime = 0
			wanted_level = maxf(0.0, wanted_level - 1.0)
			refresh_hud()
		var caps: Array = wanted_cfg.get("max_active_enemies_by_star", [0, 3, 6, 10, 15, 22, 30])
		var stars := floori(wanted_level)
		var cap := int(caps[mini(stars, caps.size() - 1)])
		var types: Array = wanted_cfg.get("spawn_type_by_star_index_0_based", ["cop"])
		if get_tree().get_nodes_in_group("enemies").size() < cap and randf() < 0.02 + stars * 0.005:
			_spawn_enemy(str(types[mini(stars - 1 if stars > 0 else 0, types.size() - 1)]))
	if combo_frames > 0:
		combo_frames -= 1
		if combo_frames <= 0:
			combo_count = 0
	for child in get_children():
		if child is Pickup and not child.collected and player.global_position.distance_to(child.global_position) < 25.0:
			child.collected = true
			if child.kind == "health":
				player.hp = minf(player.max_hp, player.hp + 30.0)
			else:
				cash += 15
			child.queue_free()
			refresh_hud()
	# camera follow + zoom + shake, as in the HTML
	var target := player.global_position
	camera.global_position = camera.global_position.lerp(target, 0.12)
	if shake > 0.0:
		camera.offset = Vector2(randf() - 0.5, randf() - 0.5) * shake
		shake *= 0.88
		if shake < 0.5:
			shake = 0.0
			camera.offset = Vector2.ZERO
	var target_zoom := 1.0
	if player.in_car:
		target_zoom = 0.65
	elif wanted_level >= 4.0:
		target_zoom = 0.8
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 0.05)
	if randf() < 0.1:
		refresh_hud()

func _spawn_enemy(kind: String) -> void:
	var e := Enemy.new()
	e.setup(kind, enemy_stats.get(kind, {}))
	var ang := randf() * TAU
	var d := 500.0 + randf() * 400.0
	var pos := player.global_position + Vector2(cos(ang), sin(ang)) * d
	pos.x = clamp(pos.x, 100, World.SIZE - 100)
	pos.y = clamp(pos.y, 100, World.SIZE - 100)
	e.global_position = pos
	e.world = world
	e.main = self
	add_child(e)
