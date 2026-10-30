extends Node3D

# G.O.D.O.T — Gate 3D-2
# Gate 3D-1's systems (all 9 weapons, wanted, cash/combo — numbers
# from res://data/*.json, rules mirroring engine/scripts/main.gd,
# including the two HTML bug fixes: float wanted + floori() lookups,
# and the fire cooldown ticking EVERY physics frame in both modes)
# on a city that is no longer grey boxes. Gate 3D-2 adds:
#   - Procedural dressing (dressing.gd): code-generated facade
#     textures with lit windows, dressed buildings / roads / props,
#     dressed cars and characters. NO binary assets — the repo push
#     route is text-only, so everything is generated in GDScript.
#   - The Black Market: the 5 upgrades from data/upgrades.json,
#     bought with cash in a B-key panel, effects live.
#   - Save/load to user://godot_save.json (rule in gate3d/README.md).
#   - Synthesized SFX (sfx.gd) — generated AudioStreamWAV, no files.
#   - A _draw minimap (minimap.gd).
# 3D adaptations are labelled in gate3d/README.md.

const SCALE := 15.0  # 2D world units per 3D unit (3600 -> 240)

var data: Dictionary = {}
var weapons: Array = []
var driveby_weapon: Dictionary = {}
var enemy_stats: Dictionary = {}  # kind -> stats dict
var wanted_cfg: Dictionary = {}
var car_stats: Dictionary = {}
var ped_stats: Dictionary = {}

var player: Player3D = null
var cars: Array[Car3D] = []
var enemies: Array = []  # Enemy3D / Tank3D, duck-typed like the 2D code
var buildings: Array = []  # Rect2 XZ footprints, for spawn placement
var camera: Camera3D = null
var cam_yaw: float = 0.0
var state: String = "PLAYING"

var cash: int = 0
var score: int = 0
var kills: int = 0
var cars_destroyed: int = 0

var wanted_level: float = 0.0
var frames_since_crime: int = 0
var combo_count: int = 0
var combo_frames: int = 0

var hud_hp: ProgressBar = null
var hud_weapon: Label = null
var hud_cash: Label = null
var hud_stars: Label = null
var hud_combo: Label = null
var hud_center: Label = null

var fx: Array = []  # transient visuals: {node, ttl, max_ttl, grow}
var autotest: bool = false

# ---------- Gate 3D-2: upgrades / save / shop / sfx / minimap ----------
var dressing: CityDressing = null
var upgrade_defs: Array = []  # from data/upgrades.json, in file order
var upgrade_by_id: Dictionary = {}
var upgrade_levels: Dictionary = {}  # id -> int level
var unlocked_weapons: Array = []  # weapon indices available (3D-1: all)
var base_hp_data: float = 100.0  # data: player.base_hp
const SAVE_PATH := "user://godot_save.json"
const SAVE_PATH_TEST := "user://godot_save_autotest.json"
var save_path: String = SAVE_PATH
var save_frames: int = 0
var frame_counter: int = 0
var shop_open: bool = false
var shop_panel: PanelContainer = null
var shop_cash_label: Label = null
var shop_rows: Dictionary = {}  # id -> {level: Label, buy: Button}
var minimap: Minimap = null
var sfx_streams: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var last_hurt_sfx_frame: int = -100
var last_boom_sfx_frame: int = -100

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # so _input can close the shop while the tree is paused
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args or "--autotest" in OS.get_cmdline_args()
	if autotest:
		# Autotest never touches the player's real save file.
		save_path = SAVE_PATH_TEST
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	data = GameData.world_enemies_wanted()
	weapons = GameData.weapons()
	driveby_weapon = GameData.load_json("res://data/weapons.json").get("driveby_weapon", {})
	for e in data.get("enemies", []):
		enemy_stats[e.get("type", "")] = e
	wanted_cfg = data.get("wanted", {})
	car_stats = data.get("car", {})
	ped_stats = data.get("pedestrian", {})
	base_hp_data = float(data.get("player", {}).get("base_hp", 100))
	upgrade_defs = GameData.load_json("res://data/upgrades.json").get("upgrades", [])
	for d in upgrade_defs:
		upgrade_by_id[d.get("id", "")] = d
		upgrade_levels[d.get("id", "")] = 0
	for i in range(weapons.size()):
		unlocked_weapons.append(i)
	dressing = CityDressing.new()
	load_game()

	_setup_environment()
	_build_city()
	_setup_sfx()
	player = Player3D.new()
	player.position = Vector3(0, 0.2, 8)
	player.main = self
	add_child(player)
	player.max_hp = base_hp_data
	apply_upgrades()
	player.hp = player.max_hp
	player.weapon_index = int(GameData.load_json("res://data/weapons.json").get("player_start_weapon_index", 1))
	player.refresh_gun(weapons[player.weapon_index])
	var car_colors := [Color(0.75, 0.25, 0.25), Color(0.25, 0.35, 0.8), Color(0.3, 0.65, 0.3), Color(0.8, 0.7, 0.2), Color(0.55, 0.57, 0.62), Color(0.45, 0.2, 0.55)]
	var car_spots := [Vector3(4, 0.2, -2), Vector3(-14, 0.2, -30), Vector3(20, 0.2, 24), Vector3(-30, 0.2, 18), Vector3(30, 0.2, -34), Vector3(-24, 0.2, 44)]
	for i in range(car_spots.size()):
		var car := Car3D.new()
		car.car_color = car_colors[i]
		car.position = car_spots[i]
		car.rotation.y = randf() * TAU
		car.main = self
		car.hp = float(car_stats.get("hp", 100))
		car.max_hp = car.hp
		add_child(car)
		cars.append(car)
	for i in range(8):
		var ped := Ped3D.new()
		ped.position = Vector3((randf() - 0.5) * 90, 0.2, (randf() - 0.5) * 90)
		ped.main = self
		add_child(ped)
	camera = Camera3D.new()
	camera.far = 160.0  # PS2 draw distance: short on purpose
	camera.position = Vector3(0, 3, 15)
	add_child(camera)
	_build_hud()
	refresh_hud()

	if "--screenshot" in args or "--screenshot" in OS.get_cmdline_args():
		_take_screenshot()
	if "--countnodes" in args or "--countnodes" in OS.get_cmdline_args():
		var mm_instances := 0
		var stack: Array = [self]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MultiMeshInstance3D and n.multimesh != null:
				mm_instances += n.multimesh.instance_count
			for ch in n.get_children():
				stack.append(ch)
		print("NODECOUNT: nodes=", get_tree().get_node_count(), " multimesh_instances=", mm_instances)
	if autotest:
		_run_autotest()

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Gate 3D-2: procedural PS2-era sky — hazy blue up top, warm
	# smog at the horizon, short fog doing the period draw distance.
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.40, 0.72)
	sm.sky_horizon_color = Color(0.79, 0.76, 0.68)
	sm.sky_curve = 0.09
	sm.ground_bottom_color = Color(0.24, 0.23, 0.21)
	sm.ground_horizon_color = Color(0.79, 0.76, 0.68)
	sm.ground_curve = 0.08
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.74, 0.76)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.4
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)

func _point_free(x: float, z: float, grow: float) -> bool:
	var p := Vector2(x, z)
	for r in buildings:
		if r.grow(grow).has_point(p):
			return false
	return true

