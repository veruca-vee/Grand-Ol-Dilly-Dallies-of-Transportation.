class_name Ped
extends FlappyPerson

var walk_speed: float = 0.9
var target_angle: float = 0.0
var timer: float = 0.0
var fleeing: bool = false
var dead: bool = false
var world: World = null
var main: Node = null

func _ready() -> void:
	super._ready()
	add_to_group("peds")
	body_color = [Color(0.8, 0.3, 0.6), Color(0.4, 0.5, 0.8), Color(0.3, 0.6, 0.8), Color(0.8, 0.6, 0.3), Color(0.4, 0.8, 0.8)][randi() % 5]
	target_angle = randf() * TAU

func _physics_process(delta: float) -> void:
	if dead:
		return
	var player: Node2D = main.player if main != null else null
	fleeing = false
	if player != null:
		var d := global_position.distance_to(player.global_position)
		if d < 150.0 and (main.wanted_level >= 1.0 or main.player_weapon_index() > 0):
			fleeing = true
			target_angle = (global_position - player.global_position).angle()
			walk_speed = 2.5
	if not fleeing:
		timer -= delta
		if timer <= 0.0:
			timer = 0.8 + randf() * 2.0
			target_angle = randf() * TAU
			walk_speed = 0.6 + randf() * 0.7
	rotation += clamp(wrapf(target_angle - rotation, -PI, PI), -0.04, 0.04)
	var prev := global_position
	global_position += Vector2(cos(rotation), sin(rotation)) * walk_speed
	if world != null and world.is_blocked(global_position, 10.0):
		global_position = prev
		target_angle += PI
	global_position.x = clamp(global_position.x, 20, World.SIZE - 20)
	global_position.y = clamp(global_position.y, 20, World.SIZE - 20)
	is_shouting = fleeing  # fleeing peds flap their whole head, Canadian-style
	tick_flap(delta)

func _draw() -> void:
	if not dead:
		draw_flappy_person()
