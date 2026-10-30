class_name FlappyPerson
extends CharacterBody2D

# GATE 0 STIPULATION (Vee, 2026-10-29): characters look similar to the
# Canadians in South Park. Design translation, drawn in code, no copied
# art: a simple flat body, beady close-set eyes, and a head split
# horizontally at the mouth — the entire top half of the head lifts and
# drops (the "flap") while the character is talking / shouting.
#
# In this top-down sprite the split runs across the head, the upper
# half is the -Y half in local space, and `flap` (0..1) is how far it
# has lifted this frame. Pedestrians flap when fleeing ("!"), the
# player flaps while firing, enemies flap while shooting.

var body_color: Color = Color(0.6, 0.6, 0.65)
var skin_color: Color = Color(0.96, 0.80, 0.64)
var radius: float = 11.0

var flap: float = 0.0
var flap_time: float = 0.0
var is_shouting: bool = false

func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)

func tick_flap(delta: float) -> void:
	if is_shouting:
		flap_time += delta * 14.0
		flap = 0.5 + 0.5 * sin(flap_time)  # whole top of head, up-down
	else:
		flap = move_toward(flap, 0.0, delta * 8.0)
	queue_redraw()

func _semi(radius_: float, upper: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 12
	for i in range(steps + 1):
		var a := PI + (PI * float(i) / float(steps)) if upper else (PI * float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * radius_)
	return pts

func draw_flappy_person() -> void:
	# shadow
	draw_circle(Vector2(2, 3), radius, Color(0, 0, 0, 0.35))
	# body (flat, simple)
	draw_circle(Vector2.ZERO, radius, body_color)
	# head: lower half stays, upper half lifts by flap
	var head_r := radius * 0.62
	var lift := Vector2(0, -flap * head_r * 0.9)
	draw_colored_polygon(_semi(head_r, false), skin_color.darkened(0.08))
	# upper semicircle, drawn offset by the flap lift
	draw_set_transform(lift, 0.0, Vector2.ONE)
	draw_colored_polygon(_semi(head_r, true), skin_color)
	# mouth gap: dark line that widens as the top half lifts
	# beady eyes: two small, close-set black ovals on the UPPER half,
	# so they ride up and down with the flap.
	var eye_y := -head_r * 0.35
	draw_circle(Vector2(-head_r * 0.22, eye_y), 1.4, Color.BLACK)
	draw_circle(Vector2(head_r * 0.22, eye_y), 1.4, Color.BLACK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flap > 0.05:
		draw_line(Vector2(-head_r * 0.7, 0), Vector2(head_r * 0.7, 0), Color(0.2, 0.05, 0.05), 1.5 + flap * 2.0)