func _build_city() -> void:
	# Gate 3D-2 city: same layout grid as 3D-0/1 (roads on the 52
	# pitch, building clusters on the grid points, centre cluster
	# open) — but dressed. All resources come from CityDressing.
	var d := dressing
	# ground slab with collision (noise-concrete material now)
	var ground := StaticBody3D.new()
	var gmesh := MeshInstance3D.new()
	var gbox := BoxMesh.new()
	gbox.size = Vector3(240, 1, 240)
	gmesh.mesh = gbox
	gmesh.position = Vector3(0, -0.5, 0)
	var gmat := d.concrete_mat.duplicate() as StandardMaterial3D
	gmat.albedo_color = Color(0.30, 0.32, 0.29)
	gmat.uv1_scale = Vector3(48, 48, 1)
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	var gshape := CollisionShape3D.new()
	var gcol := BoxShape3D.new()
	gcol.size = Vector3(240, 1, 240)
	gshape.shape = gcol
	gshape.position = Vector3(0, -0.5, 0)
	ground.add_child(gshape)
	add_child(ground)
	# roads: asphalt-textured strips on the grid
	for i in range(-2, 3):
		_road(Vector3(i * 52, 0.02, 0), Vector3(10, 0.05, 240))
		_road(Vector3(0, 0.02, i * 52), Vector3(240, 0.05, 10))
	# dashed lane markings down every road centre (one MultiMesh)
	var dash_xf: Array = []
	for i in range(-2, 3):
		for k in range(-19, 20):
			dash_xf.append(d.xf(Vector3(i * 52, 0.09, k * 6.0)))
			dash_xf.append(d.xf(Vector3(k * 6.0, 0.09, i * 52), PI / 2.0))
	add_child(d.make_multimesh(d.dash_mesh, d.dash_mat, dash_xf))
	# crosswalks at the open centre intersection (the other grid
	# intersections are built over by the clusters, as in 3D-0/1)
	var cw := MeshInstance3D.new()
	cw.mesh = d.crosswalk_mesh
	cw.material_override = d.crosswalk_mat
	add_child(cw)
	# buildings: seeded clusters, 1-3 dressed buildings per grid point
	var rng := RandomNumberGenerator.new()
	rng.seed = 2004  # San Andreas launch year, why not
	var ac_xf: Array = []
	var antenna_xf: Array = []
	var tower_spots: Array = []  # Vector4(x, z, roof_y, footprint)
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			# pavement pad under each cluster (its edge is the curb)
			var pad := MeshInstance3D.new()
			var pbm := BoxMesh.new()
			pbm.size = Vector3(40, 0.1, 40)
			pad.mesh = pbm
			pad.position = Vector3(bx * 52, 0.05, bz * 52)
			var pmat := d.pavement_mat.duplicate() as StandardMaterial3D
			pmat.uv1_scale = Vector3(10, 10, 1)
			pad.material_override = pmat
			add_child(pad)
			if bx == 0 and bz == 0:
				continue  # spawn block stays open (pad only)
			var n := 1 + rng.randi() % 3
			var offs: Array = []
			if n == 1:
				offs = [Vector2(0, 0)]
			elif n == 2:
				offs = [Vector2(-9.5, 0), Vector2(9.5, 0)]
			else:
				offs = [Vector2(-10, -9.5), Vector2(10, -9.5), Vector2(0, 10)]
			for o in offs:
				var w := rng.randf_range(12.0, 17.0) if n > 1 else rng.randf_range(15.0, 20.0)
				var dep := rng.randf_range(12.0, 17.0) if n > 1 else rng.randf_range(15.0, 20.0)
				var h := rng.randf_range(6.0, 28.0)
				var cx: float = bx * 52 + o.x + rng.randf_range(-1.5, 1.5)
				var cz: float = bz * 52 + o.y + rng.randf_range(-1.5, 1.5)
				_building(Vector3(cx, 0, cz), Vector3(w, h, dep), rng)
				if rng.randf() < 0.5:
					ac_xf.append(d.xf(Vector3(cx + rng.randf_range(-w / 4, w / 4), h + 0.55, cz + rng.randf_range(-dep / 4, dep / 4)), rng.randf() * TAU))
				if h > 17.0 and rng.randf() < 0.6:
					antenna_xf.append(d.xf(Vector3(cx + w / 2 - 1.0, h + 1.5, cz + dep / 2 - 1.0)))
				if h > 9.0 and h < 21.0 and rng.randf() < 0.16:
					tower_spots.append(Vector4(cx, cz, h, w))
	add_child(d.make_multimesh(d.ac_mesh, d.ac_mat, ac_xf))
	add_child(d.make_multimesh(d.antenna_mesh, d.antenna_mat, antenna_xf))
	_build_props(rng, d, tower_spots)

func _road(pos: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := dressing.asphalt_mat.duplicate() as StandardMaterial3D
	if size.z > size.x:
		m.uv1_scale = Vector3(2.5, 60, 1)
	else:
		m.uv1_scale = Vector3(60, 2.5, 1)
	mi.material_override = m
	add_child(mi)

func _building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var d := dressing
	var body := StaticBody3D.new()
	body.position = Vector3(pos.x, 0, pos.z)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0, size.y / 2, 0)
	# facade texture with per-building UV scale so windows stay
	# roughly the same size whatever the footprint (texture: 6 cols
	# over ~10.8 units, 12 rows over ~22 units)
	var fm := d.facade_materials[rng.randi() % d.facade_materials.size()].duplicate() as StandardMaterial3D
	fm.uv1_scale = Vector3(maxf(size.x, size.z) / 10.8, size.y / 22.0, 1)
	mi.material_override = fm
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = size
	shape.shape = col
	shape.position = Vector3(0, size.y / 2, 0)
	body.add_child(shape)
	# roof slab: parapet trim + hides the stretched roof texture
	var roof := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = Vector3(size.x + 0.4, 0.3, size.z + 0.4)
	roof.mesh = rbm
	roof.position = Vector3(0, size.y + 0.15, 0)
	roof.material_override = d.roof_mat
	body.add_child(roof)
	# ground floor: dark storefront band + awning on most buildings
	if rng.randf() < 0.75:
		var band := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(size.x + 0.12, 1.15, size.z + 0.12)
		band.mesh = bbm
		band.position = Vector3(0, 0.58, 0)
		band.material_override = d.storefront_mat
		body.add_child(band)
		var awn := MeshInstance3D.new()
		var abm := BoxMesh.new()
		abm.size = Vector3(size.x + 0.55, 0.16, size.z + 0.55)
		awn.mesh = abm
		awn.position = Vector3(0, 2.28, 0)
		awn.material_override = d.awning_mats[rng.randi() % d.awning_mats.size()]
		body.add_child(awn)
	buildings.append(Rect2(pos.x - size.x / 2, pos.z - size.z / 2, size.x, size.z))
	add_child(body)

