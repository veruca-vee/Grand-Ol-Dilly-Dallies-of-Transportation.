class_name Car3D
extends CharacterBody3D

# Arcade car, PS2-era proportions built from boxes + cylinder wheels.
# Driven only while `driven` (set by gate3d_main on enter/exit).
# Gate 3D-1: cars have hp (data: car.hp = 100) and can be destroyed;
# destruction, economy and wanted live in gate3d_main.kill_car.

var car_color: Color = Color(0.75, 0.25, 0.25)
var speed: float = 0.0
var max_speed: float = 24.0
var accel: float = 14.0
var driven: bool = false
var gravity: float = 22.0

var hp: float = 100.0  # data: car.hp
var max_hp: float = 100.0
var dead: bool = false
var main: Node = null
var body_meshes: Array = []
var front_pivots: Array[Node3D] = []  # Gate 3D-2: front wheels steer
var wheel_spins: Array[Node3D] = []   # all wheels roll
var spin_angle: float = 0.0
var steer_visual: float = 0.0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.14, 0.20)
	m.roughness = 0.25
	m.metallic = 0.35
	return m

func _light_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.6
	return m

func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _ready() -> void:
	add_to_group("cars3d")
	collision_layer = 4
	collision_mask = 7
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.1, 4.0)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)
	# Gate 3D-2 dressed body: paint lower body + glass cabin + paint
	# roof panel + bumpers, instead of Gate 3D-0's plain boxes.
	body_meshes.append(_box(Vector3(1.8, 0.5, 4.0), Vector3(0, 0.55, 0), car_color))
	_box(Vector3(1.84, 0.16, 4.04), Vector3(0, 0.30, 0), car_color.darkened(0.30))  # lower trim
	var cabin := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(1.58, 0.48, 2.0)
	cabin.mesh = cbm
	cabin.position = Vector3(0, 1.04, 0.15)
	cabin.material_override = _glass_mat()
	add_child(cabin)
	body_meshes.append(_box(Vector3(1.64, 0.09, 2.06), Vector3(0, 1.32, 0.15), car_color.darkened(0.08)))  # roof
	_box(Vector3(1.86, 0.18, 0.25), Vector3(0, 0.42, -2.02), Color(0.12, 0.12, 0.13))  # bumpers
	_box(Vector3(1.86, 0.18, 0.25), Vector3(0, 0.42, 2.02), Color(0.12, 0.12, 0.13))
	# wheels: steer pivot -> spin node -> tyre + hubcap (front = -Z)
	var tyre_mat := _mat(Color(0.05, 0.05, 0.05))
	var hub_mat := _mat(Color(0.55, 0.56, 0.60))
	hub_mat.metallic = 0.4
	hub_mat.roughness = 0.4
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sx * 0.85, 0.36, sz * 1.3)
			add_child(pivot)
			var spin := Node3D.new()
			pivot.add_child(spin)
			var wheel := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.36
			cm.bottom_radius = 0.36
			cm.height = 0.25
			cm.radial_segments = 10
			wheel.mesh = cm
			wheel.rotation.z = PI / 2.0  # axle along X
			wheel.material_override = tyre_mat
			spin.add_child(wheel)
			var hub := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.17
			hm.bottom_radius = 0.17
			hm.height = 0.27
			hm.radial_segments = 8
			hub.mesh = hm
			hub.rotation.z = PI / 2.0
			hub.material_override = hub_mat
			spin.add_child(hub)
			wheel_spins.append(spin)
			if sz < 0.0:
				front_pivots.append(pivot)
	# headlights (front, -Z) + taillights: emissive, no real lights
	var hl := _light_mat(Color(1.0, 0.95, 0.70))
	var tl := _light_mat(Color(1.0, 0.15, 0.15))
	for sx in [-1.0, 1.0]:
		var h := _box(Vector3(0.32, 0.12, 0.06), Vector3(sx * 0.58, 0.64, -2.03), Color.WHITE)
		h.material_override = hl
		var t := _box(Vector3(0.32, 0.12, 0.06), Vector3(sx * 0.58, 0.64, 2.03), Color.WHITE)
		t.material_override = tl

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if hp <= 0.0 and main != null:
		main.kill_car(self)

func set_dead_visual() -> void:
	for m in body_meshes:
		m.material_override = _mat(Color(0.1, 0.1, 0.1))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if driven and not dead:
		# input reading is ENGINE CORE (core/controller.gd)
		var drive_input := Controller.read_drive_input()
		var throttle := drive_input.y
		var steer := drive_input.x
		speed += throttle * accel * delta
		speed = clamp(speed, -max_speed * 0.4, max_speed)
		if throttle == 0.0:
			speed = move_toward(speed, 0.0, 10.0 * delta)
		if abs(speed) > 0.3:
			rotation.y += steer * 1.6 * delta * sign(speed)
		# Gate 3D-2: front wheels visibly steer, all wheels roll
		steer_visual = move_toward(steer_visual, steer * 0.45, delta * 3.0)
	else:
		speed = move_toward(speed, 0.0, 20.0 * delta)
		steer_visual = move_toward(steer_visual, 0.0, delta * 3.0)
	for p in front_pivots:
		p.rotation.y = steer_visual
	if abs(speed) > 0.01:
		spin_angle -= speed * delta / 0.36
		for s in wheel_spins:
			s.rotation.x = spin_angle
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
