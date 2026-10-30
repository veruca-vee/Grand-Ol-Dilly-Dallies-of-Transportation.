class_name World
extends Node2D

# City grid, numbers from the HTML: world 3600, block 340, road 100,
# ~15% of blocks skipped. Buildings are greybox rectangles.

const SIZE := 3600.0
const BLOCK := 340.0
const ROAD := 100.0

var buildings: Array[Rect2] = []

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234  # deterministic greybox; the HTML used Math.random()
	var x := 0.0
	while x < SIZE:
		var y := 0.0
		while y < SIZE:
			if rng.randf() >= 0.15:
				buildings.append(Rect2(x + ROAD / 2.0, y + ROAD / 2.0, BLOCK - ROAD, BLOCK - ROAD))
			y += BLOCK
		x += BLOCK

func is_blocked(pos: Vector2, r: float) -> bool:
	for b in buildings:
		var closest := Vector2(clamp(pos.x, b.position.x, b.position.x + b.size.x), clamp(pos.y, b.position.y, b.position.y + b.size.y))
		if pos.distance_to(closest) < r:
			return true
	return false

func hits_building(pos: Vector2) -> bool:
	for b in buildings:
		if b.has_point(pos):
			return true
	return false

func _draw() -> void:
	draw_rect(Rect2(0, 0, SIZE, SIZE), Color(0.07, 0.07, 0.10))  # roads / ground
	for b in buildings:
		draw_rect(b, Color(0.14, 0.14, 0.18))
		draw_rect(b.grow(-6), Color(0.18, 0.18, 0.23))
	draw_rect(Rect2(0, 0, SIZE, SIZE), Color(1, 0, 0, 0.35), false, 4.0)
