class_name Enemy3D
extends FlapRig

# Cop / SWAT / military in 3D. Stats come from
# data/enemies_world_wanted.json via setup(), exactly as scripts/enemy.gd.
# Adaptations (labelled in gate3d/README.md): ranges are 2D units / 15
# (the 3D world is 240 across, the 2D world 3600); speeds are scaled
# by the player-speed ratio 5.0 / 3.8 so the chase feel matches the 2D
# ratios; bullet life stays in source frames (range / 18).

var kind: String = "cop"
var hp: float = 40.0
var max_hp: float = 40.0
var speed: float = 2.4
var dmg: float = 8.0
var fire_rate_frames: float = 22.0
var range_: float = 23.3  # 350 / 15
var bullet_life_frames: float = 19.4  # 350 / 18
var fire_cooldown: float = 0.0
var dead: bool = false
var talk_timer: float = 0.0
var gravity: float = 22.0
var main: Node = null

func setup(kind_: String, stats: Dictionary) -> void:
	kind = kind_
	hp = float(stats.get("hp", 40))
	max_hp = hp
	speed = float(stats.get("speed", 1.8)) * (5.0 / 3.8)
	dmg = float(stats.get("dmg", 8))
	fire_rate_frames = float(stats.get("fire_rate_frames", 22))
	range_ = float(stats.get("range", 350)) / 15.0
	bullet_life_frames = float(stats.get("range", 350)) / 18.0
	shirt_color = Color(stats.get("color", "#4488ff"))
	# Gate 3D-2 dressing: cops and military wear caps (see
	# core/flap_rig); SWAT's near-black kit reads as-is.
	if kind == "cop":
		cap_enabled = true
		cap_color = Color(0.08, 0.12, 0.32)
	elif kind == "military":
		cap_enabled = true
		cap_color = Color(0.22, 0.32, 0.16)

func _ready() -> void:
	super._ready()
	add_to_group("enemies3d")
	# greybox gun, dark with the 2D red tip colour family
	_box(Vector3(0.09, 0.09, 0.5), Vector3(0.3, 1.12, -0.35), Color(0.12, 0.12, 0.12), self)

func gun_position() -> Vector3:
	return global_position + Vector3(0, 1.25, 0) + (-global_transform.basis.z) * 0.45

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
		face_direction(to_player)
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	if d > range_ * 0.6:
		var dir := to_player.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()
	if fire_cooldown > 0.0:
		fire_cooldown -= 1.0
	if talk_timer > 0.0:
		talk_timer -= delta
	is_talking = talk_timer > 0.0  # firing enemies flap, Canadian-style
	if d < range_ and fire_cooldown <= 0.0 and main.state == "PLAYING":
		is_talking = true
		talk_timer = 0.12
		main.enemy_shoot_3d(self)
		fire_cooldown = fire_rate_frames
	global_position.x = clamp(global_position.x, -115, 115)
	global_position.z = clamp(global_position.z, -115, 115)
	tick_flap(delta)
