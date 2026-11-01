class_name CityBuilder
extends RefCounted

# ENGINE CORE — seeded city generation: environment (sky/fog/sun),
# ground, roads with markings, building clusters, and street props,
# all built from CityDressing's procedural resources into a parent
# Node3D. Returns (and keeps) the building footprints so the game
# can place spawns outside buildings.
#
# Extracted from gate3d_main.gd (_setup_environment / _build_city /
# _road / _building / _build_props / _point_free) in the Engine Core
# gate (step 10) — the code moved verbatim except that add_child
# became parent.add_child and the layout config is read here. The
# grid (52 pitch, 240 extent, seed 2004) is this builder's default
# config, set from G.O.D.O.T's city; a different game passes its
# own numbers to a future config pass — the LAYOUT ALGORITHM is the
# reusable part.

var dressing: CityDressing = null
var buildings: Array = []  # Rect2 XZ footprints
# Detail Pass 1 registries (read by the autotest + screenshot
# framing): every building's facade seed / lit ratio, and every
# mounted storefront sign.
var sign_count: int = 0
var sign_accents: Array = []
var sign_positions: Array = []  # world Vector3 of each sign centre
var facade_seeds: Array = []
var facade_lit_ratios: Array = []
var _facade_seed_used := {}

# Layout constants — the single source of truth shared by the
# placement code below and the markings model / autotest.
const PITCH := 52.0        # grid pitch: roads + clusters share it
const ROAD_HALF := 5.0     # road strips are 10 wide, on grid lines
const PAD_HALF := 20.0     # block pads are 40x40, on grid points
const WORLD_HALF := 120.0  # slab / road strips span 240
const ROAD_TOP_Y := 0.115  # asphalt top (centre y 0.09 + 0.05 / 2); raised above PAD_TOP_Y by the Detail 1 markings fix so the strips stay the top surface where pads overlap them
const PAD_TOP_Y := 0.10    # pad top (centre y 0.05 + 0.1 / 2)

# Marking / pad registries (read by the autotest): the positions
# actually placed, so checks test the build, not a re-derivation.
var dash_positions: Array = []       # world centres of lane dashes
var crosswalk_positions: Array = []  # world centres of zebra stripes
var pad_centres: Array = []          # Vector2 centres of pads laid

func _init() -> void:
	dressing = CityDressing.new()

# Builds environment + city under parent; returns the footprints.
func build_world(parent: Node3D) -> Array:
	_setup_environment(parent)
	_build_city(parent)
	return buildings

func _setup_environment(parent: Node3D) -> void:
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
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	parent.add_child(sun)

# The pads this build lays (centres). Placement AND the markings
# model read this one list, so they can never drift apart.
func _compute_pad_centres() -> Array:
	var out: Array = []
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			out.append(Vector2(bx * PITCH, bz * PITCH))
	return out

# --- Markings model (shared by placement + the autotest) ---
# A point is ROAD SURFACE when it lies on a road strip AND the
# asphalt is the topmost ground surface there. Where a pad
# overlaps a strip, whichever top is higher is what a marking
# paints — with PAD_TOP_Y > ROAD_TOP_Y the pads pave over the
# roads at every cluster, which is the Detail 1 playtest bug
# (markings rendering on the sidewalks).
func _on_road_strip(x: float, z: float) -> bool:
	for i in range(-2, 3):
		if absf(x - i * PITCH) <= ROAD_HALF and absf(z) <= WORLD_HALF:
			return true
		if absf(z - i * PITCH) <= ROAD_HALF and absf(x) <= WORLD_HALF:
			return true
	return false

func _top_surface_y(x: float, z: float) -> float:
	var top := 0.0  # ground slab top
	if _on_road_strip(x, z):
		top = maxf(top, ROAD_TOP_Y)
	for c in pad_centres:
		if absf(x - c.x) <= PAD_HALF and absf(z - c.y) <= PAD_HALF:
			top = maxf(top, PAD_TOP_Y)
	return top

