class_name Bullet3D
extends Node3D

# Projectile for enemy fire and the player's ROCKET (all other player
# weapons are hitscan from the camera ray — see gate3d_main).
# Mirrors scripts/bullet.gd: per-frame movement, life measured in
# frames of range (range / speed-per-frame in the source data), and
# main resolves every hit — the bullet itself only checks buildings.

var vel: Vector3 = Vector3.ZERO  # units per second
var damage: float = 10.0
var is_player: bool = true
var is_rocket: bool = false
var life_frames: float = 20.0
var shooter: Object = null
var main: Node = null  # gate3d_main; resolves hits

func setup(pos: Vector3, velocity: Vector3, dmg: float, player_owned: bool, rocket: bool, life: float, shooter_: Object, game_main: Node, color: Color) -> void:
	global_position = pos
	vel = velocity
	damage = dmg
	is_player = player_owned
	is_rocket = rocket
	life_frames = life
	shooter = shooter_
	main = game_main
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22 if rocket else 0.09
	sm.height = sm.radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	add_child(mi)

func _physics_process(delta: float) -> void:
	if main == null:
		return
	var from := global_position
	var to := from + vel * delta
	# Buildings / ground are collision layer 1. A rocket explodes on
	# the building (2D rule: explode radius 100 at full damage);
	# anything else just dies, as in the 2D resolve_bullet.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if is_rocket:
			main.explode_3d(hit.position, 100.0, damage, self)
		queue_free()
		return
	global_position = to
	main.resolve_bullet3d(self)
	if is_queued_for_deletion():
		return
	life_frames -= 1.0
	if life_frames <= 0.0:
		queue_free()
