class_name Car3D
extends CharacterBody3D

# Arcade car, PS2-era proportions built from boxes + cylinder wheels.
# Driven only while `driven` (set by gate3d_main on enter/exit).

var car_color: Color = Color(0.75, 0.25, 0.25)
var speed: float = 0.0
var max_speed: float = 24.0
var accel: float = 14.0
var driven: bool = false
var gravity: float = 22.0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.1, 4.0)
	shape.shape = box
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)
	_box(Vector3(1.8, 0.5, 4.0), Vector3(0, 0.55, 0), car_color)
	_box(Vector3(1.6, 0.5, 2.0), Vector3(0, 1.05, 0.15), car_color.darkened(0.15))
	_box(Vector3(1.62, 0.3, 0.9), Vector3(0, 1.05, -0.35), Color(0.1, 0.12, 0.16))  # windshield block
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.36
			cm.bottom_radius = 0.36
			cm.height = 0.25
			cm.radial_segments = 10
			wheel.mesh = cm
			wheel.rotation.z = PI / 2.0  # axle along X
			wheel.position = Vector3(sx * 0.85, 0.36, sz * 1.3)
			wheel.material_override = _mat(Color(0.05, 0.05, 0.05))
			add_child(wheel)
	# headlights
	_box(Vector3(0.3, 0.12, 0.05), Vector3(-0.6, 0.62, -2.0), Color(1, 0.95, 0.7))
	_box(Vector3(0.3, 0.12, 0.05), Vector3(0.6, 0.62, -2.0), Color(1, 0.95, 0.7))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if driven:
		var throttle := 0.0
		var steer := 0.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			throttle += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			throttle -= 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			steer += 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			steer -= 1.0
		speed += throttle * accel * delta
		speed = clamp(speed, -max_speed * 0.4, max_speed)
		if throttle == 0.0:
			speed = move_toward(speed, 0.0, 10.0 * delta)
		if abs(speed) > 0.3:
			rotation.y += steer * 1.6 * delta * sign(speed)
	else:
		speed = move_toward(speed, 0.0, 20.0 * delta)
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
