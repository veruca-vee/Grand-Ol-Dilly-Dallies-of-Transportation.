class_name FlapRig
extends CharacterBody3D

# ENGINE CORE — the hinge-head character rig every person in a game
# on this engine is built from (body builder, flap tick, facing).
# Extracted from gate3d/flappy_person3d.gd in the Engine Core gate
# (step 9); class renamed FlappyPerson3D -> FlapRig, body and hinge
# math unchanged.
#
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
# Gate 3D-2 dressing: an optional cap that rides the upper head (it
# is glued to the top half, so it flaps with the flap — correct and
# funny). Head proportions and the hinge are NOT touched.
var cap_enabled: bool = false
var cap_color: Color = Color(0.10, 0.14, 0.35)

var is_talking: bool = false
var flap_time: float = 0.0
var flap_amount: float = 0.0  # 0..1, read by tests / other systems
var upper_pivot: Node3D = null
# Detail Pass 1: walk-cycle limb pivots. Legs/arms hang from these
# so they can swing; the head/hinge code below is NOT touched by
# the walk cycle. walk_* state is read by tests / other systems.
var leg_pivot_l: Node3D = null
var leg_pivot_r: Node3D = null
var arm_pivot_l: Node3D = null
var arm_pivot_r: Node3D = null
var walk_phase: float = 0.0  # radians; advances with distance travelled
var walk_swing: float = 0.0  # current leg swing magnitude (radians)
var walk_blend: float = 0.0  # 0..1 ease in/out so limbs settle at rest
var walk_stride: float = 2.4  # phase radians per world unit travelled
var walk_leg_amp: float = 0.55
var walk_arm_amp: float = 0.38
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
	# legs / torso / arms — flat boxes, PS2-era low-poly by
	# construction. Detail Pass 1: legs and arms hang from hip /
	# shoulder pivots so the walk cycle can swing them; box sizes
	# are unchanged and the pivot offsets keep the limb spans the
	# same as the old static boxes (legs ~0.02-0.52, arms
	# 0.545-1.095).
	leg_pivot_l = _limb(Vector3(-0.11, 0.52, 0), Vector3(0.16, 0.5, 0.18), Vector3(0, -0.25, 0), pants_color)
	leg_pivot_r = _limb(Vector3(0.11, 0.52, 0), Vector3(0.16, 0.5, 0.18), Vector3(0, -0.25, 0), pants_color)
	_box(Vector3(0.5, 0.62, 0.26), Vector3(0, 0.81, 0), shirt_color, self)
	arm_pivot_l = _limb(Vector3(-0.33, 1.095, 0), Vector3(0.13, 0.55, 0.15), Vector3(0, -0.275, 0), shirt_color.darkened(0.1))
	arm_pivot_r = _limb(Vector3(0.33, 1.095, 0), Vector3(0.13, 0.55, 0.15), Vector3(0, -0.275, 0), shirt_color.darkened(0.1))
	# lower head / jaw (below the split)
	_box(Vector3(0.42, 0.15, 0.38), Vector3(0, MOUTH_Y - 0.075, 0), skin_color.darkened(0.05), self)
	# upper head on its hinge pivot at the mouth line, back of the head
	upper_pivot = Node3D.new()
	upper_pivot.position = Vector3(0, MOUTH_Y, 0.19)
	add_child(upper_pivot)
	_box(Vector3(0.44, 0.22, 0.40), Vector3(0, 0.11, -0.19), skin_color, upper_pivot)
	if cap_enabled:
		# cap crown + brim, children of the upper head so they ride it
		_box(Vector3(0.47, 0.09, 0.43), Vector3(0, 0.265, -0.19), cap_color, upper_pivot)
		_box(Vector3(0.42, 0.03, 0.20), Vector3(0, 0.225, -0.47), cap_color.darkened(0.15), upper_pivot)
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

# One swinging limb: a pivot at the joint, the box hanging below it.
func _limb(joint: Vector3, box_size: Vector3, box_offset: Vector3, color: Color) -> Node3D:
	var p := Node3D.new()
	p.position = joint
	add_child(p)
	_box(box_size, box_offset, color, p)
	return p

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

# Detail Pass 1 walk cycle: phase advances with distance
# travelled (planar speed x stride), legs swing in anti-phase,
# arms counter-swing, and the blend eases out when the body stops
# so the limbs settle to neutral instead of freezing mid-stride.
# Called by subclasses after move_and_slide(), beside tick_flap.
func tick_walk(delta: float) -> void:
	if leg_pivot_l == null:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.05:
		walk_phase += planar * delta * walk_stride
		walk_blend = move_toward(walk_blend, 1.0, delta * 8.0)
	else:
		walk_blend = move_toward(walk_blend, 0.0, delta * 8.0)
	var s := sin(walk_phase)
	leg_pivot_l.rotation.x = s * walk_leg_amp * walk_blend
	leg_pivot_r.rotation.x = -s * walk_leg_amp * walk_blend
	arm_pivot_l.rotation.x = -s * walk_arm_amp * walk_blend
	arm_pivot_r.rotation.x = s * walk_arm_amp * walk_blend
	walk_swing = absf(s) * walk_leg_amp * walk_blend

func face_direction(dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var target := global_position + Vector3(dir.x, 0, dir.z)
	if target.distance_to(global_position) > 0.01:
		look_at(target, Vector3.UP)
