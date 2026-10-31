class_name CityDressing
extends RefCounted

# ENGINE CORE — the shared visual resources for CityBuilder
# (core/city_builder.gd): textures, materials, meshes, MultiMesh
# builder. Extracted from gate3d/dressing.gd in the Engine Core
# gate (step 10); content unchanged.
#
# Gate 3D-2: ALL visuals are procedural — meshes, materials and
# textures generated in code at startup. No binary assets anywhere:
# the repo's GitHub push route accepts UTF-8 text only, so .glb/.fbx
# model packs cannot live in the repo. Code-generated dressing keeps
# everything text, licence-clean and reproducible from seed 2004.
#
# This class owns the shared resources (textures, materials, meshes)
# and small builders (MultiMesh sets, merged-mesh props). Placement
# lives in gate3d_main, which knows the city layout.

var facade_materials: Array[StandardMaterial3D] = []
var roof_mat: StandardMaterial3D
var storefront_mat: StandardMaterial3D
var awning_mats: Array[StandardMaterial3D] = []
var asphalt_mat: StandardMaterial3D
var concrete_mat: StandardMaterial3D
var pavement_mat: StandardMaterial3D
var dash_mat: StandardMaterial3D
var crosswalk_mat: StandardMaterial3D
var pole_mat: StandardMaterial3D
var lamp_mat: StandardMaterial3D
var traffic_box_mat: StandardMaterial3D
var lens_red_mat: StandardMaterial3D
var lens_green_mat: StandardMaterial3D
var lens_dark_mat: StandardMaterial3D
var trunk_mat: StandardMaterial3D
var foliage_mat: StandardMaterial3D
var dumpster_mat: StandardMaterial3D
var dumpster_lid_mat: StandardMaterial3D
var crate_mat: StandardMaterial3D
var barrier_mat: StandardMaterial3D
var bench_mat: StandardMaterial3D
var ac_mat: StandardMaterial3D
var antenna_mat: StandardMaterial3D
var tower_mat: StandardMaterial3D
var tower_roof_mat: StandardMaterial3D
# Detail Pass 1 clutter set (all MultiMesh'd by CityBuilder)
var bollard_mat: StandardMaterial3D
var cone_mat: StandardMaterial3D
var trashbag_mat: StandardMaterial3D
var newsbox_mat: StandardMaterial3D
var cardboard_mat: StandardMaterial3D

var unit_box: BoxMesh
var dash_mesh: BoxMesh
var crate_mesh: BoxMesh
var barrier_mesh: BoxMesh
var ac_mesh: BoxMesh
var trunk_mesh: CylinderMesh
var foliage_mesh: SphereMesh
var antenna_mesh: CylinderMesh
var streetlight_mesh: ArrayMesh  # pole + arm, offsets baked in
var lamp_head_mesh: BoxMesh     # offset baked via instance transform
var traffic_mesh: ArrayMesh     # pole + signal box, offsets baked in
var lens_mesh: SphereMesh
var crosswalk_mesh: ArrayMesh   # one intersection's 4 zebra sets
var crosswalk_stripes: Array = []  # [centre, size] per stripe baked into crosswalk_mesh (CityBuilder reads the centres)
var bollard_mesh: CylinderMesh
var cone_mesh: CylinderMesh
var trashbag_mesh: SphereMesh
var newsbox_mesh: BoxMesh
var cardboard_mesh: BoxMesh

