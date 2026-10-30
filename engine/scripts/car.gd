class_name Car
extends CharacterBody2D

# Numbers from the HTML Car class / data file: 56x26, hp 100,
# max_speed 16 per-frame, accel 0.35, friction 0.96.

var car_color: Color = Color(0.8, 0.3, 0.3)
var speed: float = 0.0
var max_speed: float = 16.0
var accel: float = 0.35
var friction_: float = 0.96
var hp: float = 100.0
var max_hp: float = 100.0
var dead: bool = false
var driven: bool = false
var ai: bool = false
var ai_timer: float = 0.0
var ai_steer: float = 0.0
var world: World = null
var main: Node = null

func _ready() -> void:
	add_to_group("cars")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(56, 26)
	shape.shape = rect
	add_child(shape)

func take_damage(amt: float) -> void:
	if dead:
		return
	hp -= amt
	queue_redraw()
	if hp <= 0.0 and main != null:
		main.kill_car(self)

func _physics_process(delta: float) -> void:
	if dead:
		speed *= 0.9
		return
	if driven:
		return  # Player script drives this car (single source of motion)
	if ai:
		ai_timer -= delta
		if ai_timer <= 0.0:
			ai_timer = 0.7 + randf() * 1.5
			ai_steer = (randf() - 0.5) * 0.04
			if randf() < 0.3:
				speed += 0.6
		speed += 0.15
		rotation += ai_steer
		speed = min(speed, max_speed * 0.55)
	else:
		speed *= 0.85
	_drive(delta)

func drive_input(move_vec: Vector2, mag: float) -> void:
	# Called by Player while driven. Mirrors the HTML v2 driven branch.
	if mag > 0.1:
		var target := move_vec.angle()
		rotation += clamp(wrapf(target - rotation, -PI, PI), -0.1, 0.1)
		speed += accel * mag
	_drive(0.0)

func _drive(_delta: float) -> void:
	speed *= friction_
	speed = clamp(speed, -max_speed * 0.45, max_speed)
	var prev := global_position
	global_position += Vector2(cos(rotation), sin(rotation)) * speed
	if world != null and world.is_blocked(global_position, 32.0):
		global_position = prev
		speed *= -0.3
	global_position.x = clamp(global_position.x, 40, World.SIZE - 40)
	global_position.y = clamp(global_position.y, 40, World.SIZE - 40)
	if abs(speed) > 4.0 and main != null:
		main.check_car_runovers(self)
	queue_redraw()

func _draw() -> void:
	var w := 56.0
	var h := 26.0
	draw_rect(Rect2(-w / 2 + 4, -h / 2 + 4, w, h), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(-w / 2, -h / 2, w, h), Color(0.2, 0.2, 0.2) if dead else car_color)
	draw_rect(Rect2(-8, -h / 2 + 3, 16, h - 6), Color(0.04, 0.04, 0.04))
	if driven and not dead:
		draw_colored_polygon(PackedVector2Array([Vector2(w / 2, -h / 2 + 4), Vector2(w / 2 + 120, -h / 2 - 25), Vector2(w / 2 + 120, -h / 2 + 35)]), Color(1, 1, 0.7, 0.18))
	if not dead and hp < max_hp:
		draw_rect(Rect2(-20, -28, 40, 5), Color(0.2, 0, 0))
		draw_rect(Rect2(-20, -28, 40 * hp / max_hp, 5), Color(0, 1, 0) if hp / max_hp > 0.4 else Color(1, 0, 0))