func is_asphalt(x: float, z: float) -> bool:
	return _on_road_strip(x, z) and _top_surface_y(x, z) <= ROAD_TOP_Y

# The crossing square of two road strips at a grid point.
func in_intersection_box(x: float, z: float) -> bool:
	for i in range(-2, 3):
		for j in range(-2, 3):
			if absf(x - i * PITCH) <= ROAD_HALF and absf(z - j * PITCH) <= ROAD_HALF:
				return true
	return false

func _point_free(x: float, z: float, grow: float) -> bool:
	var p := Vector2(x, z)
	for r in buildings:
		if r.grow(grow).has_point(p):
			return false
	return true

func _build_city(parent: Node3D) -> void:
	# Gate 3D-2 city: same layout grid as 3D-0/1 (roads on the 52
	# pitch, building clusters on the grid points, centre cluster
	# open) — but dressed. All resources come from CityDressing.
	pad_centres = _compute_pad_centres()
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
	parent.add_child(ground)
	# Fall fix (2026-11-01): invisible world-edge walls just
	# outside the slab — one body, four shapes, no meshes, so
	# nothing can leave the ground (Vee's first live sessions:
	# drove past x=120 and fell to y=-771). Slow contact stops
	# here; the GAME layer turns fast contact into the bonk
	# launch. Tall enough that roof-height crossings stay in.
	var edge_body := StaticBody3D.new()
	var wall_h := 30.0
	var wall_specs := [
		[Vector3(WORLD_HALF + 1.0, wall_h / 2.0, 0), Vector3(2, wall_h, WORLD_HALF * 2 + 4)],
		[Vector3(-WORLD_HALF - 1.0, wall_h / 2.0, 0), Vector3(2, wall_h, WORLD_HALF * 2 + 4)],
		[Vector3(0, wall_h / 2.0, WORLD_HALF + 1.0), Vector3(WORLD_HALF * 2 + 4, wall_h, 2)],
		[Vector3(0, wall_h / 2.0, -WORLD_HALF - 1.0), Vector3(WORLD_HALF * 2 + 4, wall_h, 2)],
	]
	for spec in wall_specs:
		var wshape := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = spec[1]
		wshape.shape = wbox
		wshape.position = spec[0]
		edge_body.add_child(wshape)
	parent.add_child(edge_body)
	# roads: asphalt-textured strips on the grid. Detail 1 markings
	# fix: strip centre y 0.09 puts the asphalt top (0.115) ABOVE
	# the pad tops (0.10), so the road surface — and its markings —
	# stays on top where a block pad overlaps a strip, instead of
	# the pad paving over the road at every cluster.
	for i in range(-2, 3):
		_road(parent, Vector3(i * PITCH, 0.09, 0), Vector3(10, 0.05, 240))
		_road(parent, Vector3(0, 0.09, i * PITCH), Vector3(240, 0.05, 10))
	# dashed lane markings down every road centre (one MultiMesh)
	var dash_xf: Array = []
	for i in range(-2, 3):
		for k in range(-19, 20):
			var dp1 := Vector3(i * PITCH, 0.09, k * 6.0)
			var dp2 := Vector3(k * 6.0, 0.09, i * PITCH)
			dash_xf.append(d.xf(dp1))
			dash_xf.append(d.xf(dp2, PI / 2.0))
			dash_positions.append(dp1)
			dash_positions.append(dp2)
	parent.add_child(d.make_multimesh(d.dash_mesh, d.dash_mat, dash_xf))
	# crosswalks at the open centre intersection (the other grid
	# intersections are built over by the clusters, as in 3D-0/1)
	var cw := MeshInstance3D.new()
	cw.mesh = d.crosswalk_mesh
	cw.material_override = d.crosswalk_mat
	parent.add_child(cw)
	for s in d.crosswalk_stripes:
		crosswalk_positions.append(s[0])
	# buildings: seeded clusters, 1-3 dressed buildings per grid point
	var rng := RandomNumberGenerator.new()
	rng.seed = 2004  # San Andreas launch year, why not
	var ac_xf: Array = []
	var antenna_xf: Array = []
	var tower_spots: Array = []  # Vector4(x, z, roof_y, footprint)
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			# pavement pad under each cluster (its edge is the curb)
			if pad_centres.has(Vector2(bx * PITCH, bz * PITCH)):
				var pad := MeshInstance3D.new()
				var pbm := BoxMesh.new()
				pbm.size = Vector3(40, 0.1, 40)
				pad.mesh = pbm
				pad.position = Vector3(bx * PITCH, 0.05, bz * PITCH)
				var pmat := d.pavement_mat.duplicate() as StandardMaterial3D
				pmat.uv1_scale = Vector3(10, 10, 1)
				pad.material_override = pmat
				parent.add_child(pad)
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
				_building(parent, Vector3(cx, 0, cz), Vector3(w, h, dep), rng, Vector2(bx * 52, bz * 52))
				if rng.randf() < 0.5:
					ac_xf.append(d.xf(Vector3(cx + rng.randf_range(-w / 4, w / 4), h + 0.55, cz + rng.randf_range(-dep / 4, dep / 4)), rng.randf() * TAU))
				if h > 17.0 and rng.randf() < 0.6:
					antenna_xf.append(d.xf(Vector3(cx + w / 2 - 1.0, h + 1.5, cz + dep / 2 - 1.0)))
				if h > 9.0 and h < 21.0 and rng.randf() < 0.16:
					tower_spots.append(Vector4(cx, cz, h, w))
	parent.add_child(d.make_multimesh(d.ac_mesh, d.ac_mat, ac_xf))
	parent.add_child(d.make_multimesh(d.antenna_mesh, d.antenna_mat, antenna_xf))
	_build_props(parent, rng, d, tower_spots)

