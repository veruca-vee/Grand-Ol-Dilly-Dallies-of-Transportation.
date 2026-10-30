class_name Player
extends FlappyPerson

var move_speed: float = 3.8  # HTML base, +0.4 per Sprint Training level (save system is Gate 1)
var hp: float = 100.0
var max_hp: float = 100.0
var weapon_index: int = 1  # PISTOL, as in the HTML
var fire_cooldown: float = 0.0
var dead: bool = false
var in_car: bool = false
var vehicle: Car = null
var world: World = null
var main: Node = null

func _ready() -> void:
	super._ready()
	add_to_group("player")
	body_color = Color(0.05, 0.65, 0.05)

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if main != null:
		main.on_player_damaged()
	if hp <= 0.0 and main != null:
		main.on_player_death()

func try_interact() -> void:
	if dead or main == null:
		return
	if in_car:
		exit_car()
	else:
		var closest: Car = null
		var best := 80.0
		for c in get_tree().get_nodes_in_group("cars"):
			if c.dead:
				continue
			var d := global_position.distance_to(c.global_position)
			if d < best:
				best = d
				closest = c
		if closest != null:
			in_car = true
			vehicle = closest
			closest.driven = true
			closest.ai = false
			visible = false

func exit_car() -> void:
	if vehicle == null:
		return
	vehicle.driven = false
	global_position = vehicle.global_position + Vector2(cos(vehicle.rotation + PI / 2), sin(vehicle.rotation + PI / 2)) * 35.0
	vehicle = null
	in_car = false
	visible = true

func cycle_weapon() -> void:
	if dead or main == null:
		return
	weapon_index = (weapon_index + 1) % main.weapons.size()
	main.refresh_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			try_interact()
		elif event.keycode == KEY_Q:
			cycle_weapon()

func _physics_process(delta: float) -> void:
	if dead or main == null:
		return
	# Cooldown ticks EVERY frame in both modes.
	# (HTML bug fixed here: in-car cooldown never ticked, drive-by fired once.)
	if fire_cooldown > 0.0:
		fire_cooldown -= 1.0
	if in_car and vehicle != null:
		global_position = vehicle.global_position
		rotation = vehicle.rotation
		var mv := _move_vector()
		vehicle.drive_input(mv, mv.length())
		is_shouting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if is_shouting and fire_cooldown <= 0.0:
			main.player_shoot(global_position, (get_global_mouse_position() - global_position).angle(), true)
			fire_cooldown = 8.0
		return
	var move := _move_vector()
	if move.length() > 0.05:
		var prev := global_position
		global_position += move * move_speed
		if world != null and world.is_blocked(global_position, 11.0):
			global_position = prev
	global_position.x = clamp(global_position.x, 15, World.SIZE - 15)
	global_position.y = clamp(global_position.y, 15, World.SIZE - 15)
	rotation = (get_global_mouse_position() - global_position).angle()
	is_shouting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if is_shouting and fire_cooldown <= 0.0:
		main.player_shoot(global_position, rotation, false)
		# cooldown is set by main.player_shoot from the weapon's rate
	tick_flap(delta)
	queue_redraw()

func _move_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	return v.normalized() if v.length() > 0.0 else Vector2.ZERO

func _draw() -> void:
	if not in_car and not dead:
		draw_flappy_person()
		draw_rect(Rect2(4, -3, 18, 6), Color(0.2, 0.2, 0.2))  # greybox gun
		draw_line(Vector2(20, 0), Vector2(80, 0), Color(1, 0.15, 0.15, 0.3), 1.0)
