extends Node3D

# G.O.D.O.T — Gate 3D-0
# PS2-era greybox: third-person, low-poly primitives only, distance fog
# + capped camera far plane ("San Andreas, like when it came out" =
# short draw distance and fog doing the hiding, not detail).
# Systems (weapons/wanted/economy) still live in the Gate 0 prototype
# and data/*.json; this gate proves: world, third-person movement,
# enter/drive a car, and the Canadian flap-head in 3D.

var player: Player3D = null
var cars: Array[Car3D] = []
var camera: Camera3D = null
var hud_label: Label = null
var cam_yaw: float = 0.0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _ready() -> void:
	_setup_environment()
	_build_city()
	player = Player3D.new()
	player.position = Vector3(0, 0.2, 8)
	add_child(player)
	var car_colors := [Color(0.75, 0.25, 0.25), Color(0.25, 0.35, 0.8), Color(0.3, 0.65, 0.3), Color(0.8, 0.7, 0.2)]
	var car_spots := [Vector3(4, 0.2, -2), Vector3(-14, 0.2, -30), Vector3(20, 0.2, 24), Vector3(-30, 0.2, 18)]
	for i in range(car_spots.size()):
		var car := Car3D.new()
		car.car_color = car_colors[i]
		car.position = car_spots[i]
		car.rotation.y = randf() * TAU
		add_child(car)
		cars.append(car)
	for i in range(8):
		var ped := Ped3D.new()
		ped.position = Vector3((randf() - 0.5) * 90, 0.2, (randf() - 0.5) * 90)
		add_child(ped)
	camera = Camera3D.new()
	camera.far = 160.0  # PS2 draw distance: short on purpose
	add_child(camera)
	_build_hud()

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
	add_child(body)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_label = Label.new()
	hud_label.position = Vector2(10, 8)
	hud_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud_label)
	_update_hud()

func _update_hud() -> void:
	var state := "on foot"
	if player != null and player.driving != null:
		state = "driving"
	hud_label.text = "G.O.D.O.T — Gate 3D-0 (%s)\nWASD move/drive · E enter/exit car · hold T to talk (watch the head)" % state

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if player.driving != null:
			_exit_car()
		else:
			_try_enter_car()

func _try_enter_car() -> void:
	var best: Car3D = null
	var best_d := 4.0
	for car in cars:
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
		_update_hud()

func _exit_car() -> void:
	var car := player.driving
	car.driven = false
	player.driving = null
	player.global_position = car.global_position + car.global_transform.basis.x * 2.2 + Vector3(0, 0.3, 0)
	player.visible = true
	player.set_physics_process(true)
	if player.body_shape != null:
		player.body_shape.disabled = false
	_update_hud()

func _process(delta: float) -> void:
	if player == null or camera == null:
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
