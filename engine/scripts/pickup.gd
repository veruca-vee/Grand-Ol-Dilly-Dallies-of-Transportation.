class_name Pickup
extends Node2D

var kind: String = "cash"  # "cash" | "health"
var collected: bool = false
var bob: float = 0.0

func _process(delta: float) -> void:
	bob += delta * 3.0
	queue_redraw()

func _draw() -> void:
	var y := sin(bob) * 4.0
	var c := Color(0, 1, 1) if kind == "cash" else Color(0, 1, 0)
	draw_circle(Vector2(0, y), 10, c)
	if kind == "health":
		draw_rect(Rect2(-8, y - 3, 16, 6), Color.WHITE)
		draw_rect(Rect2(-3, y - 8, 6, 16), Color.WHITE)
