class_name FollowCamera
extends RefCounted

# ENGINE CORE — the follow-cam rig: sits behind + above the actor,
# its yaw lerping toward the actor's facing, the camera position
# lerping toward the rig point, looking at the actor's chest.
# Distances/heights are per-call game config; the yaw STATE lives
# here, and the game reads it back for aim/facing (the camera yaw
# is what "forward" means for the controller and the shooter).
#
# Extracted from gate3d_main.gd's _process in the Engine Core gate
# (step 7); rates and geometry are the shipped ones.

var yaw: float = 0.0
var yaw_rate: float = 4.0   # yaw lerp speed toward the actor
var pos_rate: float = 8.0   # position lerp speed toward the rig point
var aim_height: float = 1.4 # look_at offset above the actor's feet

# Behind a -Z-facing actor is +Z in its yaw frame.
static func back_for_yaw(yaw_: float) -> Vector3:
	return Vector3(sin(yaw_), 0, cos(yaw_))

static func aim_direction(camera: Camera3D) -> Vector3:
	return -camera.global_transform.basis.z

func update(camera: Camera3D, actor: Node3D, delta: float, dist: float, height: float) -> void:
	var actor_yaw := actor.global_transform.basis.get_euler().y
	yaw = lerp_angle(yaw, actor_yaw, delta * yaw_rate)
	var target_pos := actor.global_position + back_for_yaw(yaw) * dist + Vector3(0, height, 0)
	camera.global_position = camera.global_position.lerp(target_pos, delta * pos_rate)
	camera.look_at(actor.global_position + Vector3(0, aim_height, 0), Vector3.UP)
