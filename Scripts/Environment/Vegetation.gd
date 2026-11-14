class_name Vegetation
extends RefCounted
## Static procedural builders for tropical vegetation. All meshes are cached and
## shared by MultiMesh scatter. Colours are sRGB (MeshBuilder converts).

static var _cache: Dictionary = {}

## Real low-poly forest trees (3 variants, bark + leaf-card textures). Procedural tree is the fallback.
const TREE_GLB: String = "res://Assets/Models/forest_trees.glb"
## Which node of forest_trees.glb each of the 3 scatter variants uses (3 and 4 are the realistic leafy trees).
const TREE_NODES: Array[int] = [3, 4, 1]

# ---- broadleaf forest tree (jackfruit / mango-like) --------------------------------
static func get_tree_mesh(variant: int, detail: int) -> ArrayMesh:
	var key: String = "tree_%d_%d" % [variant, detail]
	if not _cache.has(key):
		var glb: ArrayMesh = GlbMesh.load_mesh(TREE_GLB, 14.0 + float(variant) * 1.5, {"only_node": "Tree%d" % TREE_NODES[variant % 3]})
		if glb != null:
			_cache[key] = glb
		else:
			_cache[key] = build_broadleaf(50 + variant * 13, 8.0 + float(variant) * 1.5, detail)
	return _cache[key] as ArrayMesh

static func build_broadleaf(seed_in: int, height: float, detail: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_in
	var mb: MeshBuilder = MeshBuilder.new()
	var bark_a: Color = Color(0.28, 0.20, 0.14)
	var bark_b: Color = Color(0.40, 0.32, 0.22)
	var bend: Vector3 = Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(-0.8, 0.8))
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	var n: int = 6
	for i in range(n):
		var t: float = float(i) / float(n - 1)
		path.append(Vector3(0.0, -0.2 + t * height * 0.72, 0.0) + bend * (t * t))
		radii.append(lerpf(0.34, 0.17, t) * (1.35 if i == 0 else 1.0))
	mb.add_tube(path, radii, 6 if detail > 0 else 5, bark_a, bark_b)
	var crown: Vector3 = path[n - 1]
	var lumps: int = 7 if detail > 0 else 3
	for i in range(lumps):
		var a: float = TAU * float(i) / float(lumps) + rng.randf_range(-0.4, 0.4)
		var rr: float = 0.0 if i == 0 else rng.randf_range(1.4, 2.3)
		var r: float = rng.randf_range(1.8, 2.8)
		var centre: Vector3 = crown + Vector3(cos(a) * rr, rng.randf_range(0.2, 2.2), sin(a) * rr)
		if i > 0 and detail > 0:
			var bp: PackedVector3Array = PackedVector3Array([crown - Vector3(0.0, 1.2, 0.0), (crown + centre) * 0.5, centre - Vector3(0.0, 0.5, 0.0)])
			mb.add_tube(bp, PackedFloat32Array([0.12, 0.09, 0.06]), 4, bark_a, bark_b)
		var dark: Color = Color(0.09, 0.26, 0.08).lerp(Color(0.14, 0.30, 0.09), rng.randf())
		var light: Color = Color(0.24, 0.46, 0.13).lerp(Color(0.34, 0.54, 0.16), rng.randf())
		mb.add_sphere(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), centre), Vector3(r, r * 0.62, r), 5 if detail > 0 else 4, 8 if detail > 0 else 6, dark, light, 0.22, rng.randf() * 10.0)
	return mb.build(GameMaterials.foliage())

# ---- low flowering bush -------------------------------------------------------------
static func get_bush_mesh(variant: int) -> ArrayMesh:
	var key: String = "bush_%d" % variant
	if not _cache.has(key):
		_cache[key] = build_bush(200 + variant * 7, variant)
	return _cache[key] as ArrayMesh

