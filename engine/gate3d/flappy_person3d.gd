class_name FlappyPerson3D
extends CharacterBody3D

# The Canadian look in 3D — the "how" (Vee said yes to the look on
# 2026-10-29, how was left open; this is the assistant's design):
#
# The head is TWO boxes split at the mouth line (y = MOUTH_Y).
#   - Lower head / jaw: static, part of the body.
#   - Upper head: a child of `upper_pivot`, a Node3D placed exactly at
#     the mouth line, at the BACK of the head (+Z; characters face -Z).
#     Rotating upper_pivot.rotation.x lifts the front of the upper
#     head up and back — the South-Park-Canadian flap, as a hinge.
#   - The beady eyes are two small black spheres ON the upper head,
#     close-set, so they ride the flap.
# While `is_talking`, the hinge oscillates; otherwise it settles shut.

const MOUTH_Y := 1.47

var shirt_color: Color = Color(0.25, 0.45, 0.8)
var pants_color: Color = Color(0.2, 0.2, 0.25)
var skin_color: Color = Color(0.96, 0.80, 0.64)

var is_talking: bool = false
var flap_time: float = 0.0
var flap_amount: float = 0.0  # 0..1, read by tests / other systems
var upper_pivot: Node3D = null
var body_shape: CollisionShape3D = null
var built: bool = false

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi

func _build_body() -> void:
	if built:
		return
	built = true
	body_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	body_shape.shape = cap
	body_shape.position = Vector3(0, 0.85, 0)
	add_child(body_shape)
	# legs / torso / arms — flat boxes, PS2-era low-poly by construction
	_box(Vector3(0.16, 0.5, 0.18), Vector3(-0.11, 0.25, 0), pants_color, self)
	_box(Vector3(0.16, 0.5, 0.18), Vector3(0.11, 0.25, 0), pants_color, self)
	_box(Vector3(0.5, 0.62, 0.26), Vector3(0, 0.81, 0), shirt_color, self)
	_box(Vector3(0.13, 0.55, 0.15), Vector3(-0.33, 0.82, 0), shirt_color.darkened(0.1), self)
	_box(Vector3(0.13, 0.55, 0.15), Vector3(0.33, 0.82, 0), shirt_color.darkened(0.1), self)
	# lower head / jaw (below the split)
	_box(Vector3(0.42, 0.15, 0.38), Vector3(0, MOUTH_Y - 0.075, 0), skin_color.darkened(0.05), self)
	# upper head on its hinge pivot at the mouth line, back of the head
	upper_pivot = Node3D.new()
	upper_pivot.position = Vector3(0, MOUTH_Y, 0.19)
	add_child(upper_pivot)
	_box(Vector3(0.44, 0.22, 0.40), Vector3(0, 0.11, -0.19), skin_color, upper_pivot)
	# beady eyes: small, close-set, black — children of the upper head
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.028
		sm.height = 0.056
		sm.radial_segments = 8
		sm.rings = 4
		eye.mesh = sm
		eye.position = Vector3(sx * 0.055, 0.13, -0.40)
		eye.material_override = _mat(Color.BLACK)
		upper_pivot.add_child(eye)

func _ready() -> void:
	# Gate 3D-1 collision scheme: world/buildings = layer 1,
	# characters = layer 2, cars = layer 4; everyone collides with all.
	collision_layer = 2
	collision_mask = 7
	_build_body()

func tick_flap(delta: float) -> void:
	if is_talking:
		flap_time += delta * 13.0
		flap_amount = 0.5 + 0.5 * sin(flap_time)
	else:
		flap_amount = move_toward(flap_amount, 0.0, delta * 7.0)
	if upper_pivot != null:
		# max opening ~0.55 rad at the hinge — the whole top of the head
		upper_pivot.rotation.x = flap_amount * 0.55

func face_direction(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var target := global_position + Vector3(dir.x, 0, dir.z)
	if target.distance_to(global_position) > 0.01:
		look_at(target, Vector3.UP)
