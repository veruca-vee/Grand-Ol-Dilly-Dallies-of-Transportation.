extends Node3D

# SMOKETEST — a throwaway test fixture, NOT a shipped game.
#
# The Engine Core gate's port test: this tiny scene boots ONLY the
# reusable engine (res://core/) with its OWN data set (1 weapon,
# 1 enemy type, a 3-star wanted table, upgrade costs that match
# nothing in G.O.D.O.T) and checks the core the way a new game
# would use it: move (camera-relative), shoot (damage dealt),
# buy (upgrade purchase at the fixture's own prices) — plus bonus
# checks for wanted/save/flap-rig/sfx. If a new game can't stand
# up from core + data, the extraction isn't done; this is the proof.
#
# Run: godot --headless --path . res://smoketest/SmokeTest.tscn

var walker: CharacterBody3D = null
var move_active: bool = false
var move_input := Vector2.ZERO
var test_yaw: float = 0.0

func _ready() -> void:
	# ground (layer 1, like every game on this engine)
	var ground := StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	var gshape := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(120, 1, 120)
	gshape.shape = gbox
	gshape.position = Vector3(0, -0.5, 0)
	ground.add_child(gshape)
	add_child(ground)
	# walker: a bare CharacterBody3D driven by core Controller math
	walker = CharacterBody3D.new()
	walker.collision_layer = 2
	walker.collision_mask = 7
	var wshape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	wshape.shape = cap
	wshape.position = Vector3(0, 0.85, 0)
	walker.add_child(wshape)
	walker.position = Vector3(0, 0.2, 0)
	add_child(walker)
	_run()

func _physics_process(delta: float) -> void:
	if walker == null or not move_active:
		return
	if not walker.is_on_floor():
		walker.velocity.y -= 22.0 * delta
	else:
		walker.velocity.y = -0.5
	var dir := Controller.move_dir(move_input, test_yaw)
	walker.velocity.x = dir.x * 5.0
	walker.velocity.z = dir.z * 5.0
	walker.move_and_slide()

