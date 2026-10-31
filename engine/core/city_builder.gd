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
	# roads: asphalt-textured strips on the grid
	for i in range(-2, 3):
		_road(parent, Vector3(i * 52, 0.02, 0), Vector3(10, 0.05, 240))
		_road(parent, Vector3(0, 0.02, i * 52), Vector3(240, 0.05, 10))
	# dashed lane markings down every road centre (one MultiMesh)
	var dash_xf: Array = []
	for i in range(-2, 3):
		for k in range(-19, 20):
			dash_xf.append(d.xf(Vector3(i * 52, 0.09, k * 6.0)))
			dash_xf.append(d.xf(Vector3(k * 6.0, 0.09, i * 52), PI / 2.0))
	parent.add_child(d.make_multimesh(d.dash_mesh, d.dash_mat, dash_xf))
	# crosswalks at the open centre intersection (the other grid
	# intersections are built over by the clusters, as in 3D-0/1)
	var cw := MeshInstance3D.new()
	cw.mesh = d.crosswalk_mesh
	cw.material_override = d.crosswalk_mat
	parent.add_child(cw)
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
				_building(parent, Vector3(cx, 0, cz), Vector3(w, h, dep), rng)
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

func _building(parent: Node3D, pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
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
	parent.add_child(body)

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
				if rng.randf() < 0.45:
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
	for i in range(26):
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