func _road(parent: Node3D, pos: Vector3, size: Vector3) -> void:
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
	parent.add_child(mi)

func _building(parent: Node3D, pos: Vector3, size: Vector3, rng: RandomNumberGenerator, cluster_centre: Vector2 = Vector2.ZERO) -> void:
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
	# Detail Pass 1: a UNIQUE facade seed + lit-window ratio per
	# building (stronger than "adjacent buildings differ"), so no
	# two buildings share a facade or a lit pattern.
	var fseed := 77003 + facade_seeds.size() * 131 + rng.randi_range(0, 60)
	while _facade_seed_used.has(fseed):
		fseed += 1
	_facade_seed_used[fseed] = true
	var lit_ratio := rng.randf_range(0.08, 0.50)
	facade_seeds.append(fseed)
	facade_lit_ratios.append(lit_ratio)
	var fm := d.make_facade_material(d.facade_bases[rng.randi() % d.facade_bases.size()], fseed, lit_ratio)
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
		# Detail Pass 1: most storefronts carry an emissive sign
		if rng.randf() < 0.55:
			_mount_sign(body, pos, size, cluster_centre, rng)
	buildings.append(Rect2(pos.x - size.x / 2, pos.z - size.z / 2, size.x, size.z))
	parent.add_child(body)

# Detail Pass 1: mount one emissive sign on the building face
# pointing away from the cluster centre (toward the pad edge /
# road), above the awning. One node per sign.
func _mount_sign(body: Node3D, pos: Vector3, size: Vector3, centre: Vector2, rng: RandomNumberGenerator) -> void:
	var d := dressing
	var rel := Vector2(pos.x - centre.x, pos.z - centre.y)
	var normal := Vector3(0, 0, 1)
	var along_x := false
	if absf(rel.x) > absf(rel.y):
		normal = Vector3(signf(rel.x), 0, 0)
		along_x = true
	elif absf(rel.y) > 0.01:
		normal = Vector3(0, 0, signf(rel.y))
	var accent: Color = CityDressing.SIGN_ACCENTS[rng.randi() % CityDressing.SIGN_ACCENTS.size()]
	var sign := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.4, 0.85, 0.12)
	sign.mesh = bm
	var half := (size.x / 2.0 + 0.10) if along_x else (size.z / 2.0 + 0.10)
	sign.position = Vector3(normal.x * half, 3.1, normal.z * half)
	if along_x:
		sign.rotation.y = PI / 2.0
	sign.material_override = d.make_sign_material(accent, 4000 + sign_count * 17 + rng.randi_range(0, 9))
	body.add_child(sign)
	sign_count += 1
	if not sign_accents.has(accent):
		sign_accents.append(accent)
	sign_positions.append(pos + sign.position)

