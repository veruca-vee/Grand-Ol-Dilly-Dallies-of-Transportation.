class_name Ped3D
extends FlappyPerson3D

# Gate 3D-1: peds keep the Gate 3D-0 wander + random talk, and gain
# the Gate 0 flee rule (scripts/ped.gd): within flee radius of the
# player while wanted >= 1 or the player carries more than fists,
# run directly away at flee speed, flapping the whole time.
# Distances/speeds adapted like the enemies: radius 150 / 15 = 10,
# speeds scaled by 5.0 / 3.8 (2D walk 0.6-1.3 -> 0.8-1.7, flee 2.5 -> 3.3).
# Like the 2D code, a ped has no hp: any bullet hit kills (main's call).

var walk_speed: float = 1.2
var gravity: float = 22.0
var target_dir: Vector3 = Vector3.FORWARD
var wander_timer: float = 0.0
var talk_timer: float = 0.0
var fleeing: bool = false
var dead: bool = false
var death_timer: float = -1.0
var main: Node = null

func _init() -> void:
	shirt_color = [Color(0.8, 0.3, 0.6), Color(0.4, 0.5, 0.8), Color(0.8, 0.6, 0.3), Color(0.4, 0.8, 0.8), Color(0.55, 0.35, 0.65), Color(0.7, 0.45, 0.3)][randi() % 6]
	pants_color = [Color(0.16, 0.18, 0.30), Color(0.10, 0.10, 0.12), Color(0.30, 0.22, 0.16), Color(0.25, 0.25, 0.28), Color(0.35, 0.30, 0.22)][randi() % 5]

func _ready() -> void:
	super._ready()
	add_to_group("peds3d")

func die() -> void:
	# Called by gate3d_main.kill_ped (economy/wanted live there).
	# Tip over, sink, free — the 3D stand-in for the 2D queue_free.
	dead = true
	death_timer = 2.0
	if body_shape != null:
		body_shape.disabled = true
	rotation.x = -1.35

func _physics_process(delta: float) -> void:
	if dead:
		if death_timer > 0.0:
			death_timer -= delta
			if death_timer < 0.6:
				global_position.y -= delta * 0.6
			if death_timer <= 0.0:
				queue_free()
		return
	fleeing = false
	if main != null and main.player != null:
		var to_me: Vector3 = global_position - main.player.global_position
		to_me.y = 0.0
		if to_me.length() < 10.0 and (main.wanted_level >= 1.0 or main.player.weapon_index > 0):
			fleeing = true
			target_dir = to_me.normalized()
			walk_speed = 3.3
	if not fleeing:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = 2.0 + randf() * 3.0
			var a := randf() * TAU
			target_dir = Vector3(cos(a), 0, sin(a))
			walk_speed = 0.8 + randf() * 0.9
			# peds randomly start/stop talking — that's when the head flaps
			talk_timer = (1.0 + randf() * 2.0) if randf() < 0.4 else 0.0
	if talk_timer > 0.0:
		talk_timer -= delta
	is_talking = fleeing or talk_timer > 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	velocity.x = target_dir.x * walk_speed
	velocity.z = target_dir.z * walk_speed
	face_direction(target_dir)
	move_and_slide()
	if is_on_wall() and not fleeing:
		target_dir = -target_dir
	global_position.x = clamp(global_position.x, -110, 110)
	global_position.z = clamp(global_position.z, -110, 110)
	tick_flap(delta)