func _build_props(rng: RandomNumberGenerator, d: CityDressing, tower_spots: Array) -> void:
	# Rooftop water towers (a few, individual nodes): 4 legs, a
	# cylinder tank, a cone roof. tower_spots: Vector4(cx, cz, roof_y, w)
	var leg_m := BoxMesh.new()
	leg_m.size = Vector3(0.12, 1.4, 0.12)
	var tank_m := CylinderMesh.new()
	tank_m.top_radius = 0.95
	tank_m.bottom_radius = 0.95
	tank_m.height = 1.7
	tank_m.radial_segments = 10
	var cone_m := CylinderMesh.new()
	cone_m.top_radius = 0.0
	cone_m.bottom_radius = 1.15
	cone_m.height = 0.7
	cone_m.radial_segments = 10
	for t in tower_spots:
		var tw := Node3D.new()
		tw.position = Vector3(t.x, t.z, t.y)
		for lx in [-0.7, 0.7]:
			for lz in [-0.7, 0.7]:
				var leg := MeshInstance3D.new()
				leg.mesh = leg_m
				leg.position = Vector3(lx, 0.7, lz)
				leg.material_override = d.tower_mat
				tw.add_child(leg)
		var tank := MeshInstance3D.new()
		tank.mesh = tank_m
		tank.position = Vector3(0, 2.25, 0)
		tank.material_override = d.tower_mat
		tw.add_child(tank)
		var cone := MeshInstance3D.new()
		cone.mesh = cone_m
		cone.position = Vector3(0, 3.45, 0)
		cone.material_override = d.tower_roof_mat
		tw.add_child(cone)
		add_child(tw)
	# Streetlights: one side per segment, alternating, arm over the
	# road; skipped where a building swallowed the spot.
	var light_xf: Array = []
	var head_xf: Array = []
	for i in range(-2, 3):
		for k in range(6):
			var along := -97.5 + k * 39.0
			var side := 1.0 if (k + i) % 2 == 0 else -1.0
			# vertical road at x = i*52
			var vx := i * 52 + side * 5.9
			if _point_free(vx, along, 0.6):
				var ry := PI / 2.0 if side > 0.0 else -PI / 2.0
				light_xf.append(d.xf(Vector3(vx, 0, along), ry))
				head_xf.append(d.xf(Vector3(vx, 0, along), ry))
			# horizontal road at z = i*52
			var hz := i * 52 + side * 5.9
			if _point_free(along, hz, 0.6):
				var ry2 := PI if side > 0.0 else 0.0
				light_xf.append(d.xf(Vector3(along, 0, hz), ry2))
				head_xf.append(d.xf(Vector3(along, 0, hz), ry2))
	add_child(d.make_multimesh(d.streetlight_mesh, d.pole_mat, light_xf))
	# lamp heads: same instance transforms as the poles, with the
	# arm-end offset folded into each transform.
	var head_xf2: Array = []
	for t in head_xf:
		var local := Transform3D(Basis(), Vector3(0, 4.08, -1.45))
		head_xf2.append(t * local)
	add_child(d.make_multimesh(d.lamp_head_mesh, d.lamp_mat, head_xf2))
	# Traffic lights at the inner 3x3 intersections: pole + box in
	# one mesh; red/green lenses by (i+j) parity, dark lens elsewhere.
	var tl_xf: Array = []
	var red_xf: Array = []
	var green_xf: Array = []
	var dark_xf: Array = []
	for i in range(-1, 2):
		for j in range(-1, 2):
			var base := Vector3(i * 52 + 5.9, 0, j * 52 + 5.9)
			var ry := atan2(-(i * 52.0 - base.x), -(j * 52.0 - base.z))  # face the intersection
			var t := d.xf(base, ry)
			tl_xf.append(t)
			var ns_green := (i + j) % 2 == 0
			var lens_local := [Vector3(0, 3.56, -0.45), Vector3(0, 3.25, -0.45), Vector3(0, 2.94, -0.45)]
			if ns_green:
				green_xf.append(t * Transform3D(Basis(), lens_local[2]))
				dark_xf.append(t * Transform3D(Basis(), lens_local[0]))
			else:
				red_xf.append(t * Transform3D(Basis(), lens_local[0]))
				dark_xf.append(t * Transform3D(Basis(), lens_local[2]))
			dark_xf.append(t * Transform3D(Basis(), lens_local[1]))
	add_child(d.make_multimesh(d.traffic_mesh, d.traffic_box_mat, tl_xf))
	add_child(d.make_multimesh(d.lens_mesh, d.lens_red_mat, red_xf))
	add_child(d.make_multimesh(d.lens_mesh, d.lens_green_mat, green_xf))
	add_child(d.make_multimesh(d.lens_mesh, d.lens_dark_mat, dark_xf))
	# Trees at cluster corners (checked against buildings)
	var trunk_xf: Array = []
	var fol_xf: Array = []
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			for corner in [Vector2(-17, -17), Vector2(17, -17), Vector2(-17, 17), Vector2(17, 17)]:
				if rng.randf() < 0.45:
					continue
				var tx: float = bx * 52 + corner.x + rng.randf_range(-2, 2)
				var tz: float = bz * 52 + corner.y + rng.randf_range(-2, 2)
				if not _point_free(tx, tz, 1.2):
					continue
				trunk_xf.append(d.xf(Vector3(tx, 0.65, tz)))
				var sc := rng.randf_range(0.85, 1.45)
				fol_xf.append(d.xf(Vector3(tx, 2.1 * sc, tz), rng.randf() * TAU, sc))
	add_child(d.make_multimesh(d.trunk_mesh, d.trunk_mat, trunk_xf))
	add_child(d.make_multimesh(d.foliage_mesh, d.foliage_mat, fol_xf))
	# Dumpsters: individual nodes (body + ajar lid) near clusters
	var dump_m := BoxMesh.new()
	dump_m.size = Vector3(2.0, 1.15, 1.1)
	var lid_m := BoxMesh.new()
	lid_m.size = Vector3(2.0, 0.08, 1.1)
	var placed := 0
	var guard := 0
	while placed < 10 and guard < 60:
		guard += 1
		var dx := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		var dz := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		if not _point_free(dx, dz, 1.6):
			continue
		var dn := Node3D.new()
		dn.position = Vector3(dx, 0, dz)
		dn.rotation.y = rng.randf() * TAU
		var db := MeshInstance3D.new()
		db.mesh = dump_m
		db.position = Vector3(0, 0.58, 0)
		db.material_override = d.dumpster_mat
		dn.add_child(db)
		var dl := MeshInstance3D.new()
		dl.mesh = lid_m
		dl.position = Vector3(0, 1.22, -0.2)
		dl.rotation.x = -0.35
		dl.material_override = d.dumpster_lid_mat
		dn.add_child(dl)
		add_child(dn)
		placed += 1
	# Crates + barriers scattered on pads (MultiMesh)
	var crate_xf: Array = []
	var barrier_xf: Array = []
	for i in range(26):
		var px := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		var pz := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		if not _point_free(px, pz, 1.0):
			continue
		if i % 3 == 0:
			barrier_xf.append(d.xf(Vector3(px, 0.43, pz), rng.randf() * TAU))
		else:
			crate_xf.append(d.xf(Vector3(px, 0.38, pz), rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
	add_child(d.make_multimesh(d.crate_mesh, d.crate_mat, crate_xf))
	add_child(d.make_multimesh(d.barrier_mesh, d.barrier_mat, barrier_xf))
	# Benches near the centre block (bus-stop furniture)
	var seat_m := BoxMesh.new()
	seat_m.size = Vector3(1.9, 0.09, 0.5)
	var back_m := BoxMesh.new()
	back_m.size = Vector3(1.9, 0.5, 0.08)
	for spot in [Vector3(-8, 0, -14), Vector3(12, 0, -14), Vector3(-14, 0, 10), Vector3(16, 0, 12), Vector3(-6, 0, 18), Vector3(8, 0, 20)]:
		var bn := Node3D.new()
		bn.position = spot
		bn.rotation.y = rng.randf_range(-0.4, 0.4)
		var seat := MeshInstance3D.new()
		seat.mesh = seat_m
		seat.position = Vector3(0, 0.5, 0)
		seat.material_override = d.bench_mat
		bn.add_child(seat)
		var back := MeshInstance3D.new()
		back.mesh = back_m
		back.position = Vector3(0, 0.8, 0.24)
		back.material_override = d.bench_mat
		bn.add_child(back)
		add_child(bn)

# ---------- Debug: windowed screenshot for visual checks ----------
func _take_screenshot() -> void:
	# Used with a real (Xvfb) display, NOT headless: lets a human or
	# the assistant eyeball the dressed city. Saves + quits.
	for i in range(100):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "user://gate3d_shot.png"
	img.save_png(path)
	print("SCREENSHOT: ", ProjectSettings.globalize_path(path), " ", img.get_size())
	get_tree().quit()

# ---------- HUD ----------
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.09, 0.07, 0.17, 0.85)  # Midnight Circle panel
	panel.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.49, 1.0, 0.95)  # violet C77DFF
	fill.set_corner_radius_all(4)
	hud_hp = ProgressBar.new()
	hud_hp.position = Vector2(10, 10)
	hud_hp.custom_minimum_size = Vector2(220, 18)
	hud_hp.size = Vector2(220, 18)
	hud_hp.max_value = player.max_hp
	hud_hp.value = player.hp
	hud_hp.show_percentage = false
	hud_hp.add_theme_stylebox_override("background", panel)
	hud_hp.add_theme_stylebox_override("fill", fill)
	layer.add_child(hud_hp)
	hud_weapon = Label.new()
	hud_weapon.position = Vector2(10, 34)
	hud_weapon.add_theme_font_size_override("font_size", 16)
	layer.add_child(hud_weapon)
	hud_combo = Label.new()
	hud_combo.position = Vector2(10, 58)
	hud_combo.add_theme_font_size_override("font_size", 16)
	hud_combo.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))  # candle gold FFD479
	layer.add_child(hud_combo)
	hud_cash = Label.new()
	hud_cash.position = Vector2(1020, 8)
	hud_cash.add_theme_font_size_override("font_size", 18)
	hud_cash.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	layer.add_child(hud_cash)
	hud_stars = Label.new()
	hud_stars.position = Vector2(1020, 34)
	hud_stars.add_theme_font_size_override("font_size", 20)
	hud_stars.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	layer.add_child(hud_stars)
	var help := Label.new()
	help.position = Vector2(10, 660)
	help.add_theme_font_size_override("font_size", 14)
	help.text = "WASD move/drive · mouse aims · LMB fire · 1-9 / Q weapons · E enter/exit car · B black market · hold T to talk"
	layer.add_child(help)
	var cross := Label.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-7, -16)
	cross.add_theme_font_size_override("font_size", 20)
	cross.text = "+"
	layer.add_child(cross)
	hud_center = Label.new()
	hud_center.position = Vector2(490, 300)
	hud_center.add_theme_font_size_override("font_size", 42)
	hud_center.add_theme_color_override("font_color", Color(1.0, 0.33, 0.44))  # ember FF5370
	hud_center.visible = false
	layer.add_child(hud_center)
	# Gate 3D-2: minimap, bottom-right
	minimap = Minimap.new()
	minimap.main = self
	minimap.position = Vector2(1090, 522)
	layer.add_child(minimap)
	_build_shop(layer)

