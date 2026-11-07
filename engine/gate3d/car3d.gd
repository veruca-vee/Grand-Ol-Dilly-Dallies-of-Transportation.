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
# Per-model build config (GETAWAY1: the fleet is no longer
# Kenney-only). Fields: file, scale (visual -> the unchanged
# 4.0 collision length), flip (kit nose is +Z, physics forward
# is -Z; the Kimi sedan's nose is already -Z), spin_r (the
# effective wheel radius at scale — the honest divisor for
# spin, angle = distance / r), wheel_mode ("kit": wheel nodes
# named wheel-front-*/wheel-back-* driven by euler writes;
# "axle": Wheel_FL/FR/RL/RR nodes whose baked rotY basis is
# composed with yaw + axle spin instead).
# Kenney values are the pre-GETAWAY1 constants, unchanged:
# kit sedan 2.55 long -> x1.55 (ASSET_RESEARCH §2); kit wheel
# radius 0.30 native x 1.55 = 0.465.
const MODEL_CFG := {
	"getaway_sedan": {
		"file": "res://assets/kimi_getaway/Felony_City_Getaway_Sedan.glb",
		"scale": 0.8406, "flip": false, "spin_r": 0.3362,
		"wheel_mode": "axle",
	},
}
# The kit scale as a public constant: gate3d_main's service-
# vehicle dressing scales kit GLBs by it directly.
const MODEL_SCALE := 1.55
const KIT_CFG := {"scale": MODEL_SCALE, "flip": true, "spin_r": 0.465, "wheel_mode": "kit"}

func _cfg() -> Dictionary:
	if MODEL_CFG.has(model_name):
		return MODEL_CFG[model_name]
	var c := KIT_CFG.duplicate()
	c["file"] = MODEL_DIR + model_name + ".glb"
	return c

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

# Instance the model and wire its parts, per _cfg(). Kit
# models: nose is +Z (probe, ASSETS1 gate: wheel-front-* sit
# at positive Z in Godot space) while this car's forward is
# -Z, so the model root turns PI; wheel centres sit at native
# y 0.30 with radius 0.30, so at the kit scale the tyres touch
# y=0 exactly at the car origin. The getaway sedan needs no
# flip (nose already -Z, GETAWAY1 probe) and its wheel nodes
# carry a baked rotY basis, stored as "home" for the axle-mode
# composition in _physics_process.
func _build_model() -> void:
	var cfg := _cfg()
	var ps: PackedScene = load(str(cfg["file"]))
	if ps == null:
		return
	model_root = ps.instantiate() as Node3D
	model_root.scale = Vector3.ONE * float(cfg["scale"])
	if bool(cfg["flip"]):
		model_root.rotation.y = PI
	add_child(model_root)
	var axle := str(cfg["wheel_mode"]) == "axle"
	var stack: Array = [model_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var lname := n.name.to_lower()
			if axle and (lname == "wheel_fl" or lname == "wheel_fr" or lname == "wheel_rl" or lname == "wheel_rr"):
				glb_wheels.append({"node": n, "front": lname == "wheel_fl" or lname == "wheel_fr", "home": (n as Node3D).transform.basis})
			elif not axle and (lname.begins_with("wheel-front-") or lname.begins_with("wheel-back-")):
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
		spin_angle -= speed * delta / float(_cfg()["spin_r"])
	# Kit wheels: the model root is turned PI, so a wheel's
	# local rotation.x runs against the car's frame:
	# -spin_angle is what rolls the tyre the way the car
	# travels (probe + axis math in the gate README). Yaw keeps
	# steer_visual's sign — about the shared Y axis the flip
	# adds PI, it does not negate.
	# Axle wheels (getaway sedan): the node's baked basis is
	# composed as yaw * home * axle-spin. The tyre disc lies in
	# the node's local XY plane with its axle along local Z,
	# so spinning about local Z rolls it; home maps that axle
	# onto the car's lateral axis, and the front pair's yaw is
	# applied in car space first. Spin direction matches the
	# kit path by construction (GETAWAY1_SPEC S4).
	for went in glb_wheels:
		var wn: Node3D = went["node"]
		if went.has("home"):
			var yaw := steer_visual if bool(went["front"]) else 0.0
			wn.basis = Basis(Vector3.UP, yaw) * (went["home"] as Basis) * Basis(Vector3(0, 0, 1), spin_angle)
		else:
			wn.rotation.x = -spin_angle
			wn.rotation.y = steer_visual if bool(went["front"]) else 0.0
	var forward := -global_transform.basis.z
	velocity.x = forward.x * speed
	velocity.z = forward.z * speed
	move_and_slide()
