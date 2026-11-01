class_name DebugLog
extends RefCounted

# ENGINE CORE — playtest telemetry: a session log (header,
# timed state snapshots, named events) plus capped frame
# captures, written to a local directory the game chooses.
#
# The game feeds it snapshot dictionaries and events; the
# logger owns the files, the rotation and the timing. It is
# deliberately boring technology: plain text, one line per
# record, appends only, NO network anything — sessions are
# fetched off the player's machine by hand (see
# tools/playtest_digest.py in the repo for the reader).
#
# Failure posture: if the session cannot be started (bad or
# unwritable dir), the logger disables itself, prints ONE
# line to stderr, and every later call is a no-op. Telemetry
# must never crash or spam the game it observes.
#
# Snapshot dictionaries carry the keys: pos (Vector3), vy
# (float), fps (int), wanted (float), in_car (bool), hp
# (float), cash (int). Missing keys log as zeroes.

# Engine defaults — a game may override any of these per
# instance before start_session; none of them are any one
# game's numbers.
var snapshot_interval: float = 0.5  # seconds between snapshots
var frame_interval: float = 20.0  # seconds between auto-frames
var frame_cap: int = 90  # frames kept; oldest deleted past this

# The game sets this to a Callable returning an Image (or
# null). Viewport grabs are renderer-dependent, so capture
# goes through this provider: tests inject generated images,
# the game injects its viewport, and a null/empty image is
# refused by capture_frame either way.
var frame_provider: Callable

var session_path: String = ""  # "" until start_session succeeds
var dir_path: String = ""
var frames: Array = []  # kept frame paths, oldest first

var _file: FileAccess = null
var _session_stamp: String = ""  # yyyymmdd-hhmmss of session start
var _active: bool = false
var _failed: bool = false
var _start_msec: int = 0
var _snap_acc: float = 0.0
var _frame_acc: float = 0.0
# Test seam (same pattern as the autotest's move_override):
# when >= 0, elapsed() returns this instead of the live clock,
# so tests can stamp deterministic times. Play never sets it.
var _test_now: float = -1.0

func elapsed() -> float:
	if _test_now >= 0.0:
		return _test_now
	return float(Time.get_ticks_msec() - _start_msec) / 1000.0

func start_session(dir: String, build_label: String) -> bool:
	if _active:
		end_session()
	dir_path = dir.trim_suffix("/")
	var global_dir := ProjectSettings.globalize_path(dir_path)
	var err := DirAccess.make_dir_recursive_absolute(global_dir)
	if err != OK and not DirAccess.dir_exists_absolute(global_dir):
		_fail("cannot create telemetry dir %s" % dir_path)
		return false
	var dt := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d-%02d%02d%02d" % [
		int(dt.get("year", 0)), int(dt.get("month", 0)),
		int(dt.get("day", 0)), int(dt.get("hour", 0)),
		int(dt.get("minute", 0)), int(dt.get("second", 0))]
	_session_stamp = stamp
	session_path = dir_path + "/session-" + stamp + ".log"
	_file = FileAccess.open(session_path, FileAccess.WRITE)
	if _file == null:
		_fail("cannot open session file %s" % session_path)
		session_path = ""
		return false
	_start_msec = Time.get_ticks_msec()
	_snap_acc = 0.0
	_frame_acc = 0.0
	frames.clear()
	_active = true
	var vi := Engine.get_version_info()
	var godot_ver := "%d.%d.%d-%s" % [
		int(vi.get("major", 0)), int(vi.get("minor", 0)),
		int(vi.get("patch", 0)), str(vi.get("status", ""))]
	_write("# GODOT-TELEMETRY v1 build=%s godot=%s started=%s" % [
		build_label.replace(" ", "_"), godot_ver,
		Time.get_datetime_string_from_system()])
	return true

func end_session() -> void:
	if not _active:
		return
	_write("# end t=%.2f frames=%d" % [elapsed(), frames.size()])
	_file = null  # RefCounted: dropping the handle closes it
	_active = false

func snapshot(state: Dictionary) -> void:
	if not _active:
		return
	var pos: Vector3 = state.get("pos", Vector3.ZERO)
	_write("t=%.2f SNAPSHOT pos=%.2f,%.2f,%.2f vy=%.2f fps=%d wanted=%.2f in_car=%s hp=%.1f cash=%d" % [
		elapsed(), pos.x, pos.y, pos.z,
		float(state.get("vy", 0.0)), int(state.get("fps", 0)),
		float(state.get("wanted", 0.0)),
		"true" if bool(state.get("in_car", false)) else "false",
		float(state.get("hp", 0.0)), int(state.get("cash", 0))])

func event(event_name: String, data: Dictionary = {}) -> void:
	if not _active:
		return
	var parts: Array = ["t=%.2f" % elapsed(), "EVENT", event_name]
	var keys := data.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [str(k), _fmt_value(data[k])])
	_write(" ".join(parts))

# The game calls this every frame with its current snapshot
# state; the logger decides when a snapshot / auto-frame is
# due. Returns nothing — observing must not steer the game.
func tick(delta: float, state: Dictionary) -> void:
	if not _active:
		return
	_snap_acc += delta
	while _snap_acc >= snapshot_interval:
		_snap_acc -= snapshot_interval
		snapshot(state)
	_frame_acc += delta
	if _frame_acc >= frame_interval:
		_frame_acc = 0.0
		capture_now()

# Vee's "it broke right here" button: a MARKER event line
# plus a forced frame, whatever the timers say.
func marker() -> void:
	if not _active:
		return
	event("MARKER")
	capture_now()

func capture_now() -> bool:
	if not _active or not frame_provider.is_valid():
		return false
	var img: Variant = frame_provider.call()
	if img is Image:
		return capture_frame(img)
	return false

func capture_frame(image: Image) -> bool:
	if not _active or image == null or image.is_empty():
		return false
	# Frame names carry the session stamp: every session in a
	# shared dir writes the same frame-<t> names otherwise, and
	# later sessions overwrite earlier sessions' frames (seen
	# in the first live playtests, 2026-11-01). The digest
	# parser reads both namings.
	var stem := "frame-%s-%.2f" % [_session_stamp, elapsed()]
	var path := dir_path + "/" + stem + ".png"
	var n := 2
	while FileAccess.file_exists(path):
		path = dir_path + "/" + stem + "-%d.png" % n
		n += 1
	if image.save_png(path) != OK:
		return false
	frames.append(path)
	while frames.size() > frame_cap:
		var old: String = frames.pop_front()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old))
	return true

func _fmt_value(v: Variant) -> String:
	if v is String:
		return str(v).replace(" ", "_")
	return str(v)

func _write(line: String) -> void:
	if not _active or _file == null:
		return
	_file.store_line(line)
	_file.flush()

func _fail(msg: String) -> void:
	if not _failed:
		printerr("DebugLog: " + msg + " (telemetry disabled)")
	_failed = true
	_active = false