# ---------- Black Market (Gate 3D-2) ----------
func _build_shop(layer: CanvasLayer) -> void:
	shop_panel = PanelContainer.new()
	shop_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # clickable while paused
	shop_panel.position = Vector2(400, 120)
	shop_panel.custom_minimum_size = Vector2(480, 0)
	shop_panel.visible = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.09, 0.07, 0.17, 0.97)  # Midnight Circle panel
	bg.set_corner_radius_all(6)
	bg.set_content_margin_all(14)
	shop_panel.add_theme_stylebox_override("panel", bg)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	shop_panel.add_child(vbox)
	var title := Label.new()
	title.text = "BLACK MARKET"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.47))
	vbox.add_child(title)
	shop_cash_label = Label.new()
	shop_cash_label.add_theme_font_size_override("font_size", 16)
	shop_cash_label.add_theme_color_override("font_color", Color(0.82, 0.85, 0.96))
	vbox.add_child(shop_cash_label)
	for def in upgrade_defs:
		var uid := str(def.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_l := Label.new()
		name_l.text = str(def.get("name", uid))
		name_l.custom_minimum_size = Vector2(140, 0)
		name_l.add_theme_font_size_override("font_size", 16)
		row.add_child(name_l)
		var lvl_l := Label.new()
		lvl_l.custom_minimum_size = Vector2(70, 0)
		lvl_l.add_theme_font_size_override("font_size", 16)
		lvl_l.add_theme_color_override("font_color", Color(0.78, 0.49, 1.0))
		row.add_child(lvl_l)
		var desc_l := Label.new()
		desc_l.text = str(def.get("desc", ""))
		desc_l.custom_minimum_size = Vector2(150, 0)
		desc_l.add_theme_font_size_override("font_size", 13)
		desc_l.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
		row.add_child(desc_l)
		var buy_b := Button.new()
		buy_b.custom_minimum_size = Vector2(96, 0)
		buy_b.add_theme_font_size_override("font_size", 15)
		buy_b.pressed.connect(_on_buy_pressed.bind(uid))
		row.add_child(buy_b)
		vbox.add_child(row)
		shop_rows[uid] = {"level": lvl_l, "buy": buy_b}
	var hint := Label.new()
	hint.text = "Keys 1-5 buy · B or Esc closes"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.70, 0.72, 0.82))
	vbox.add_child(hint)
	layer.add_child(shop_panel)

func _on_buy_pressed(uid: String) -> void:
	buy_upgrade(uid)
	refresh_shop()

func toggle_shop(open: bool) -> void:
	shop_open = open
	shop_panel.visible = open
	get_tree().paused = open
	if open:
		refresh_shop()

func refresh_shop() -> void:
	if shop_panel == null:
		return
	shop_cash_label.text = "Cash: $%d" % cash
	for uid in shop_rows:
		var row: Dictionary = shop_rows[uid]
		var lvl: Label = row["level"]
		lvl.text = "Lv %d" % int(upgrade_levels.get(uid, 0))
		var buy: Button = row["buy"]
		var cost := upgrade_cost(uid)
		buy.text = "BUY $%d" % cost
		buy.disabled = cash < cost

# ---------- Upgrades (data/upgrades.json) ----------
func upgrade_level(uid: String) -> int:
	return int(upgrade_levels.get(uid, 0))

func upgrade_cost(uid: String) -> int:
	var def: Dictionary = upgrade_by_id.get(uid, {})
	if def.is_empty():
		return 0
	# data: floor(base_cost * 1.4 ^ current_level)
	return int(floor(float(def.get("base_cost", 0)) * pow(1.4, float(upgrade_level(uid)))))

func damage_mult() -> float:
	return 1.0 + 0.15 * float(upgrade_level("damage"))

func firerate_mult() -> float:
	return 1.0 + 0.10 * float(upgrade_level("firerate"))

func regen_stat() -> float:
	return 0.3 * float(upgrade_level("regen"))

func apply_upgrades() -> void:
	if player == null:
		return
	var new_max := base_hp_data + 25.0 * float(upgrade_level("hp"))
	var delta := new_max - player.max_hp
	player.max_hp = new_max
	if delta > 0.0:
		player.hp = minf(player.hp + delta, new_max)
	# 2D speed: 3.8 + 0.4/level; 3D base is 5.0 (ratio 5.0/3.8, the
	# same adaptation as every other speed in this port)
	player.walk_speed = 5.0 * (3.8 + 0.4 * float(upgrade_level("speed"))) / 3.8

func buy_upgrade(uid: String) -> bool:
	if not upgrade_by_id.has(uid):
		return false
	var cost := upgrade_cost(uid)
	if cash < cost:
		return false
	cash -= cost
	upgrade_levels[uid] = upgrade_level(uid) + 1
	apply_upgrades()
	save_game()
	play_sfx("pickup", -10.0)
	refresh_hud()
	return true

