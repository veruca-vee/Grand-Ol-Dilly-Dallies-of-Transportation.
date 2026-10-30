class_name Tank3D
extends CharacterBody3D

# The tank from data/enemies_world_wanted.json (hp 300, dmg 25,
# fire rate 45 frames, range 500, speed 1.5) as a slow armored box
# vehicle — the 2D code drew it as a rectangle with a turret; this is
# the same idea in boxes. Same interface as Enemy3D (kind / dead /
# take_damage / gun_position) so gate3d_main treats both alike.
# Range / 15 and speed * (5.0/3.8): same adaptations as Enemy3D.

var kind: String = "tank"
var hp: float = 300.0
var max_hp: float = 300.0
var speed: float = 2.0
var dmg: float = 25.0
var fire_rate_frames: float = 45.0
var range_: float = 33.3  # 500 / 15
var bullet_life_frames: float = 27.8  # 500 / 18
var fire_cooldown: float = 0.0
var dead: bool = false
var gravity: float = 22.0
var main: Node = null

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)

func setup(_kind: String, stats: Dictionary) -> void:
	hp = float(stats.get("hp", 300))
	max_hp = hp
	speed = float(stats.get("speed", 1.5)) * (5.0 / 3.8)
	dmg = float(stats.get("dmg", 25))
	fire_rate_frames = float(stats.get("fire_rate_frames", 45))
	range_ = float(stats.get("range", 500)) / 15.0
	bullet_life_frames = float(stats.get("range", 500)) / 18.0

func _ready() -> void:
	add_to_group("enemies3d")
	collision_layer = 2
	collision_mask = 7
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.8, 5.2)
	shape.shape = box
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	var armor := Color(0.45, 0.47, 0.45)
	_box(Vector3(3.2, 1.1, 5.2), Vector3(0, 0.75, 0), armor)
	_box(Vector3(1.6, 0.7, 2.2), Vector3(0, 1.65, 0.2), armor.darkened(0.15))
	_box(Vector3(0.25, 0.25, 2.4), Vector3(0, 1.65, -1.9), Color(0.15, 0.15, 0.15))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.5, 0.7, 5.3), Vector3(sx * 1.5, 0.35, 0), Color(0.1, 0.1, 0.1))

func gun_position() -> Vector3:
	return global_position + Vector3(0, 1.65, 0) + (-global_transform.basis.z) * 3.0

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if hp <= 0.0 and main != null:
		main.kill_enemy(self)

func _physics_process(delta: float) -> void:
	if dead or main == null or main.player == null:
		return
	var player_pos: Vector3 = main.player.global_position
	var to_player := player_pos - global_position
	to_player.y = 0.0
	var d := to_player.length()
	if d > 0.05:
		var target_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 1.5)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if d > range_ * 0.6:
		var forward := -global_transform.basis.z
		velocity.x = forward.x * speed
		velocity.z = forward.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if fire_cooldown > 0.0:
		fire_cooldown -= 1.0
	if d < range_ and fire_cooldown <= 0.0 and main.state == "PLAYING":
		main.enemy_shoot_3d(self)
		fire_cooldown = fire_rate_frames
	global_position.x = clamp(global_position.x, -112, 112)
	global_position.z = clamp(global_position.z, -112, 112)
