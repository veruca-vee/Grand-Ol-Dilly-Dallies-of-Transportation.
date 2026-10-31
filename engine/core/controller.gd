class_name Controller
extends RefCounted

# ENGINE CORE — character/vehicle input and the camera-relative
# movement math. Input is read by physical key (this engine reads
# Input.is_key_pressed, no InputMap — a game that needs remapping
# wraps these two readers).
#
# The movement rule (the Gate 3D-2 walk fix, now core): W walks
# where the camera looks, not world-north. For a follow camera whose
# "behind the actor" vector is (sin(yaw), 0, cos(yaw)), camera
# forward is its negation, (-sin(yaw), 0, -cos(yaw)); at yaw 0
# forward is (0,0,-1) and right is (1,0,0).
#
# Extracted from gate3d/player3d.gd and gate3d/car3d.gd in the
# Engine Core gate (step 7). The math and the key signs are
# byte-for-byte the shipped ones; the autotest walks through them.

# On-foot input: x = strafe (D-A), y = forward (W-S).
static func read_walk_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	return v

# Driving input: x = steer (A +, D -), y = throttle (W +, S -).
static func read_drive_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x -= 1.0
	return v

static func forward_for_yaw(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

static func right_for_yaw(yaw: float) -> Vector3:
	return forward_for_yaw(yaw).cross(Vector3.UP)

# Camera-relative move direction for a walk input at a camera yaw.
static func move_dir(input_vec: Vector2, yaw: float) -> Vector3:
	var fwd := forward_for_yaw(yaw)
	var right := fwd.cross(Vector3.UP)
	return (fwd * input_vec.y + right * input_vec.x).normalized()
