class_name Player3D
extends FlappyPerson3D

# Gate 3D-1: the player now carries the Gate 0 combat state — hp,
# weapon selection, fire cooldown. Firing itself (input, camera-ray
# hitscan, drive-by) is driven by gate3d_main, which also ticks
# fire_cooldown EVERY physics frame in both modes — the HTML bug was
# an in-car cooldown that never ticked, so drive-by fired once.

var walk_speed: float = 5.0
var gravity: float = 22.0
var driving: Car3D = null

var hp: float = 100.0  # data: player.base_hp
var max_hp: float = 100.0
var weapon_index: int = 1  # PISTOL, as in the HTML / Gate 0
var fire_cooldown: float = 0.0  # in 60 Hz frames, as the source data
var dead: bool = false
var fire_flap_time: float = 0.0
var main: Node = null
var gun: MeshInstance3D = null

func _init() -> void:
	shirt_color = Color(0.1, 0.6, 0.15)  # set before _build_body runs

func _ready() -> void:
	super._ready()
	add_to_group("player3d")
	gun = _box(Vector3(0.09, 0.09, 0.55), Vector3(0.3, 1.12, -0.35), Color(0.15, 0.15, 0.15), self)
	gun.visible = false

func refresh_gun(weapon: Dictionary) -> void:
	if gun == null:
		return
	if weapon.get("melee", false):
		gun.visible = false
		return
	gun.visible = true
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(weapon.get("color", "#ffdd88"))
	m.roughness = 0.7
	gun.material_override = m

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if main != null:
		main.on_player_damaged()
	if hp <= 0.0 and main != null:
		main.on_player_death()

func _physics_process(delta: float) -> void:
	if dead:
		return
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
	if fire_flap_time > 0.0:
		fire_flap_time -= delta
	is_talking = Input.is_key_pressed(KEY_T) or fire_flap_time > 0.0
	move_and_slide()
	tick_flap(delta)