func _mat(color: Color, rough: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m

func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2004
	_build_textures(rng)
	_build_materials()
	_build_meshes()

# ---------- Code-generated textures ----------
func _speckle(img: Image, rng: RandomNumberGenerator, amount: float, count: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in range(count):
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 1)
		var c := img.get_pixel(x, y)
		var d := rng.randf_range(-amount, amount)
		img.set_pixel(x, y, Color(clampf(c.r + d, 0.0, 1.0), clampf(c.g + d, 0.0, 1.0), clampf(c.b + d, 0.0, 1.0), 1.0))

# Detail Pass 1: storefront sign accents (Midnight-Circle-adjacent:
# violet C77DFF, gold FFD479, moonwater 7FDBCA, ember FF5370, herb
# 82C99A) and the facade base palette, shared with CityBuilder so
# per-building facades use the same bases as the shared set.
const SIGN_ACCENTS: Array = [
	Color(0.78, 0.49, 1.0), Color(1.0, 0.83, 0.47), Color(0.50, 0.86, 0.79),
	Color(1.0, 0.33, 0.44), Color(0.51, 0.79, 0.60),
]
var facade_bases: Array = []

func _make_facade(base: Color, rng: RandomNumberGenerator, lit_ratio: float = 0.28) -> ImageTexture:
	var img := Image.create(128, 192, false, Image.FORMAT_RGBA8)
	img.fill(base)
	_speckle(img, rng, 0.045, 2600)
	# window grid: 6 cols x 12 rows; the bottom row is storefront glass
	var cols := 6
	var rows := 12
	var cw := 128.0 / cols
	var ch := 192.0 / rows
	for r in range(rows):
		for c in range(cols):
			var rect := Rect2i(int(c * cw) + 4, int(r * ch) + 3, int(cw) - 8, int(ch) - 6)
			var wc: Color
			if r == rows - 1:
				wc = Color(0.05, 0.07, 0.10)
			elif rng.randf() < lit_ratio:
				var b := rng.randf_range(0.7, 1.0)
				wc = Color(1.0 * b, 0.74 * b, 0.40 * b)  # lit window, warm
			elif rng.randf() < 0.10:
				wc = Color(0.35, 0.36, 0.34)  # blinds / pale glass
			else:
				var v := rng.randf_range(0.0, 0.05)
				wc = Color(0.08 + v, 0.11 + v, 0.15 + v)  # dark glass
			img.fill_rect(rect, wc)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _make_noise_tile(base: Color, rng: RandomNumberGenerator, speckle_count: int) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(base)
	_speckle(img, rng, 0.05, speckle_count)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _build_textures(rng: RandomNumberGenerator) -> void:
	# muted PS2-era facade palette
	var bases: Array[Color] = [
		Color(0.55, 0.42, 0.35), Color(0.62, 0.55, 0.45), Color(0.45, 0.50, 0.55),
		Color(0.50, 0.50, 0.42), Color(0.66, 0.58, 0.47), Color(0.40, 0.42, 0.48),
	]
	facade_bases = bases
	for b in bases:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _make_facade(b, rng)
		m.roughness = 0.95
		m.texture_repeat = 1  # TEXTURE_REPEAT_ENABLED (enum constant not exposed to GDScript in 4.3; value verified empirically)
		facade_materials.append(m)
	asphalt_mat = StandardMaterial3D.new()
	asphalt_mat.albedo_texture = _make_noise_tile(Color(0.075, 0.075, 0.082), rng, 5200)
	asphalt_mat.roughness = 1.0
	asphalt_mat.texture_repeat = 1  # TEXTURE_REPEAT_ENABLED (enum constant not exposed to GDScript in 4.3; value verified empirically)
	concrete_mat = StandardMaterial3D.new()
	concrete_mat.albedo_texture = _make_noise_tile(Color(0.46, 0.47, 0.46), rng, 3800)
	concrete_mat.roughness = 1.0
	concrete_mat.texture_repeat = 1  # TEXTURE_REPEAT_ENABLED (enum constant not exposed to GDScript in 4.3; value verified empirically)
	pavement_mat = concrete_mat  # block pads share the concrete tile

func _build_materials() -> void:
	roof_mat = _mat(Color(0.15, 0.15, 0.17))
	storefront_mat = _mat(Color(0.06, 0.08, 0.11), 0.35)
	for c in [Color(0.45, 0.12, 0.18), Color(0.10, 0.35, 0.38), Color(0.75, 0.55, 0.15), Color(0.35, 0.20, 0.50), Color(0.20, 0.40, 0.20)]:
		awning_mats.append(_mat(c, 0.9))
	dash_mat = _mat(Color(0.85, 0.82, 0.70), 0.9)
	crosswalk_mat = _mat(Color(0.80, 0.80, 0.78), 0.9)
	pole_mat = _mat(Color(0.12, 0.12, 0.14), 0.7)
	lamp_mat = _unshaded(Color(1.0, 0.90, 0.60))
	traffic_box_mat = _mat(Color(0.08, 0.08, 0.09), 0.8)
	lens_red_mat = _unshaded(Color(0.92, 0.10, 0.10))
	lens_green_mat = _unshaded(Color(0.15, 0.92, 0.28))
	lens_dark_mat = _mat(Color(0.07, 0.07, 0.07), 0.5)
	trunk_mat = _mat(Color(0.30, 0.22, 0.15))
	foliage_mat = _mat(Color(0.16, 0.35, 0.14), 1.0)
	dumpster_mat = _mat(Color(0.16, 0.32, 0.20), 0.8)
	dumpster_lid_mat = _mat(Color(0.10, 0.10, 0.11), 0.8)
	crate_mat = _mat(Color(0.48, 0.36, 0.20), 1.0)
	barrier_mat = _mat(Color(0.78, 0.44, 0.14), 0.9)
	bench_mat = _mat(Color(0.25, 0.28, 0.30), 0.7)
	ac_mat = _mat(Color(0.55, 0.56, 0.58), 0.85)
	antenna_mat = _mat(Color(0.20, 0.20, 0.22), 0.6)
	tower_mat = _mat(Color(0.42, 0.33, 0.22), 0.95)
	tower_roof_mat = _mat(Color(0.30, 0.24, 0.16), 0.95)
	bollard_mat = _mat(Color(0.58, 0.56, 0.48), 0.7)
	cone_mat = _mat(Color(0.85, 0.40, 0.10), 0.9)
	trashbag_mat = _mat(Color(0.08, 0.09, 0.11), 0.95)
	newsbox_mat = _mat(Color(0.20, 0.30, 0.55), 0.6)
	cardboard_mat = _mat(Color(0.55, 0.42, 0.26), 1.0)

# ---------- Shared meshes ----------
func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm

func _merged(parts: Array) -> ArrayMesh:
	# parts: Array of [Mesh, Transform3D] — baked into one ArrayMesh.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(p[0], 0, p[1])
	return st.commit()

func _t(origin: Vector3, size: Vector3, rot_y: float = 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rot_y).scaled(size)
	return Transform3D(b, origin)

func _build_meshes() -> void:
	unit_box = _box_mesh(Vector3.ONE)
	dash_mesh = _box_mesh(Vector3(0.14, 0.10, 2.0))
	crate_mesh = _box_mesh(Vector3(0.75, 0.75, 0.75))
	barrier_mesh = _box_mesh(Vector3(1.9, 0.85, 0.42))
	ac_mesh = _box_mesh(Vector3(1.25, 0.62, 1.25))
	trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.09
	trunk_mesh.bottom_radius = 0.14
	trunk_mesh.height = 1.3
	trunk_mesh.radial_segments = 7
	foliage_mesh = SphereMesh.new()
	foliage_mesh.radius = 0.95
	foliage_mesh.height = 2.1
	foliage_mesh.radial_segments = 7
	foliage_mesh.rings = 4
	antenna_mesh = CylinderMesh.new()
	antenna_mesh.top_radius = 0.025
	antenna_mesh.bottom_radius = 0.04
	antenna_mesh.height = 2.6
	antenna_mesh.radial_segments = 5
	# streetlight: pole at origin, arm reaching toward -Z (over the road)
	streetlight_mesh = _merged([
		[unit_box, _t(Vector3(0, 2.1, 0), Vector3(0.13, 4.2, 0.13))],
		[unit_box, _t(Vector3(0, 4.14, -0.75), Vector3(0.10, 0.10, 1.6))],
	])
	lamp_head_mesh = _box_mesh(Vector3(0.30, 0.09, 0.55))
	# traffic light: pole + signal box facing -Z
	traffic_mesh = _merged([
		[unit_box, _t(Vector3(0, 1.8, 0), Vector3(0.13, 3.6, 0.13))],
		[unit_box, _t(Vector3(0, 3.25, -0.28), Vector3(0.36, 0.95, 0.30))],
	])
	lens_mesh = SphereMesh.new()
	lens_mesh.radius = 0.085
	lens_mesh.height = 0.17
	lens_mesh.radial_segments = 8
	lens_mesh.rings = 4
	# crosswalks: zebra stripes across all 4 approaches of one
	# intersection centred at the origin (stripes stop at the road edge)
	crosswalk_stripes.clear()
	for side in [-1.0, 1.0]:
		for i in range(5):
			var off := -4.0 + i * 2.0
			# Detail 1 markings fix: stripe centre y 0.132 puts the
			# slab (0.03 thick) just proud of the raised asphalt top
			# (0.115) — paint ON the road. (Pre-fix y 0.105 painted
			# the intersection PAD, whose top was 0.10.)
			# across the vertical road, north + south approaches
			crosswalk_stripes.append([Vector3(off, 0.132, side * 7.6), Vector3(1.1, 0.03, 2.8)])
			# across the horizontal road, east + west approaches
			crosswalk_stripes.append([Vector3(side * 7.6, 0.132, off), Vector3(2.8, 0.03, 1.1)])
	var parts: Array = []
	for s in crosswalk_stripes:
		parts.append([unit_box, _t(s[0], s[1])])
	crosswalk_mesh = _merged(parts)
	# Detail Pass 1 clutter meshes (cheap on purpose: the density
	# budget is paid in instances, not triangles)
	bollard_mesh = CylinderMesh.new()
	bollard_mesh.top_radius = 0.09
	bollard_mesh.bottom_radius = 0.11
	bollard_mesh.height = 0.85
	bollard_mesh.radial_segments = 7
	cone_mesh = CylinderMesh.new()
	cone_mesh.top_radius = 0.03
	cone_mesh.bottom_radius = 0.17
	cone_mesh.height = 0.55
	cone_mesh.radial_segments = 8
	trashbag_mesh = SphereMesh.new()
	trashbag_mesh.radius = 0.42
	trashbag_mesh.height = 0.8
	trashbag_mesh.radial_segments = 7
	trashbag_mesh.rings = 4
	newsbox_mesh = _box_mesh(Vector3(0.55, 0.95, 0.5))
	cardboard_mesh = _box_mesh(Vector3(0.95, 0.14, 0.7))

# Detail Pass 1: a per-building facade material — unique texture
# from its own seeded RNG at a per-building lit-window ratio, so
# no two buildings share a facade (seed) or a lit pattern.
func make_facade_material(base: Color, seed_value: int, lit_ratio: float) -> StandardMaterial3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var m := StandardMaterial3D.new()
	m.albedo_texture = _make_facade(base, rng, lit_ratio)
	m.roughness = 0.95
	m.texture_repeat = 1  # TEXTURE_REPEAT_ENABLED (see _build_textures)
	return m

# Detail Pass 1: an emissive storefront sign — generated texture
# (dark panel, accent border, blocky name-like glyph bars) lit by
# its own emission so it reads at fog distance.
func make_sign_material(accent: Color, seed_value: int) -> StandardMaterial3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.04, 0.10))  # void panel
	img.fill_rect(Rect2i(0, 0, 256, 3), accent)
	img.fill_rect(Rect2i(0, 61, 256, 3), accent)
	img.fill_rect(Rect2i(0, 0, 3, 64), accent)
	img.fill_rect(Rect2i(253, 0, 3, 64), accent)
	var x := 14
	for li in range(rng.randi_range(5, 8)):
		var lw := rng.randi_range(14, 24)
		var bars := rng.randi_range(2, 4)
		for b in range(bars):
			var bx := x + int(float(lw) * float(b) / float(bars))
			var bw := maxi(3, int(float(lw) / float(bars)) - 3)
			var bh := rng.randi_range(24, 38)
			var col := accent if b % 2 == 0 else Color(0.95, 0.93, 0.85)
			img.fill_rect(Rect2i(bx, 32 - bh / 2, bw, bh), col)
		if rng.randf() < 0.6:
			img.fill_rect(Rect2i(x, 29, lw, 5), accent.darkened(0.15))
		x += lw + rng.randi_range(6, 12)
		if x > 225:
			break
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_texture = tex
	m.emission_energy_multiplier = 1.35
	return m

# ---------- MultiMesh builder ----------
func make_multimesh(mesh: Mesh, mat: Material, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	return mmi

func xf(pos: Vector3, rot_y: float = 0.0, scale: float = 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * scale), pos)

# Detail Pass 1: non-uniform-scale sibling of xf (squashed bags).
func xf3(pos: Vector3, rot_y: float, scale: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y).scaled(scale), pos)
