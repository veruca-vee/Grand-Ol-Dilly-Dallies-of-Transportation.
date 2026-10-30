class_name Minimap
extends Control

# Gate 3D-2: cheap top-down minimap — no SubViewport, just _draw
# from world positions each frame. World is 240 units across; roads
# sit on the 52-unit grid (see gate3d_main._build_city).
# North (-Z) is up: map_y grows with +Z, so -Z lands at the top.

var main: Node = null  # gate3d_main — reads player / enemies / cars

func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	size = Vector2(180, 180)
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _to_map(p: Vector3) -> Vector2:
	var s := size.x / 240.0
	return Vector2((p.x + 120.0) * s, (p.z + 120.0) * s)

func _draw() -> void:
	if main == null:
		return
	var s := size.x / 240.0
	# backing: Midnight Circle panel
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.067, 0.05, 0.13, 0.82))
	# block pads (between the roads)
	var block_col := Color(0.23, 0.20, 0.35, 0.9)
	for i in range(-2, 2):
		for j in range(-2, 2):
			var cx := i * 52.0 + 26.0
			var cz := j * 52.0 + 26.0
			draw_rect(Rect2(Vector2((cx - 21.0 + 120.0) * s, (cz - 21.0 + 120.0) * s), Vector2(42.0 * s, 42.0 * s)), block_col)
	# roads
	var road_col := Color(0.05, 0.05, 0.07, 0.95)
	for i in range(-2, 3):
		var c := i * 52.0
		draw_rect(Rect2(Vector2((c - 5.0 + 120.0) * s, 0), Vector2(10.0 * s, size.y)), road_col)
		draw_rect(Rect2(Vector2(0, (c - 5.0 + 120.0) * s), Vector2(size.x, 10.0 * s)), road_col)
	# cars: small silver-blue squares
	for c in main.cars:
		if is_instance_valid(c) and not c.dead:
			draw_rect(Rect2(_to_map(c.global_position) - Vector2(2, 2), Vector2(4, 4)), Color(0.62, 0.70, 0.95))
	# enemies: ember dots (tanks bigger)
	for e in main.enemies:
		if is_instance_valid(e) and not e.dead:
			var r := 4.0 if e.kind == "tank" else 2.5
			draw_circle(_to_map(e.global_position), r, Color(1.0, 0.33, 0.44))
	# player: candle-gold dot with a silver ring
	if main.player != null and is_instance_valid(main.player):
		var pp := _to_map(main.player.global_position)
		draw_circle(pp, 4.5, Color(0.75, 0.78, 0.91))
		draw_circle(pp, 3.2, Color(1.0, 0.83, 0.47))
	# border: moon-silver
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.91, 0.6), false, 1.5)
