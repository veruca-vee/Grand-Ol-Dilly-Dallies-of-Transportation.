class_name Explosion
extends Node2D

var t: float = 0.0
var max_radius: float = 90.0

func _process(delta: float) -> void:
	t += delta * 2.5
	queue_redraw()
	if t >= 1.0:
		queue_free()

func _draw() -> void:
	var r := max_radius * t
	draw_circle(Vector2.ZERO, r, Color(1, 0.5, 0, 1.0 - t))
	draw_circle(Vector2.ZERO, r * 0.6, Color(1, 0.9, 0, 1.0 - t))