func _build_props(parent: Node3D, rng: RandomNumberGenerator, d: CityDressing, tower_spots: Array) -> void:
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
		parent.add_child(tw)
	# Streetlights: one side per segment, alternating, arm over the
	# road; skipped where a building swallowed the spot.
	var light_xf: Array = []
	var head_xf: Array = []
	for i in range(-2, 3):
		for k in range(8):
			var along := -113.75 + k * 32.5
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
	parent.add_child(d.make_multimesh(d.streetlight_mesh, d.pole_mat, light_xf))
	# lamp heads: same instance transforms as the poles, with the
	# arm-end offset folded into each transform.
	var head_xf2: Array = []
	for t in head_xf:
		var local := Transform3D(Basis(), Vector3(0, 4.08, -1.45))
		head_xf2.append(t * local)
	parent.add_child(d.make_multimesh(d.lamp_head_mesh, d.lamp_mat, head_xf2))
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
	parent.add_child(d.make_multimesh(d.traffic_mesh, d.traffic_box_mat, tl_xf))
	parent.add_child(d.make_multimesh(d.lens_mesh, d.lens_red_mat, red_xf))
	parent.add_child(d.make_multimesh(d.lens_mesh, d.lens_green_mat, green_xf))
	parent.add_child(d.make_multimesh(d.lens_mesh, d.lens_dark_mat, dark_xf))
	# Trees at cluster corners (checked against buildings)
	var trunk_xf: Array = []
	var fol_xf: Array = []
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			for corner in [Vector2(-17, -17), Vector2(17, -17), Vector2(-17, 17), Vector2(17, 17)]:
				if rng.randf() < 0.20:
					continue
				var tx: float = bx * 52 + corner.x + rng.randf_range(-2, 2)
				var tz: float = bz * 52 + corner.y + rng.randf_range(-2, 2)
				if not _point_free(tx, tz, 1.2):
					continue
				trunk_xf.append(d.xf(Vector3(tx, 0.65, tz)))
				var sc := rng.randf_range(0.85, 1.45)
				fol_xf.append(d.xf(Vector3(tx, 2.1 * sc, tz), rng.randf() * TAU, sc))
	parent.add_child(d.make_multimesh(d.trunk_mesh, d.trunk_mat, trunk_xf))
	parent.add_child(d.make_multimesh(d.foliage_mesh, d.foliage_mat, fol_xf))
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
		parent.add_child(dn)
		placed += 1
	# Crates + barriers scattered on pads (MultiMesh)
	var crate_xf: Array = []
	var barrier_xf: Array = []
	for i in range(70):
		var px := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		var pz := (randi_range(-2, 2)) * 52 + rng.randf_range(-19, 19)
		if not _point_free(px, pz, 1.0):
			continue
		if i % 3 == 0:
			barrier_xf.append(d.xf(Vector3(px, 0.43, pz), rng.randf() * TAU))
		else:
			crate_xf.append(d.xf(Vector3(px, 0.38, pz), rng.randf() * TAU, rng.randf_range(0.8, 1.3)))
	parent.add_child(d.make_multimesh(d.crate_mesh, d.crate_mat, crate_xf))
	parent.add_child(d.make_multimesh(d.barrier_mesh, d.barrier_mat, barrier_xf))
	# ---- Detail Pass 1: street clutter density (all MultiMesh) ----
	# Bollards along both edges of every road, skipped inside
	# building footprints.
	var bollard_xf: Array = []
	for i in range(-2, 3):
		for k in range(19):
			var along := -117.0 + k * 13.0
			for side in [-1.0, 1.0]:
				if _point_free(i * 52 + side * 6.6, along, 0.3):
					bollard_xf.append(d.xf(Vector3(i * 52 + side * 6.6, 0.43, along)))
				if _point_free(along, i * 52 + side * 6.6, 0.3):
					bollard_xf.append(d.xf(Vector3(along, 0.43, i * 52 + side * 6.6)))
	parent.add_child(d.make_multimesh(d.bollard_mesh, d.bollard_mat, bollard_xf))
	# Traffic cones scattered on the road surfaces.
	var cone_xf: Array = []
	for i in range(70):
		var road_i := randi_range(-2, 2) * 52
		var along := rng.randf_range(-115, 115)
		var off := rng.randf_range(-4.2, 4.2)
		if rng.randf() < 0.5:
			cone_xf.append(d.xf(Vector3(road_i + off, 0.32, along), rng.randf() * TAU))
		else:
			cone_xf.append(d.xf(Vector3(along, 0.32, road_i + off), rng.randf() * TAU))
	parent.add_child(d.make_multimesh(d.cone_mesh, d.cone_mat, cone_xf))
	# Trash bags on the pads.
	var bag_xf: Array = []
	for i in range(90):
		var px := randi_range(-2, 2) * 52 + rng.randf_range(-19, 19)
		var pz := randi_range(-2, 2) * 52 + rng.randf_range(-19, 19)
		if not _point_free(px, pz, 0.7):
			continue
		bag_xf.append(d.xf3(Vector3(px, 0.30, pz), rng.randf() * TAU, Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.6, 0.85), rng.randf_range(0.8, 1.3))))
	parent.add_child(d.make_multimesh(d.trashbag_mesh, d.trashbag_mat, bag_xf))
	# Bushes along pad edges (foliage mesh, small scale).
	var bush_xf: Array = []
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			for spot in [Vector2(-19, -19), Vector2(19, -19), Vector2(-19, 19), Vector2(19, 19), Vector2(0, -19), Vector2(0, 19), Vector2(-19, 0), Vector2(19, 0)]:
				if rng.randf() < 0.35:
					continue
				var px2: float = bx * 52 + spot.x + rng.randf_range(-1.5, 1.5)
				var pz2: float = bz * 52 + spot.y + rng.randf_range(-1.5, 1.5)
				if not _point_free(px2, pz2, 0.9):
					continue
				var sc := rng.randf_range(0.35, 0.6)
				bush_xf.append(d.xf(Vector3(px2, 1.05 * sc + 0.1, pz2), rng.randf() * TAU, sc))
	parent.add_child(d.make_multimesh(d.foliage_mesh, d.foliage_mat, bush_xf))
	# Newspaper boxes at cluster corners.
	var news_xf: Array = []
	for bx in range(-2, 3):
		for bz in range(-2, 3):
			for corner in [Vector2(-21, -21), Vector2(21, -21), Vector2(-21, 21), Vector2(21, 21)]:
				if rng.randf() < 0.55:
					continue
				var px3: float = bx * 52 + corner.x
				var pz3: float = bz * 52 + corner.y
				if not _point_free(px3, pz3, 0.8):
					continue
				news_xf.append(d.xf(Vector3(px3, 0.48, pz3), rng.randf() * TAU))
	parent.add_child(d.make_multimesh(d.newsbox_mesh, d.newsbox_mat, news_xf))
	# Cardboard piles on the pads.
	var card_xf: Array = []
	for i in range(50):
		var px4 := randi_range(-2, 2) * 52 + rng.randf_range(-19, 19)
		var pz4 := randi_range(-2, 2) * 52 + rng.randf_range(-19, 19)
		if not _point_free(px4, pz4, 0.8):
			continue
		card_xf.append(d.xf(Vector3(px4, 0.12, pz4), rng.randf() * TAU, rng.randf_range(0.8, 1.4)))
	parent.add_child(d.make_multimesh(d.cardboard_mesh, d.cardboard_mat, card_xf))
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
		parent.add_child(bn)