static func build_bush(seed_in: int, variant: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_in
	var mb: MeshBuilder = MeshBuilder.new()
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + rng.randf()
		var r: float = rng.randf_range(0.45, 0.8)
		var c: Vector3 = Vector3(cos(a) * 0.45, r * 0.5, sin(a) * 0.45)
		var dark: Color = Color(0.10, 0.28, 0.09).lerp(Color(0.16, 0.34, 0.10), rng.randf())
		var light: Color = Color(0.26, 0.48, 0.14).lerp(Color(0.36, 0.56, 0.18), rng.randf())
		mb.add_sphere(Transform3D(Basis.IDENTITY, c), Vector3(r, r * 0.8, r), 4, 6, dark, light, 0.2, rng.randf() * 10.0)
	if variant != 1:
		var flower: Color = Color(0.82, 0.10, 0.12) if variant == 0 else Color(0.95, 0.75, 0.15)
		for i in range(6):
			var a2: float = rng.randf() * TAU
			var fp: Vector3 = Vector3(cos(a2) * 0.7, rng.randf_range(0.5, 0.95), sin(a2) * 0.7)
			mb.add_sphere(Transform3D(Basis.IDENTITY, fp), Vector3(0.08, 0.06, 0.08), 3, 5, flower.darkened(0.2), flower)
	return mb.build(GameMaterials.vertex_color())

# ---- grass / fern tufts -------------------------------------------------------------
## Real grass cards: small clumps are cut out of the big realtime_grass patch (xz centres in
## the model's own metres). If the file is missing the procedural tuft is used.
const GRASS_GLB: String = "res://Assets/Models/realtime_grass.glb"
const GRASS_CLUMPS: Array[Vector2] = [Vector2(-3.0, 1.0), Vector2(1.5, -5.3), Vector2(-0.4, -2.4)]

static func get_tuft_mesh(variant: int) -> ArrayMesh:
	var key: String = "tuft_%d" % variant
	if not _cache.has(key):
		var glb: ArrayMesh = GlbMesh.load_mesh(GRASS_GLB, 0.0, {"skip_materials": ["Material"], "clip_center": GRASS_CLUMPS[variant % 3], "clip_radius": 0.7, "scale_mult": 0.7 + float(variant) * 0.15})
		if glb != null:
			_cache[key] = glb
		else:
			_cache[key] = build_tuft(300 + variant * 5, 7 + variant * 2, 0.55 + float(variant) * 0.25)
	return _cache[key] as ArrayMesh

static func build_tuft(seed_in: int, blades: int, height: float) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_in
	var mb: MeshBuilder = MeshBuilder.new()
	for i in range(blades):
		var a: float = TAU * float(i) / float(blades) + rng.randf_range(-0.3, 0.3)
		var base: Vector3 = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.02, 0.18)
		var lean: Vector3 = Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.12, 0.35)
		var h: float = height * rng.randf_range(0.7, 1.15)
		var wdir: Vector3 = Vector3(-sin(a), 0.0, cos(a)) * 0.05
		var cb: Color = Color(0.10, 0.26, 0.07)
		var ct: Color = Color(0.36, 0.56, 0.16).lerp(Color(0.5, 0.6, 0.2), rng.randf() * 0.5)
		var mid: Vector3 = base + lean * 0.4 + Vector3(0.0, h * 0.55, 0.0)
		var tip: Vector3 = base + lean + Vector3(0.0, h, 0.0)
		mb.add_quad_vc(base - wdir, base + wdir, mid + wdir * 0.7, mid - wdir * 0.7, cb, cb, cb.lerp(ct, 0.5), cb.lerp(ct, 0.5), Vector3.UP)
		mb.add_tri_vc(mid - wdir * 0.7, mid + wdir * 0.7, tip, cb.lerp(ct, 0.5), cb.lerp(ct, 0.5), ct, Vector3.UP)
	return mb.build(GameMaterials.grass())

# ---- banana plant (Kerala staple) ---------------------------------------------------
static func get_banana_mesh(variant: int) -> ArrayMesh:
	var key: String = "banana_%d" % variant
	if not _cache.has(key):
		_cache[key] = build_banana(400 + variant * 9)
	return _cache[key] as ArrayMesh

static func build_banana(seed_in: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_in
	var mb: MeshBuilder = MeshBuilder.new()
	var stem: PackedVector3Array = PackedVector3Array()
	var rad: PackedFloat32Array = PackedFloat32Array()
	for i in range(5):
		var t: float = float(i) / 4.0
		stem.append(Vector3(0.1 * t * t, t * 2.6, 0.0))
		rad.append(lerpf(0.20, 0.13, t))
	mb.add_tube(stem, rad, 6, Color(0.42, 0.52, 0.26), Color(0.50, 0.62, 0.32))
	var crown: Vector3 = stem[4]
	var leaves: int = 7
	for l in range(leaves):
		var yaw: float = TAU * float(l) / float(leaves) + rng.randf_range(-0.25, 0.25)
		var hdir: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = hdir.cross(Vector3.UP).normalized()
		var length: float = rng.randf_range(2.0, 2.6)
		var up_k: float = rng.randf_range(0.35, 0.75)
		var prev_l: Vector3 = Vector3.ZERO
		var prev_r: Vector3 = Vector3.ZERO
		for i in range(7):
			var t2: float = float(i) / 6.0
			var p: Vector3 = crown + hdir * (length * 0.85 * t2) + Vector3.UP * (length * up_k * t2 - length * 0.6 * t2 * t2)
			var w: float = 0.52 * pow(sin(PI * (0.04 + 0.92 * t2)), 0.8)
			var lp: Vector3 = p - side * w
			var rp: Vector3 = p + side * w
			if i > 0:
				var c0: Color = Color(0.22, 0.46, 0.12).lerp(Color(0.38, 0.62, 0.20), float(i - 1) / 6.0)
				var c1: Color = Color(0.22, 0.46, 0.12).lerp(Color(0.38, 0.62, 0.20), t2)
				mb.add_quad_vc(prev_l, prev_r, rp, lp, c0, c0, c1, c1, Vector3.UP)
			prev_l = lp
			prev_r = rp
	mb.add_sphere(Transform3D(Basis.IDENTITY, crown + Vector3(0.28, -0.35, 0.0)), Vector3(0.1, 0.2, 0.1), 3, 5, Color(0.35, 0.1, 0.22), Color(0.5, 0.15, 0.3))
	for i in range(6):
		var a: float = float(i) / 6.0 * TAU
		mb.add_sphere(Transform3D(Basis.IDENTITY, crown + Vector3(0.28 + cos(a) * 0.08, -0.65 - 0.05 * float(i % 2), sin(a) * 0.08)), Vector3(0.05, 0.13, 0.05), 3, 5, Color(0.55, 0.62, 0.15), Color(0.80, 0.78, 0.22))
	return mb.build(GameMaterials.foliage())
