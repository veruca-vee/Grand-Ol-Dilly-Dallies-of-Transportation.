class_name Enemy
extends FlappyPerson

var kind: String = "cop"
var speed: float = 1.8
var hp: float = 40.0
var max_hp: float = 40.0
var dmg: float = 8.0
var fire_rate_frames: float = 22.0
var range_: float = 350.0
var fire_cooldown: float = 0.0
var dead: bool = false
var world: World = null
var main: Node = null

func setup(kind_: String, stats: Dictionary) -> void:
	kind = kind_
	hp = float(stats.get("hp", 40))
	max_hp = hp
	speed = float(stats.get("speed", 1.8))
	dmg = float(stats.get("dmg", 8))
	fire_rate_frames = float(stats.get("fire_rate_frames", 22))
	range_ = float(stats.get("range", 350))
	radius = float(stats.get("size", 10))
	body_color = Color(stats.get("color", "#4488ff"))

func _ready() -> void:
	super._ready()
	add_to_group("enemies")

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	if hp <= 0.0 and main != null:
		main.kill_enemy(self)

func _physics_process(delta: float) -> void:
	if dead or main == null or main.player == null:
		return
	var player_pos: Vector2 = main.player.global_position
	var d := global_position.distance_to(player_pos)
	rotation = (player_pos - global_position).angle()
	if d > range_ * 0.6:
		var prev := global_position
		global_position += Vector2(cos(rotation), sin(rotation)) * speed
		if world != null and world.is_blocked(global_position, radius):
			global_position = prev
	if fire_cooldown > 0.0:
		fire_cooldown -= 1.0
	is_shouting = false
	if d < range_ and fire_cooldown <= 0.0:
		is_shouting = true  # shooting enemies flap, Canadian-style
		main.enemy_shoot(self)
		fire_cooldown = fire_rate_frames
	global_position.x = clamp(global_position.x, 40, World.SIZE - 40)
	global_position.y = clamp(global_position.y, 40, World.SIZE - 40)
	tick_flap(delta)
	queue_redraw()

func _draw() -> void:
	if dead:
		return
	if kind == "tank":
		draw_rect(Rect2(-24, -16, 48, 32), body_color)
		draw_rect(Rect2(-8, -6, 28, 12), Color(0.13, 0.13, 0.13))
		draw_rect(Rect2(18, -3, 6, 6), Color(1, 0.27, 0.27))
	else:
		draw_flappy_person()
		draw_rect(Rect2(6, -2, 10, 4), Color(1, 0.27, 0.27))  # greybox gun
	if hp < max_hp:
		draw_rect(Rect2(-15, -22, 30, 4), Color(0.2, 0, 0))
		draw_rect(Rect2(-15, -22, 30 * hp / max_hp, 4), Color(0, 1, 0) if hp / max_hp > 0.4 else Color(1, 0, 0))
