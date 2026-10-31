class_name Combat
extends RefCounted

# ENGINE CORE — weapon resolution from weapon data: effective
# damage/rate under upgrade multipliers, camera-ray hitscan,
# melee target selection, explosion falloff, aim jitter, and
# projectile hit SELECTION. What a hit DOES (damage calls, kill
# economy, explosions chaining) is game rules and stays in the
# game layer — core decides what was hit, in what order, for how
# much; the game applies it.
#
# Extracted from gate3d_main.gd in the Engine Core gate (step 6).
# Collision convention in this engine: world/buildings layer 1,
# characters layer 2, cars layer 4; weapon rays use mask 7 (all).

# --- projectile hit profile (game-configured radii/offsets) ---
var car_offset := Vector3(0, 0.6, 0)
var car_radius := 1.9
var ped_offset := Vector3(0, 0.9, 0)
var ped_radius := 0.95
var enemy_offset := Vector3(0, 0.9, 0)
var enemy_radius := 1.2
var player_offset := Vector3(0, 0.9, 0)
var player_radius := 1.05

func setup_projectiles(cfg: Dictionary) -> void:
	car_offset = cfg.get("car_offset", car_offset)
	car_radius = float(cfg.get("car_radius", car_radius))
	ped_offset = cfg.get("ped_offset", ped_offset)
	ped_radius = float(cfg.get("ped_radius", ped_radius))
	enemy_offset = cfg.get("enemy_offset", enemy_offset)
	enemy_radius = float(cfg.get("enemy_radius", enemy_radius))
	player_offset = cfg.get("player_offset", player_offset)
	player_radius = float(cfg.get("player_radius", player_radius))

# --- weapon math ---
static func effective_damage(weapon: Dictionary, mult: float) -> float:
	return float(weapon.get("dmg", 10)) * mult

static func effective_rate(weapon: Dictionary, mult: float) -> float:
	return float(weapon.get("rate_frames", 8)) / mult

static func range_units(weapon: Dictionary, scale: float) -> float:
	return float(weapon.get("range", 400)) / scale

# --- rays ---
static func ray_end(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, dist: float, exclude: Array[RID]) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 7, exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	return from + dir * dist

static func spread_direction(dir: Vector3, spread: float) -> Vector3:
	if spread > 0.0:
		return (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * spread).normalized()
	return dir

static func jitter_dir(dir: Vector3, amount: float) -> Vector3:
	return (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * amount).normalized()

# Fire `count` pellets: each takes its aim point from the camera ray
# (with spread), then traces muzzle -> aim. Returns one Dictionary
# per pellet: {"end": Vector3, "collider": Object or null}.
static func hitscan(space: PhysicsDirectSpaceState3D, cam_from: Vector3, cam_dir: Vector3, muzzle: Vector3, dist: float, count: int, spread: float, exclude: Array[RID]) -> Array:
	var results: Array = []
	for i in range(count):
		var dir_i := spread_direction(cam_dir, spread)
		var aim := ray_end(space, cam_from, dir_i, dist, exclude)
		var q := PhysicsRayQueryParameters3D.create(muzzle, aim, 7, exclude)
		var hit := space.intersect_ray(q)
		var end := aim
		var collider: Object = null
		if not hit.is_empty():
			end = hit.position
			collider = hit.collider
		results.append({"end": end, "collider": collider})
	return results

# --- melee ---
# Candidates in front of the actor: alive, within max_dist, and the
# facing dot product beats min_dot. Order preserved from input.
static func melee_targets(origin: Vector3, facing: Vector3, candidates: Array, max_dist: float, min_dot: float) -> Array:
	var out: Array = []
	for c in candidates:
		if c.get("dead"):
			continue
		var to: Vector3 = c.global_position - origin
		if origin.distance_to(c.global_position) < max_dist and facing.dot(to.normalized()) > min_dot:
			out.append(c)
	return out

# --- explosions ---
static func explosion_falloff(dmg: float, dist: float, radius: float) -> float:
	return dmg * (1.0 - dist / radius) * 1.5

# --- projectile hit selection ---
# Same order as the source rules: cars, peds, enemies, player.
# ctx: {"cars": Array, "peds": Array, "enemies": Array, "player": Node or null}
# NOTE: `shooter` is Variant, not Object — a projectile can outlive
# its shooter (an enemy dies with a bullet in flight), and passing a
# freed instance through a typed Object parameter is a hard error,
# while the old inline code only ever COMPARED against it.
# Returns {"kind": "car"|"ped"|"enemy"|"player", "target": Object}
# or {} when the projectile hits nothing this frame.
func resolve_projectile(pos: Vector3, is_player_bullet: bool, shooter: Variant, ctx: Dictionary) -> Dictionary:
	var pl: Variant = ctx.get("player")
	for c in ctx.get("cars", []):
		if c.get("dead"):
			continue
		if is_player_bullet and pl != null and pl.get("driving") == c:
			continue
		if pos.distance_to(c.global_position + car_offset) < car_radius:
			return {"kind": "car", "target": c}
	for p in ctx.get("peds", []):
		if not p.get("dead") and pos.distance_to(p.global_position + ped_offset) < ped_radius:
			return {"kind": "ped", "target": p}
	for e in ctx.get("enemies", []):
		if not e.get("dead") and e != shooter and pos.distance_to(e.global_position + enemy_offset) < enemy_radius:
			return {"kind": "enemy", "target": e}
	if not is_player_bullet and pl != null and not pl.get("dead") and pl.get("driving") == null:
		if pos.distance_to(pl.global_position + player_offset) < player_radius:
			return {"kind": "player", "target": pl}
	return {}
