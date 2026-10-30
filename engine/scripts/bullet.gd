class_name Bullet
extends Node2D

var vel: Vector2 = Vector2.ZERO
var life: float = 1.0
var damage: float = 10.0
var is_player: bool = true
var is_rocket: bool = false
var bullet_color: Color = Color(1, 0.85, 0.4)
var main: Node = null  # set by spawner; main.gd resolves all hits

func setup(from: Vector2, angle: float, weapon: Dictionary, player_owned: bool, dmg_mult: float, game_main: Node) -> void:
	global_position = from
	var speed := 10.0 if weapon.get("rocket", false) else 18.0
	vel = Vector2(cos(angle), sin(angle)) * speed
	life = float(weapon.get("range", 400)) / speed / 60.0 * 60.0  # frames of range, ticked below per-frame
	damage = float(weapon.get("dmg", 10)) * (dmg_mult if player_owned else 1.0)
	is_player = player_owned
	is_rocket = bool(weapon.get("rocket", false))
	bullet_color = Color(weapon.get("color", "#ffdd88"))
	main = game_main

func _process(delta: float) -> void:
	global_position += vel  # HTML moved bullets per-frame, not per-second
	life -= 1.0
	if main != null:
		main.resolve_bullet(self)
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0 if is_rocket else 2.5, bullet_color)
