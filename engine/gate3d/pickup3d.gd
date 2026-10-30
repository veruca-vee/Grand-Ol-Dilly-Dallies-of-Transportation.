class_name Pickup3D
extends Node3D

# 3D version of the Gate 0 pickups. Kinds and effects live in
# gate3d_main (mirroring scripts/main.gd): "cash" +$15 (gold),
# "health" +30 HP (green), "weapon" grants a random weapon (white).
# The 2D code only had cash/health kinds; "weapon" is a Gate 3D-1
# addition, labelled as such in the README.

var kind: String = "cash"  # "cash" | "health" | "weapon"
var collected: bool = false
var spin: float = 0.0
var base_y: float = 0.55

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)

func _ready() -> void:
	add_to_group("pickups3d")
	if kind == "cash":
		_box(Vector3(0.42, 0.42, 0.42), Vector3.ZERO, Color(1.0, 0.78, 0.1))
	elif kind == "health":
		_box(Vector3(0.46, 0.46, 0.46), Vector3.ZERO, Color(0.15, 0.85, 0.25))
		_box(Vector3(0.3, 0.1, 0.48), Vector3(0, 0, 0), Color.WHITE)
		_box(Vector3(0.1, 0.3, 0.48), Vector3(0, 0, 0), Color.WHITE)
	else:  # weapon
		_box(Vector3(0.22, 0.22, 0.85), Vector3.ZERO, Color(0.95, 0.95, 0.95))

func _process(delta: float) -> void:
	spin += delta
	rotation.y = spin * 2.0
	position.y = base_y + sin(spin * 3.0) * 0.08