# ---------- Save / load (user://godot_save.json) ----------
# Rule (also in gate3d/README.md): cash, total score, upgrade levels
# and the unlocked-weapon set are the persistent profile. BUSTED
# resets the RUN (wanted, enemies, position) via scene reload, but
# cash/score/upgrades carry over — the HTML saved progress the same
# way. Autosave: on purchase, every 1800 physics frames, on BUSTED.
func save_game() -> void:
	var payload := {
		"version": 1,
		"cash": cash,
		"score": score,
		"upgrades": upgrade_levels.duplicate(),
		"unlocked_weapons": unlocked_weapons.duplicate(),
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("GODOT: cannot write save file %s" % save_path)
		return
	f.store_string(JSON.stringify(payload))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var p: Dictionary = parsed
	cash = maxi(0, int(p.get("cash", 0)))
	score = maxi(0, int(p.get("score", 0)))
	var ups: Dictionary = p.get("upgrades", {})
	for uid in upgrade_levels:
		if ups.has(uid):
			upgrade_levels[uid] = maxi(0, int(ups[uid]))
	var unl: Array = p.get("unlocked_weapons", [])
	if not unl.is_empty():
		unlocked_weapons.clear()
		for idx in unl:
			var i := int(idx)
			if i >= 0 and i < weapons.size() and not unlocked_weapons.has(i):
				unlocked_weapons.append(i)

# ---------- Synthesized SFX (sfx.gd) ----------
func _setup_sfx() -> void:
	sfx_streams = {
		"gunshot": SfxSynth.gunshot(),
		"explosion": SfxSynth.explosion(),
		"pickup": SfxSynth.pickup(),
		"hurt": SfxSynth.hurt(),
		"busted": SfxSynth.busted(),
	}
	var holder := Node.new()
	holder.name = "SFX"
	add_child(holder)
	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS  # shop chime plays while paused
		p.bus = "Master"
		holder.add_child(p)
		sfx_players.append(p)

func play_sfx(sname: String, vol_db: float = -12.0, pitch: float = 1.0) -> void:
	if not sfx_streams.has(sname):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = sfx_streams[sname]
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

func refresh_hud() -> void:
	if player == null or hud_hp == null:
		return
	hud_hp.max_value = player.max_hp
	hud_hp.value = maxi(0, int(player.hp))
	hud_weapon.text = str(weapons[player.weapon_index].get("name", "")) if weapons.size() > 0 else ""
	hud_cash.text = "$%d   Score %d" % [cash, score]
	var stars := ""
	for i in range(6):
		stars += "★" if i < floori(wanted_level) else "☆"
	hud_stars.text = stars
	if combo_count > 1:
		hud_combo.text = "COMBO x%.1f (%d)" % [minf(5.0, 1.0 + combo_count * 0.5), combo_count]
	else:
		hud_combo.text = ""

# ---------- Wanted / combo (mirrors scripts/main.gd) ----------
func add_wanted(amt: float) -> void:
	wanted_level = minf(6.0, wanted_level + amt)
	frames_since_crime = 0
	refresh_hud()

func add_combo() -> float:
	combo_count += 1
	combo_frames = int(data.get("combo", {}).get("window_frames", 120))
	if combo_count > 1:
		return minf(5.0, 1.0 + combo_count * 0.5)
	return 1.0

func stars_now() -> int:
	return mini(floori(wanted_level), int(wanted_cfg.get("max_stars", 6)))

func enemy_cap(stars: int) -> int:
	var caps: Array = wanted_cfg.get("max_active_enemies_by_star", [0, 3, 6, 10, 15, 22, 30])
	return int(caps[mini(stars, caps.size() - 1)])

func spawn_type(stars: int) -> String:
	var types: Array = wanted_cfg.get("spawn_type_by_star_index_0_based", ["cop"])
	return str(types[mini(maxi(stars - 1, 0), types.size() - 1)])

func try_spawn_enemy(force: bool = false) -> bool:
	var stars := stars_now()
	if stars <= 0:
		return false
	if enemies.size() >= enemy_cap(stars):
		return false
	if not force and randf() >= 0.02 + stars * 0.005:
		return false
	_spawn_enemy(spawn_type(stars), _spawn_position())
	return true

func _spawn_position() -> Vector3:
	# 2D spawns on a 500-900 unit ring around the player; /15 -> 33-60.
	# Ring pushed out a little so spawns land outside the camera's
	# immediate view in the smaller 3D city; buildings are avoided.
	for attempt in range(12):
		var ang := randf() * TAU
		var d := 42.0 + randf() * 22.0
		var p := player.global_position + Vector3(cos(ang), 0, sin(ang)) * d
		p.x = clamp(p.x, -112, 112)
		p.z = clamp(p.z, -112, 112)
		p.y = 0.2
		var inside := false
		for r in buildings:
			if r.grow(2.0).has_point(Vector2(p.x, p.z)):
				inside = true
				break
		if not inside:
			return p
	return Vector3(60, 0.2, 60)

func _spawn_enemy(kind: String, pos: Vector3) -> void:
	var e: Node3D
	if kind == "tank":
		e = Tank3D.new()
	else:
		e = Enemy3D.new()
	e.setup(kind, enemy_stats.get(kind, {}))
	e.position = pos
	e.main = self
	add_child(e)
	enemies.append(e)

# ---------- Shooting ----------
func player_shoot_3d(driveby: bool) -> void:
	if state != "PLAYING" or player == null or player.dead or camera == null:
		return
	# Gate 3D-2: Black Market multipliers — damage x(1 + 0.15/level),
	# cooldown / (1 + 0.10/level), from data/upgrades.json.
	var weapon: Dictionary = (driveby_weapon if driveby else weapons[player.weapon_index]).duplicate()
	weapon["dmg"] = float(weapon.get("dmg", 10)) * damage_mult()
	var rate := float(weapon.get("rate_frames", 8)) / firerate_mult()
	var range3d := float(weapon.get("range", 400)) / SCALE
	var shooter: Node3D = player.driving if driveby and player.driving != null else player
	var muzzle := shooter.global_position + Vector3(0, 1.25, 0)
	if not driveby:
		player.rotation.y = cam_yaw  # face where the camera aims
	if weapon.get("melee", false):
		_melee_attack(weapon)
		player.fire_cooldown = rate
		return
	play_sfx("gunshot", -13.0, randf_range(0.92, 1.08) * (1.7 if str(weapon.get("name", "")) == "LASER" else 1.0))
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [player.get_rid()]
	if player.driving != null:
		exclude.append(player.driving.get_rid())
	var cam_from := camera.global_position
	var cam_dir := -camera.global_transform.basis.z
	var spread := float(weapon.get("spread", 0.0))
	var color := Color(weapon.get("color", "#ffdd88"))
	if weapon.get("rocket", false):
		var aim := _ray_end(space, cam_from, cam_dir, range3d, exclude)
		var dir := (aim - muzzle).normalized()
		var b := Bullet3D.new()
		add_child(b)
		b.setup(muzzle, dir * 40.0, float(weapon.get("dmg", 200)), true, true, float(weapon.get("range", 800)) / 10.0, player, self, color)
		_spawn_flash(muzzle, color)
		player.fire_cooldown = rate
		player.fire_flap_time = 0.15
		return
	for i in range(int(weapon.get("count", 1))):
		var dir_i := cam_dir
		if spread > 0.0:
			dir_i = (cam_dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * spread).normalized()
		var aim := _ray_end(space, cam_from, dir_i, range3d, exclude)
		var q := PhysicsRayQueryParameters3D.create(muzzle, aim, 7, exclude)
		var hit := space.intersect_ray(q)
		var end := aim
		if not hit.is_empty():
			end = hit.position
			_apply_hitscan_hit(hit.collider, weapon)
		_spawn_tracer(muzzle, end, color)
	_spawn_flash(muzzle, color)
	player.fire_cooldown = rate
	player.fire_flap_time = 0.15

func _ray_end(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, dist: float, exclude: Array[RID]) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * dist, 7, exclude)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	return from + dir * dist

