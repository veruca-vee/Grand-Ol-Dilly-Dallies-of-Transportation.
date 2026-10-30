class_name Ped3D
extends FlappyPerson3D

var walk_speed: float = 1.6
var gravity: float = 22.0
var target_dir: Vector3 = Vector3.FORWARD
var wander_timer: float = 0.0
var talk_timer: float = 0.0

func _init() -> void:
	shirt_color = [Color(0.8, 0.3, 0.6), Color(0.4, 0.5, 0.8), Color(0.8, 0.6, 0.3), Color(0.4, 0.8, 0.8)][randi() % 4]

func _ready() -> void:
	super._ready()
	add_to_group("peds3d")

func _physics_process(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = 2.0 + randf() * 3.0
		var a := randf() * TAU
		target_dir = Vector3(cos(a), 0, sin(a))
		# peds randomly start/stop talking — that's when the head flaps
		talk_timer = (1.0 + randf() * 2.0) if randf() < 0.4 else 0.0
	if talk_timer > 0.0:
		talk_timer -= delta
	is_talking = talk_timer > 0.0
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	velocity.x = target_dir.x * walk_speed
	velocity.z = target_dir.z * walk_speed
	face_direction(target_dir)
	move_and_slide()
	if is_on_wall():
		target_dir = -target_dir
	global_position.x = clamp(global_position.x, -110, 110)
	global_position.z = clamp(global_position.z, -110, 110)
	tick_flap(delta)
