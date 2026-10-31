class_name Minimap
extends Control

# ENGINE CORE — a cheap top-down minimap: no SubViewport, just
# _draw from world positions each frame. Layout (world size, grid
# pitch, road width, extent) and colors are config; the defaults
# are G.O.D.O.T's city (240 across, 52 grid, Midnight Circle
# palette). North (-Z) is up: map_y grows with +Z, so -Z is top.
#
# The data source is duck-typed: it must expose `player` (Node3D or
# null), `cars` (Array of Node3D with .dead / .global_position) and
# `enemies` (same, plus .kind). Set `source` once after creation.
#
# Extracted from gate3d/minimap.gd in the Engine Core gate
# (step 8); drawing math unchanged, constants became config.

var source: Node = null

var world_size: float = 240.0
var grid_pitch: float = 52.0
var road_width: float = 10.0
var grid_lo: int = -2  # blocks span grid_lo..grid_hi-1, roads grid_lo..grid_hi
var grid_hi: int = 2

var col_back := Color(0.067, 0.05, 0.13, 0.82)
var col_block := Color(0.23, 0.20, 0.35, 0.9)
var col_road := Color(0.05, 0.05, 0.07, 0.95)
var col_car := Color(0.62, 0.70, 0.95)
var col_enemy := Color(1.0, 0.33, 0.44)
var col_player_ring := Color(0.75, 0.78, 0.91)
var col_player := Color(1.0, 0.83, 0.47)
var col_border := Color(0.75, 0.78, 0.91, 0.6)

func configure(cfg: Dictionary) -> void:
	world_size = float(cfg.get("world_size", world_size))
	grid_pitch = float(cfg.get("grid_pitch", grid_pitch))
	road_width = float(cfg.get("road_width", road_width))
	grid_lo = int(cfg.get("grid_lo", grid_lo))
	grid_hi = int(cfg.get("grid_hi", grid_hi))
	for key in ["col_back", "col_block", "col_road", "col_car", "col_enemy", "col_player_ring", "col_player", "col_border"]:
		if cfg.has(key):
			set(key, cfg[key])

func _ready() -> void:
	custom_minimum_size = Vector2(180, 180)
	size = Vector2(180, 180)
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _to_map(p: Vector3) -> Vector2:
	var s := size.x / world_size
	return Vector2((p.x + world_size * 0.5) * s, (p.z + world_size * 0.5) * s)

func _draw() -> void:
	if source == null:
		return
	var s := size.x / world_size
	var half := world_size * 0.5
	var block := grid_pitch - road_width
	# backing panel
	draw_rect(Rect2(Vector2.ZERO, size), col_back)
	# block pads (between the roads)
	for i in range(grid_lo, grid_hi):
		for j in range(grid_lo, grid_hi):
			var cx := i * grid_pitch + grid_pitch * 0.5
			var cz := j * grid_pitch + grid_pitch * 0.5
			draw_rect(Rect2(Vector2((cx - block * 0.5 + half) * s, (cz - block * 0.5 + half) * s), Vector2(block * s, block * s)), col_block)
	# roads
	for i in range(grid_lo, grid_hi + 1):
		var c := i * grid_pitch
		draw_rect(Rect2(Vector2((c - road_width * 0.5 + half) * s, 0), Vector2(road_width * s, size.y)), col_road)
		draw_rect(Rect2(Vector2(0, (c - road_width * 0.5 + half) * s), Vector2(size.x, road_width * s)), col_road)
	# cars: small squares
	for c in source.cars:
		if is_instance_valid(c) and not c.dead:
			draw_rect(Rect2(_to_map(c.global_position) - Vector2(2, 2), Vector2(4, 4)), col_car)
	# enemies: dots (tanks bigger)
	for e in source.enemies:
		if is_instance_valid(e) and not e.dead:
			var r := 4.0 if e.kind == "tank" else 2.5
			draw_circle(_to_map(e.global_position), r, col_enemy)
	# player: gold dot with a silver ring
	if source.player != null and is_instance_valid(source.player):
		var pp := _to_map(source.player.global_position)
		draw_circle(pp, 4.5, col_player_ring)
		draw_circle(pp, 3.2, col_player)
	# border
	draw_rect(Rect2(Vector2.ZERO, size), col_border, false, 1.5)