func _apply_hitscan_hit(collider: Object, weapon: Dictionary) -> void:
	var dmg := float(weapon.get("dmg", 10))
	if collider is Ped3D:
		if not collider.dead:
			kill_ped(collider, false)
	elif collider is Enemy3D or collider is Tank3D:
		if not collider.dead:
			collider.take_damage(dmg)
	elif collider is Car3D:
		if not collider.dead and collider != player.driving:
			collider.take_damage(dmg)
	# buildings / ground: impact only

func _melee_attack(weapon: Dictionary) -> void:
	# 2D fists: a hit point 28 units ahead, radii 22/25/30 per target.
	var dmg := float(weapon.get("dmg", 12))
	var origin := player.global_position
	var facing := -player.global_transform.basis.z
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and origin.distance_to(p.global_position) < 2.6 and facing.dot((p.global_position - origin).normalized()) > 0.2:
			kill_ped(p, false)
	for e in enemies:
		if not e.dead and origin.distance_to(e.global_position) < 2.8 and facing.dot((e.global_position - origin).normalized()) > 0.2:
			e.take_damage(dmg)
	for c in cars:
		if not c.dead and c != player.driving and origin.distance_to(c.global_position) < 3.4 and facing.dot((c.global_position - origin).normalized()) > 0.2:
			c.take_damage(dmg)
	player.fire_flap_time = 0.15

func enemy_shoot_3d(e: Node3D) -> void:
	if player == null:
		return
	var from: Vector3 = e.gun_position()
	var target := player.global_position + Vector3(0, 1.0, 0)
	var dir := (target - from).normalized()
	dir = (dir + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.15).normalized()  # 2D aim jitter
	var b := Bullet3D.new()
	add_child(b)
	b.setup(from, dir * 72.0, float(e.dmg), false, false, float(e.bullet_life_frames), e, self, Color(1, 0.27, 0.27))

func resolve_bullet3d(b: Bullet3D) -> void:
	# Same order as the 2D resolve_bullet: cars, peds, enemies, player.
	# Hit distances are the 2D radii / 15, measured to body centres.
	var pos := b.global_position
	for c in cars:
		if c.dead:
			continue
		if b.is_player and player != null and player.driving == c:
			continue
		if pos.distance_to(c.global_position + Vector3(0, 0.6, 0)) < 1.9:
			c.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 110, b.damage * 0.8, b)
			b.queue_free()
			return
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and pos.distance_to(p.global_position + Vector3(0, 0.9, 0)) < 0.95:
			kill_ped(p, false)
			if b.is_rocket:
				explode_3d(pos, 80, b.damage * 0.5, b)
			b.queue_free()
			return
	for e in enemies:
		if not e.dead and e != b.shooter and pos.distance_to(e.global_position + Vector3(0, 0.9, 0)) < 1.2:
			e.take_damage(b.damage)
			if b.is_rocket:
				explode_3d(pos, 90, b.damage * 0.6, b)
			b.queue_free()
			return
	if not b.is_player and player != null and not player.dead and player.driving == null:
		if pos.distance_to(player.global_position + Vector3(0, 0.9, 0)) < 1.05:
			player.take_damage(b.damage * 0.5)  # 2D halves enemy bullet damage to the player
			b.queue_free()

func explode_3d(pos: Vector3, radius2d: float, dmg: float, source: Object) -> void:
	# 2D explode(): cars/enemies take dmg * (1 - d/r) * 1.5, peds die
	# within r * 0.8, the player takes dmg * 0.4 within r * 0.7.
	var radius := radius2d / SCALE
	_spawn_explosion_fx(pos, radius)
	if frame_counter - last_boom_sfx_frame > 6:  # chain kills: one boom per beat
		last_boom_sfx_frame = frame_counter
		play_sfx("explosion", -9.0, randf_range(0.9, 1.05))
	for c in cars:
		if not c.dead and c != source and pos.distance_to(c.global_position) < radius:
			c.take_damage(dmg * (1.0 - pos.distance_to(c.global_position) / radius) * 1.5)
	for e in enemies:
		if not e.dead and e != source and pos.distance_to(e.global_position) < radius:
			e.take_damage(dmg * (1.0 - pos.distance_to(e.global_position) / radius) * 1.5)
	for p in get_tree().get_nodes_in_group("peds3d"):
		if not p.dead and pos.distance_to(p.global_position) < radius * 0.8:
			kill_ped(p, false)
	if player != null and not player.dead and pos.distance_to(player.global_position) < radius * 0.7:
		player.take_damage(dmg * 0.4)

# ---------- Deaths / economy (mirrors scripts/main.gd) ----------
func kill_ped(p: Ped3D, run_over: bool) -> void:
	if p.dead:
		return
	p.die()
	var mult := add_combo()
	var base := float(ped_stats.get("cash_runover", 15) if run_over else ped_stats.get("cash_on_kill", 10))
	cash += int(base * mult)
	score += int(float(ped_stats.get("score", 20)) * mult)
	add_wanted(0.15)
	spawn_pickup_3d(p.global_position, "cash")
	refresh_hud()

func kill_car(c: Car3D) -> void:
	if c.dead:
		return
	c.dead = true
	c.speed = 0.0
	c.set_dead_visual()
	cars_destroyed += 1
	add_wanted(0.3)
	var mult := add_combo()
	cash += int(float(car_stats.get("cash_on_destroy", 25)) * mult)
	score += int(float(car_stats.get("score", 50)) * mult)
	if player != null and player.driving == c:
		_exit_car()
	explode_3d(c.global_position, 90, 80, c)
	spawn_pickup_3d(c.global_position, "cash" if randf() < 0.5 else "health")
	refresh_hud()
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void:
		if is_instance_valid(c):
			cars.erase(c)
			c.queue_free())

func kill_enemy(e: Node3D) -> void:
	if e.dead:
		return
	e.dead = true
	kills += 1
	add_wanted(0.1)
	var mult := add_combo()
	var stats: Dictionary = enemy_stats.get(e.kind, {})
	cash += int(float(stats.get("cash_on_kill", 20)) * mult)
	score += int(float(stats.get("score", 100)) * mult)
	explode_3d(e.global_position, 120 if e.kind == "tank" else 60, 100 if e.kind == "tank" else 40, e)
	if e.kind == "tank":
		spawn_pickup_3d(e.global_position, "health")
	elif randf() < 0.25:
		# Gate 3D-1 adaptation (labelled): the 2D code has no weapon
		# pickups; a quarter of non-tank enemy drops are weapons.
		spawn_pickup_3d(e.global_position, "weapon")
	else:
		spawn_pickup_3d(e.global_position, "cash")
	enemies.erase(e)
	e.queue_free()
	refresh_hud()

func spawn_pickup_3d(pos: Vector3, kind: String) -> void:
	if randf() >= 0.3:  # HTML spawnPickup gate, kept from the 2D code
		return
	var pk := Pickup3D.new()
	pk.kind = kind
	pk.position = Vector3(pos.x, 0.55, pos.z)
	add_child(pk)

# ---------- Player events ----------
func on_player_damaged() -> void:
	if frame_counter - last_hurt_sfx_frame > 12:
		last_hurt_sfx_frame = frame_counter
		play_sfx("hurt", -12.0)
	refresh_hud()

func on_player_death() -> void:
	if state != "PLAYING":
		return
	state = "GAMEOVER"
	player.dead = true
	if player.driving != null:
		_exit_car()
	explode_3d(player.global_position, 80, 50, player)
	save_game()  # profile (cash/score/upgrades) survives the BUSTED
	play_sfx("busted", -10.0)
	hud_center.text = "BUSTED\nScore %d  Cash $%d" % [score, cash]
	hud_center.visible = true
	await get_tree().create_timer(2.5).timeout
	get_tree().reload_current_scene()

