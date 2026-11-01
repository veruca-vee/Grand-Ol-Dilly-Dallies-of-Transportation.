class_name Car3D
extends CharacterBody3D

# Arcade car. Physics is the Gate 3D-0 arcade body (unchanged);
# the VISUAL is a Kenney Car Kit GLB since Assets Step 1
# (ASSETS1_SPEC, Vee's decision 2026-11-01) — the Detail 1
# procedural box bodies are retired, not bypassed: there is no
# second fleet. Driven only while `driven` (set by
# gate3d_main on enter/exit). Cars have hp (data: car.hp =
# 100) and can be destroyed; destruction, economy and wanted
# live in gate3d_main.kill_car.

# Set by the spawner BEFORE add_child (the old body_style
# seam); _ready builds that model.
var model_name: String = "sedan"
const MODEL_DIR := "res://assets/kenney_car_kit/"
# Research measurement (ASSET_RESEARCH §2): the kit sedan is
# 2.55 long against our 4.0 collision length -> x1.55.
const MODEL_SCALE := 1.55
# Kit wheel radius (0.30 native) at MODEL_SCALE: the honest
# divisor for spin (angle = distance / r).
const WHEEL_R := 0.465

var speed: float = 0.0
var max_speed: float = 24.0
var accel: float = 14.0
var driven: bool = false
var gravity: float = 22.0
# Test seam, mirroring Player3D.move_override: NaN = read the
# real input; set = drive from this vector (x steer, y
# throttle) instead. Gameplay never sets it.
var drive_override := Vector2(NAN, NAN)

var hp: float = 100.0  # data: car.hp
var max_hp: float = 100.0
var dead: bool = false
# Fall fix: edge-bonk launch state, set by gate3d_main via
# apply_bonk. While launch_time runs, Y is ballistic — the
# usual floor clamp would eat the up-pop in one frame. The
# horizontal launch itself is carried by facing + speed,
# which this body's physics already owns.
var launch_time := 0.0

# The bonk response: turn the car to face the reflected
# travel direction, carry the (boosted) reflected speed, and
# pop it upward. gate3d_main decides WHEN (edge contact at
# speed); this decides what the car does with it.
func apply_bonk(reflected_hv: Vector3, pop: float) -> void:
	var d := reflected_hv
	d.y = 0.0
	if d.length() > 0.01:
		var dirn := d.normalized()
		rotation.y = atan2(-dirn.x, -dirn.z)
		speed = d.length()
	velocity.y = pop
	launch_time = 0.5
var main: Node = null
var body_meshes: Array = []
# The kit's own wheel nodes ({node, front}), driven from
# spin_angle / steer_visual by _physics_process.
var glb_wheels: Array = []
var model_root: Node3D = null
var spin_angle: float = 0.0
var steer_visual: float = 0.0

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

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
	_build_model()

# Instance the kit model and wire its parts. The kit's nose
# is +Z (probe, ASSETS1 gate: wheel-front-* sit at positive
# Z in Godot space); this car's forward is -Z, so the model
# root turns PI to face the way the physics drives. Wheel
# centres sit at native y 0.30 with radius 0.30, so at
# MODEL_SCALE the tyres touch y=0 exactly at the car origin.
func _build_model() -> void:
	var ps: PackedScene = load(MODEL_DIR + model_name + ".glb")
	if ps == null:
		return
	model_root = ps.instantiate() as Node3D
	model_root.scale = Vector3.ONE * MODEL_SCALE
	model_root.rotation.y = PI
	add_child(model_root)
	var stack: Array = [model_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var lname := n.name.to_lower()
			if lname.begins_with("wheel-front-") or lname.begins_with("wheel-back-"):
				glb_wheels.append({"node": n, "front": lname.begins_with("wheel-front-")})
			else:
				body_meshes.append(n)
		for ch in n.get_children():
			stack.append(ch)

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if hp <= 0.0 and main != null:
		main.kill_car(self)

func set_dead_visual() -> void:
	var burnt := _mat(Color(0.1, 0.1, 0.1))
	for m in body_meshes:
		m.material_override = burnt

func _physics_process(delta: float) -> void:
	if launch_time > 0.0:
		launch_time -= delta
		velocity.y -= gravity * delta
	elif not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if driven and not dead:
		# input reading is ENGINE CORE (core/controller.gd)
		var drive_input := Controller.read_drive_input()
		if not is_nan(drive_override.x):
			drive_input = drive_override
		var throttle := drive_input.y
		var steer := drive_input.x
		speed += throttle * accel * delta
		speed = clamp(speed, -max_speed * 0.4, max_speed)
		if throttle == 0.0:
			speed = move_toward(speed, 0.0, 10.0 * delta)
		if abs(speed) > 0.3:
			rotation.y += steer * 1.6 * delta * sign(speed)
		# Gate 3D-2 contract, on the kit's wheel nodes now:
		# front wheels visibly steer, all wheels roll.
		steer_visual = move_toward(steer_visual, steer * 0.45, delta * 3.0)
	else:
		speed = move_toward(speed, 0.0, 20.0 * delta)
		steer_visual = move_toward(steer_visual, 0.0, delta * 3.0)
	if abs(speed) > 0.01:
		spin_angle -= speed * delta / WHEEL_R
	# The model root is turned PI, so a wheel's local rotation.x
	# runs against the car's frame: -spin_angle is what rolls
	# the tyre the way the car travels (probe + axis math in
	# the gate README). Yaw keeps steer_visual's sign — about
	# the shared Y axis the flip adds PI, it does not negate.
	for went in glb_wheels:
		var wn: Node3D = went["node"]
		wn.rotation.x = -spin_angle
		wn.rotation.y = steer_visual if bool(went["front"]) else 0.0
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
