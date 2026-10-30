class_name Player3D
extends FlappyPerson3D

var walk_speed: float = 5.0
var gravity: float = 22.0
var driving: Car3D = null

func _init() -> void:
	shirt_color = Color(0.1, 0.6, 0.15)  # set before _build_body runs

func _ready() -> void:
	super._ready()
	add_to_group("player3d")

func _physics_process(delta: float) -> void:
	if driving != null:
		return  # main syncs our position to the car
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	dir = dir.normalized()
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	velocity.x = dir.x * walk_speed
	velocity.z = dir.z * walk_speed
	if dir.length() > 0.05:
		face_direction(dir)
	is_talking = Input.is_key_pressed(KEY_T)  # hold T: talk (flap test)
	move_and_slide()
	tick_flap(delta)