# ---------- Cars (Gate 3D-0 behaviour, unchanged) ----------
func _try_enter_car() -> void:
	var best: Car3D = null
	var best_d := 4.0
	for car in cars:
		if car.dead:
			continue
		var d := player.global_position.distance_to(car.global_position)
		if d < best_d:
			best_d = d
			best = car
	if best != null:
		player.driving = best
		best.driven = true
		player.visible = false
		player.set_physics_process(false)
		if player.body_shape != null:
			player.body_shape.disabled = true
		refresh_hud()

func _exit_car() -> void:
	var car := player.driving
	car.driven = false
	player.driving = null
	player.global_position = car.global_position + car.global_transform.basis.x * 2.2 + Vector3(0, 0.3, 0)
	player.visible = true
	player.set_physics_process(true)
	if player.body_shape != null:
		player.body_shape.disabled = false
	refresh_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Gate 3D-2: Black Market keys take over while the shop is open
		if shop_open:
			if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
				toggle_shop(false)
			elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
				var sidx: int = event.keycode - KEY_1
				if sidx < upgrade_defs.size():
					buy_upgrade(str(upgrade_defs[sidx].get("id", "")))
					refresh_shop()
			return
		if event.keycode == KEY_B:
			if state == "PLAYING" and player != null and not player.dead:
				toggle_shop(true)
			return
		if event.keycode == KEY_E:
			if player != null and player.driving != null:
				_exit_car()
			elif player != null:
				_try_enter_car()
		elif event.keycode == KEY_Q:
			if player != null and weapons.size() > 0:
				player.weapon_index = (player.weapon_index + 1) % weapons.size()
				player.refresh_gun(weapons[player.weapon_index])
				refresh_hud()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if player != null and idx < weapons.size():
				player.weapon_index = idx
				player.refresh_gun(weapons[player.weapon_index])
				refresh_hud()

# ---------- Per-frame ----------
func _physics_process(_delta: float) -> void:
	if player == null or state != "PLAYING" or shop_open:
		return
	frame_counter += 1
	# Gate 3D-2: periodic autosave (30 s of physics frames)
	if not autotest:
		save_frames += 1
		if save_frames >= 1800:
			save_frames = 0
			save_game()
	# Adrenaline (data/upgrades.json): regen only while wanted == 0,
	# + regen_stat * 0.05 hp/frame (the rule as written in the data).
	if regen_stat() > 0.0 and wanted_level == 0.0 and not player.dead and player.hp < player.max_hp:
		player.hp = minf(player.max_hp, player.hp + regen_stat() * 0.05)
	# The cooldown ticks EVERY physics frame in both modes.
	# (HTML bug fixed here, as in Gate 0: in-car it never ticked.)
	if player.fire_cooldown > 0.0:
		player.fire_cooldown -= 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and player.fire_cooldown <= 0.0 and not player.dead:
		player_shoot_3d(player.driving != null)
	if combo_frames > 0:
		combo_frames -= 1
		if combo_frames <= 0:
			combo_count = 0
	if wanted_level > 0.0:
		frames_since_crime += 1
		var decay := int(wanted_cfg.get("decay_frames_without_crime", 600))
		if frames_since_crime > decay:
			frames_since_crime = 0
			wanted_level = maxf(0.0, wanted_level - 1.0)
			refresh_hud()
		if not autotest:
			try_spawn_enemy()
	# run-overs by the driven car (2D: any car moving fast; in the 3D
	# greybox only the player's car is driven, so it is the checker)
	if player.driving != null and abs(player.driving.speed) > 6.0:
		var car := player.driving
		for p in get_tree().get_nodes_in_group("peds3d"):
			if not p.dead and car.global_position.distance_to(p.global_position) < 1.8:
				kill_ped(p, true)
	# pickups
	for pk in get_tree().get_nodes_in_group("pickups3d"):
		if not pk.collected and player.global_position.distance_to(pk.global_position) < 1.6:
			pk.collected = true
			play_sfx("pickup", -13.0)
			if pk.kind == "health":
				player.hp = minf(player.max_hp, player.hp + 30.0)
			elif pk.kind == "weapon":
				if weapons.size() > 1:
					player.weapon_index = randi_range(1, weapons.size() - 1)
					player.refresh_gun(weapons[player.weapon_index])
					if not unlocked_weapons.has(player.weapon_index):
						unlocked_weapons.append(player.weapon_index)
			else:
				cash += 15
			pk.queue_free()
			refresh_hud()
	refresh_hud()

func _process(delta: float) -> void:
	if shop_open:
		return
	_update_fx(delta)
	if player == null or camera == null or autotest:
		return
	var actor: Node3D = player.driving if player.driving != null else player
	if player.driving != null:
		player.global_position = player.driving.global_position + Vector3(0, 0.3, 0)
	# follow camera: behind + above the actor, yaw lerps to the actor's
	var actor_yaw := actor.global_transform.basis.get_euler().y
	cam_yaw = lerp_angle(cam_yaw, actor_yaw, delta * 4.0)
	var back := Vector3(sin(cam_yaw), 0, cos(cam_yaw))  # behind a -Z-facing actor is +Z in its yaw frame
	var dist := 9.0 if player.driving != null else 6.5
	var height := 4.0 if player.driving != null else 3.0
	var target_pos := actor.global_position + back * dist + Vector3(0, height, 0)
	camera.global_position = camera.global_position.lerp(target_pos, delta * 8.0)
	camera.look_at(actor.global_position + Vector3(0, 1.4, 0), Vector3.UP)

# ---------- Transient visuals (tracers / flashes / explosions) ----------
func _fx_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	return m

func _spawn_tracer(from: Vector3, to: Vector3, color: Color) -> void:
	var len := from.distance_to(to)
	if len < 0.1:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, len)
	mi.mesh = bm
	mi.material_override = _fx_material(Color(color, 0.85))
	add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP)
	fx.append({"node": mi, "ttl": 0.06, "max": 0.06, "grow": 0.0})