func _run() -> void:
	var fails: Array[String] = []
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The fixture's own data, loaded through core DataLoader.
	var weapons := DataLoader.load_array("res://smoketest/data/weapons.json", "weapons")
	var upgrade_defs := DataLoader.load_array("res://smoketest/data/upgrades.json", "upgrades")
	var world := DataLoader.load_json("res://smoketest/data/enemies_world_wanted.json")
	if weapons.size() != 1:
		fails.append("fixture weapons: expected 1, got %d" % weapons.size())
	var weapon: Dictionary = weapons[0] if weapons.size() > 0 else {}

	# --- MOVE: camera-relative (yaw -PI/2 => forward is +X) ---
	test_yaw = -PI / 2.0
	var expect_fwd := Controller.forward_for_yaw(test_yaw)
	var start := walker.global_position
	move_input = Vector2(0, 1)
	move_active = true
	for i in range(30):
		await get_tree().physics_frame
	move_active = false
	var disp := walker.global_position - start
	disp.y = 0.0
	if disp.length() < 1.5:
		fails.append("move: barely moved (%.2f units in 30 frames)" % disp.length())
	elif disp.normalized().dot(expect_fwd) <= 0.8:
		fails.append("move: displacement %s not along camera forward %s" % [str(disp.normalized()), str(expect_fwd)])
	if fails.is_empty():
		print("SMOKETEST PASS: move camera_relative")

	# --- SHOOT: core hitscan damages a target with fixture data ---
	walker.global_position = Vector3(50, 0.2, 50)  # out of the firing line
	var bot_stats: Dictionary = world.get("enemies", [{}])[0]
	var target := StaticBody3D.new()
	target.collision_layer = 2
	target.collision_mask = 0
	var tshape := CollisionShape3D.new()
	var tbox := BoxShape3D.new()
	tbox.size = Vector3(1, 2, 1)
	tshape.shape = tbox
	tshape.position = Vector3(0, 1.0, 0)
	target.add_child(tshape)
	target.position = Vector3(0, 0, -6)
	add_child(target)
	target.set_meta("hp", float(bot_stats.get("hp", 50)))
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.2, 5)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, -6), Vector3.UP)
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	var muzzle := Vector3(0, 1.5, 4)
	var excl: Array[RID] = []
	var dmg := Combat.effective_damage(weapon, 1.0)
	var shoot_ok := true
	for shot in range(2):
		var hits := Combat.hitscan(space, cam.global_position, FollowCamera.aim_direction(cam), muzzle, Combat.range_units(weapon, 15.0), int(weapon.get("count", 1)), float(weapon.get("spread", 0.0)), excl)
		var hit_any := false
		for h in hits:
			if h.get("collider") == target:
				hit_any = true
				target.set_meta("hp", float(target.get_meta("hp")) - dmg)
		if not hit_any:
			shoot_ok = false
			fails.append("shoot: shot %d missed the target" % (shot + 1))
		if shot == 0 and float(target.get_meta("hp")) != 25.0:
			shoot_ok = false
			fails.append("shoot: hp after one %d-dmg hit is %f, expected 25" % [int(dmg), float(target.get_meta("hp"))])
	if float(target.get_meta("hp")) != 0.0:
		shoot_ok = false
		fails.append("shoot: hp after two hits is %f, expected 0 (dead)" % float(target.get_meta("hp")))
	if shoot_ok:
		print("SMOKETEST PASS: shoot damage_dealt")

	# --- BUY: upgrade purchase at the fixture's OWN prices ---
	var econ := Economy.new()
	econ.setup(world.get("combo", {}))
	econ.cash = 1000
	var ups := Upgrades.new()
	ups.setup(upgrade_defs, 1.4)
	var buy_ok := true
	if ups.cost("armor") != 333:
		buy_ok = false
		fails.append("buy: armor cost is %d, expected 333 (fixture price)" % ups.cost("armor"))
	if econ.cash < ups.cost("armor"):
		buy_ok = false
		fails.append("buy: cannot afford armor with $1000")
	else:
		econ.cash -= ups.cost("armor")
		ups.record_purchase("armor")
	if ups.level("armor") != 1:
		buy_ok = false
		fails.append("buy: armor level is %d, expected 1" % ups.level("armor"))
	if econ.cash != 667:
		buy_ok = false
		fails.append("buy: cash is %d, expected 667" % econ.cash)
	if ups.cost("armor") != 466:
		buy_ok = false
		fails.append("buy: armor cost at level 1 is %d, expected 466 (floor(333 x 1.4))" % ups.cost("armor"))
	if absf(ups.effect_value("armor") - 60.0) > 0.001:
		buy_ok = false
		fails.append("buy: armor effect is %f, expected 60 (50 + 10)" % ups.effect_value("armor"))
	if buy_ok:
		print("SMOKETEST PASS: buy upgrade_purchase")

	# --- BONUS: wanted floor/caps on the fixture's 3-star table,
	# save roundtrip on a fixture path, flap rig boots and flaps,
	# sfx synth produces streams ---
	var bonus_ok := true
	var w := Wanted.new()
	w.setup(world.get("wanted", {}))
	w.add(1.4)
	if w.stars() != 1:
		bonus_ok = false
		fails.append("bonus: floor(1.4) gave %d stars, expected 1" % w.stars())
	if w.cap(1) != 2:
		bonus_ok = false
		fails.append("bonus: cap at 1 star is %d, expected 2 (fixture table)" % w.cap(1))
	if w.spawn_type(1) != "bot":
		bonus_ok = false
		fails.append("bonus: spawn type is %s, expected bot" % w.spawn_type(1))
	var sg := SaveGame.new("user://smoketest_save.json")
	if not sg.write_payload({"version": 1, "cash": 42}):
		bonus_ok = false
		fails.append("bonus: save write failed")
	elif int(sg.read_payload().get("cash", 0)) != 42:
		bonus_ok = false
		fails.append("bonus: save roundtrip lost the payload")
	sg.delete()
	var rig := FlapRig.new()
	add_child(rig)
	await get_tree().physics_frame
	rig.is_talking = true
	for i in range(3):
		rig.tick_flap(0.05)
	if rig.upper_pivot == null or rig.flap_amount <= 0.1:
		bonus_ok = false
		fails.append("bonus: flap rig did not flap (amount %f)" % rig.flap_amount)
	if SfxSynth.gunshot() == null or SfxSynth.pickup() == null:
		bonus_ok = false
		fails.append("bonus: sfx synth returned a null stream")
	if bonus_ok:
		print("SMOKETEST PASS: wanted_floor save_roundtrip flap_rig sfx_synth")

	for f in fails:
		print("SMOKETEST FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() else 1)