func _spawn_flash(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.material_override = _fx_material(Color(1, 0.9, 0.5, 0.95))
	mi.position = pos
	add_child(mi)
	fx.append({"node": mi, "ttl": 0.05, "max": 0.05, "grow": 0.0})

func _spawn_explosion_fx(pos: Vector3, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = _fx_material(Color(1, 0.5, 0, 0.75))
	mi.position = pos + Vector3(0, 0.6, 0)
	add_child(mi)
	fx.append({"node": mi, "ttl": 0.35, "max": 0.35, "grow": radius})

func _update_fx(delta: float) -> void:
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		f["ttl"] = float(f["ttl"]) - delta
		var node: MeshInstance3D = f["node"]
		if float(f["ttl"]) <= 0.0:
			node.queue_free()
			fx.remove_at(i)
			continue
		var frac := float(f["ttl"]) / float(f["max"])
		var grow := float(f["grow"])
		if grow > 0.0:
			var s := grow * (1.0 - frac)
			node.scale = Vector3(s, s, s)
		var mat := node.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.85 * frac if grow == 0.0 else 0.75 * frac

# ---------- Autotest (--autotest) ----------
func _run_autotest() -> void:
	# Exercises the REAL fire / spawn / economy paths headlessly and
	# prints AUTOTEST PASS / AUTOTEST FAIL lines. Camera follow is
	# disabled while this runs (see _process); the camera is placed
	# by hand so the camera-ray shots are deterministic.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var fails: Array[String] = []
	player.hp = 100000.0  # test scaffolding: survive stray enemy fire
	player.max_hp = 100000.0
	# Park the ambient peds in a corner so the firing line is clean.
	for p in get_tree().get_nodes_in_group("peds3d"):
		p.set_physics_process(false)
		p.global_position = Vector3(100, 0.2, 100)

	# --- 1. SMG kills a ped; cash + score + combo move by the data ---
	player.weapon_index = 3  # SMG
	player.refresh_gun(weapons[3])
	var ped := Ped3D.new()
	ped.main = self
	add_child(ped)
	ped.set_physics_process(false)
	ped.global_position = player.global_position + Vector3(0, 0, -6)
	camera.global_position = player.global_position + Vector3(0, 2.2, 5)
	camera.look_at(ped.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	var cash0 := cash
	var score0 := score
	var shots := 0
	while not ped.dead and shots < 40:
		player.fire_cooldown = 0.0
		player_shoot_3d(false)
		shots += 1
		await get_tree().physics_frame
	if not ped.dead:
		fails.append("SMG did not kill the ped after %d shots" % shots)
	if cash != cash0 + 10:
		fails.append("ped kill cash: expected %d, got %d" % [cash0 + 10, cash])
	if score != score0 + 20:
		fails.append("ped kill score: expected %d, got %d" % [score0 + 20, score])
	if combo_count < 1:
		fails.append("combo did not increment on ped kill (count=%d)" % combo_count)

	# --- 2. SMG damages, then kills, a cop ---
	_spawn_enemy("cop", player.global_position + Vector3(0, 0, -10))
	var cop = enemies[enemies.size() - 1]
	camera.look_at(cop.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	var cop_hp0: float = cop.hp
	shots = 0
	var saw_damage := false
	var cop_died := false
	while shots < 60:
		if not is_instance_valid(cop):
			cop_died = true
			break
		if cop.dead:
			cop_died = true
			break
		player.fire_cooldown = 0.0
		player_shoot_3d(false)
		shots += 1
		if is_instance_valid(cop) and cop.hp < cop_hp0:
			saw_damage = true
		await get_tree().physics_frame
	if is_instance_valid(cop) and cop.dead:
		cop_died = true
	if not is_instance_valid(cop):
		cop_died = true  # kill_enemy freed it — that IS the death
	if not saw_damage:
		fails.append("SMG never damaged the cop (hp stuck at %f)" % cop_hp0)
	if not cop_died:
		fails.append("SMG did not kill the cop after %d shots" % shots)
	if combo_count < 2:
		fails.append("combo did not reach 2 after two kills (count=%d)" % combo_count)

	# --- 3. Wanted: float storage, floor stars, caps, spawn types ---
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	wanted_level = 0.0
	add_wanted(1.4)
	if floori(wanted_level) != 1:
		fails.append("floor(1.4) gave %d stars, expected 1" % floori(wanted_level))
	if enemy_cap(1) != 3:
		fails.append("cap at 1 star is %d, expected 3" % enemy_cap(1))
	if enemy_cap(3) != 10:
		fails.append("cap at 3 stars is %d, expected 10" % enemy_cap(3))
	var spawned := 0
	for i in range(5):
		if try_spawn_enemy(true):
			spawned += 1
	if spawned != 3:
		fails.append("forced spawns at 1 star: expected 3 (cap), got %d" % spawned)
	for e in enemies:
		if e.kind != "cop":
			fails.append("1-star spawn kind is %s, expected cop" % e.kind)
	if spawn_type(3) != "swat":
		fails.append("spawn_type(3) is %s, expected swat" % spawn_type(3))
	if spawn_type(6) != "tank":
		fails.append("spawn_type(6) is %s, expected tank" % spawn_type(6))

	# --- 4. Drive-by: cooldown ticks in-car (HTML bug #2) ---
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	wanted_level = 0.0
	player.global_position = cars[0].global_position + Vector3(1, 0.3, 0)
	_try_enter_car()
	if player.driving == null:
		fails.append("autotest could not enter a car")
	else:
		player.fire_cooldown = 8.0
		for i in range(10):
			await get_tree().physics_frame
		if player.fire_cooldown >= 8.0:
			fails.append("drive-by cooldown did not tick in car (still %f)" % player.fire_cooldown)
		player.fire_cooldown = 0.0
		player_shoot_3d(true)
		if player.fire_cooldown != 8.0:
			fails.append("drive-by fire did not set cooldown 8 (got %f)" % player.fire_cooldown)
		_exit_car()

	# --- 5. Black Market: purchase, cost scaling, effects (Gate 3D-2) ---
	var fails2: Array[String] = []
	cash = 10000
	if upgrade_cost("hp") != 150:
		fails2.append("hp upgrade cost at level 0 is %d, expected 150" % upgrade_cost("hp"))
	if not buy_upgrade("hp"):
		fails2.append("buy_upgrade(hp) failed with $10000")
	if upgrade_level("hp") != 1:
		fails2.append("hp level is %d after purchase, expected 1" % upgrade_level("hp"))
	if cash != 10000 - 150:
		fails2.append("cash after hp purchase is %d, expected %d" % [cash, 10000 - 150])
	if player.max_hp != 125.0:
		fails2.append("max_hp after hp upgrade is %f, expected 125 (100 + 25)" % player.max_hp)
	if upgrade_cost("hp") != 210:
		fails2.append("hp upgrade cost at level 1 is %d, expected 210 (floor(150 x 1.4))" % upgrade_cost("hp"))
	if not buy_upgrade("damage"):
		fails2.append("buy_upgrade(damage) failed")
	if absf(damage_mult() - 1.15) > 0.001:
		fails2.append("damage_mult at level 1 is %f, expected 1.15" % damage_mult())
	if not buy_upgrade("firerate"):
		fails2.append("buy_upgrade(firerate) failed")
	if absf(firerate_mult() - 1.10) > 0.001:
		fails2.append("firerate_mult at level 1 is %f, expected 1.10" % firerate_mult())
	cash = 10
	if buy_upgrade("regen"):
		fails2.append("buy_upgrade(regen) succeeded with only $10 (cost 400)")
	if upgrade_level("regen") != 0:
		fails2.append("regen level changed after a failed purchase")

	# --- 6. Save / load roundtrip (Gate 3D-2) ---
	cash = 777
	score = 4321
	unlocked_weapons = [0, 1, 3]
	save_game()
	cash = 0
	score = 0
	for k in upgrade_levels:
		upgrade_levels[k] = 0
	unlocked_weapons = [0]
	load_game()
	apply_upgrades()
	if cash != 777:
		fails2.append("save/load: cash is %d, expected 777" % cash)
	if score != 4321:
		fails2.append("save/load: score is %d, expected 4321" % score)
	if upgrade_level("hp") != 1 or upgrade_level("damage") != 1:
		fails2.append("save/load: upgrade levels not restored (hp=%d damage=%d)" % [upgrade_level("hp"), upgrade_level("damage")])
	if unlocked_weapons.size() != 3 or not unlocked_weapons.has(3):
		fails2.append("save/load: unlocked weapons not restored (%s)" % str(unlocked_weapons))
	if player.max_hp != 125.0:
		fails2.append("save/load: max_hp is %f after restore, expected 125" % player.max_hp)
	# leave no test save behind
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if fails.is_empty():
		print("AUTOTEST PASS: smg_ped_kill cash+score+combo | smg_cop_damage+kill | wanted_floor caps spawn_types | driveby_cooldown_ticks")
	else:
		for f in fails:
			print("AUTOTEST FAIL: ", f)
	if fails2.is_empty():
		print("AUTOTEST PASS: upgrade_purchase cost_scaling effects | save_load_roundtrip")
	else:
		for f in fails2:
			print("AUTOTEST FAIL: ", f)
	get_tree().quit(0 if fails.is_empty() and fails2.is_empty() else 1)
