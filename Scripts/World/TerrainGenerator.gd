class_name TerrainGenerator
extends Node3D
## Procedural terrain. height_at() is a pure, deterministic, STATIC function of (x, z),
## so any system (camera, scatter, regions, future tiles) can query ground height
## without needing a reference. The mesh is built per tile; blend weights are stored
## in vertex colours (R grass, G sand, B soil, A rock) and shaded by terrain.gdshader.

const CELL: float = 2.0

static var _noise: FastNoiseLite = null
static var _detail: FastNoiseLite = null
static var _ridge_z: float = -30.0
static var _gap_x: float = -45.0
static var _gap_half: float = 6.0
static var _ridge_h: float = 14.0
static var _bound_w: float = -1.0e9
static var _bound_e: float = 1.0e9
static var _bound_n: float = -1.0e9
static var _flats: PackedFloat32Array = PackedFloat32Array()   # x, z, r, height, inner (stride 5)
static var _zones: PackedFloat32Array = PackedFloat32Array()   # x, z, r, soil, rock (stride 5)
static var _path_pts: Array[PackedVector2Array] = []
static var _path_w: PackedFloat32Array = PackedFloat32Array()
static var _path_s: PackedFloat32Array = PackedFloat32Array()
static var _path_box: Array[Rect2] = []

static func _ensure_noise() -> void:
	if _noise != null:
		return
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 3
	_noise.frequency = 0.014
	_noise.seed = 1337
	_detail = FastNoiseLite.new()
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.09
	_detail.seed = 4242

static func _ramp(v: float, a: float, b: float) -> float:
	var s: float = clampf((v - a) / (b - a), 0.0, 1.0)
	return s * s * (3.0 - 2.0 * s)

## Reads terrain/regions/paths from world_regions.json data.
static func configure(data: Dictionary) -> void:
	_ensure_noise()
	_flats = PackedFloat32Array()
	_zones = PackedFloat32Array()
	_path_pts.clear()
	_path_w = PackedFloat32Array()
	_path_s = PackedFloat32Array()
	_path_box.clear()
	var t: Dictionary = data.get("terrain", {}) as Dictionary
	_ridge_z = float(t.get("ridge_z", -30.0))
	_gap_x = float(t.get("ridge_gap_x", -45.0))
	_gap_half = float(t.get("ridge_gap_half", 6.0))
	_ridge_h = float(t.get("ridge_height", 14.0))
	var b: Dictionary = t.get("bounds", {}) as Dictionary
	_bound_w = float(b.get("west", -1.0e9))
	_bound_e = float(b.get("east", 1.0e9))
	_bound_n = float(b.get("north", -1.0e9))
	for entry: Variant in (data.get("regions", []) as Array):
		var r: Dictionary = entry as Dictionary
		if not bool(r.get("enabled", false)):
			continue
		var c: Array = r.get("center", [0.0, 0.0]) as Array
		var cx: float = float(c[0])
		var cz: float = float(c[1])
		var rad: float = float(r.get("radius", 20.0))
		if r.has("flatten"):
			var f: Dictionary = r["flatten"] as Dictionary
			_flats.append_array(PackedFloat32Array([cx, cz, rad, float(f.get("height", 0.0)), float(f.get("inner", 0.6))]))
		if r.has("ground"):
			var g: Dictionary = r["ground"] as Dictionary
			_zones.append_array(PackedFloat32Array([cx, cz, rad, float(g.get("soil", 0.0)), float(g.get("rock", 0.0))]))
	for entry2: Variant in (data.get("paths", []) as Array):
		var p: Dictionary = entry2 as Dictionary
		var pv: PackedVector2Array = PackedVector2Array()
		for pt: Variant in (p.get("points", []) as Array):
			var a: Array = pt as Array
			pv.append(Vector2(float(a[0]), float(a[1])))
		var width: float = float(p.get("width", 3.0))
		_path_pts.append(pv)
		_path_w.append(width)
		_path_s.append(float(p.get("strength", 1.0)))
		var box: Rect2 = Rect2(pv[0], Vector2.ZERO)
		for q: Vector2 in pv:
			box = box.expand(q)
		_path_box.append(box.grow(width + 2.0))

static func height_at(x: float, z: float) -> float:
	_ensure_noise()
	var t: float = _ramp(z, 80.0, 40.0)
	var h: float = lerpf(-5.0, 2.0, t)
	var hill_mask: float = _ramp(z, 32.0, -8.0)
	h += _noise.get_noise_2d(x, z) * 6.0 * hill_mask
	h += _detail.get_noise_2d(x, z) * 0.35 * t
	h += _ramp(z, -30.0, -75.0) * 5.0
	# Ridge that separates the southern lands from the ancient north (one gap).
	var rz: float = (z - _ridge_z) / 6.0
	var gap: float = 1.0 - _ramp(absf(x - _gap_x), _gap_half, _gap_half + 6.0)
	h += exp(-rz * rz) * _ridge_h * (1.0 - gap) * (0.85 + 0.3 * _detail.get_noise_2d(x * 0.5, 50.0))
	# Flattened building plateaus.
	var i: int = 0
	while i < _flats.size():
		var d: float = Vector2(x - _flats[i], z - _flats[i + 1]).length()
		var w: float = 1.0 - _ramp(d, _flats[i + 2] * _flats[i + 4], _flats[i + 2])
		h = lerpf(h, _flats[i + 3], w)
		i += 5
	# Closed world edges rise into hills; open edges (removed from bounds) allow expansion.
	var rise: float = _ramp(_bound_w + 28.0 - x, 0.0, 26.0)
	rise += _ramp(x - (_bound_e - 28.0), 0.0, 26.0)
	rise += _ramp(_bound_n + 28.0 - z, 0.0, 26.0)
	h += rise * 22.0
	return maxf(h, -6.0)

static func path_weight(x: float, z: float) -> float:
	var best: float = 0.0
	var p: Vector2 = Vector2(x, z)
	for k in range(_path_pts.size()):
		if not _path_box[k].has_point(p):
			continue
		var pts: PackedVector2Array = _path_pts[k]
		var dmin: float = 1.0e9
		for j in range(pts.size() - 1):
			var cp: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[j], pts[j + 1])
			dmin = minf(dmin, cp.distance_to(p))
		var half: float = _path_w[k] * 0.5
		var w: float = (1.0 - _ramp(dmin, half, half + 1.6)) * _path_s[k]
		best = maxf(best, w)
	return best

static func distance_to_paths(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var dmin: float = 1.0e9
	for pts: PackedVector2Array in _path_pts:
		for j in range(pts.size() - 1):
			dmin = minf(dmin, Geometry2D.get_closest_point_to_segment(p, pts[j], pts[j + 1]).distance_to(p))
	return dmin

static func normal_at(x: float, z: float) -> Vector3:
	var e: float = 1.0
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()

static func splat_at(x: float, z: float, h: float, nrm: Vector3) -> Color:
	var slope: float = 1.0 - nrm.y
	var sand: float = _ramp(z + _detail.get_noise_2d(x * 1.5, z * 1.5) * 5.0, 38.0, 46.0)
	if h < 0.3:
		sand = 1.0
	var rock: float = _ramp(slope, 0.22, 0.5)
	var soil: float = path_weight(x, z)
	var i: int = 0
	while i < _zones.size():
		var d: float = Vector2(x - _zones[i], z - _zones[i + 1]).length()
		var w: float = 1.0 - _ramp(d, _zones[i + 2] * 0.55, _zones[i + 2])
		if w > 0.0:
			var patch: float = 0.5 + 0.5 * _detail.get_noise_2d(x * 0.6 + 31.0, z * 0.6)
			soil += w * _zones[i + 3] * patch
			rock += w * _zones[i + 4] * patch
		i += 5
	soil = clampf(soil, 0.0, 1.0)
	rock = clampf(rock, 0.0, 1.0)
	var keep: float = 1.0 - rock
	return Color((1.0 - sand) * (1.0 - soil) * keep, sand * keep, (1.0 - sand) * soil * keep, rock)

## Builds one terrain tile (mesh + trimesh collision) as children of this node.
func build_tile(tile_id: String, origin: Vector2, tile_size: float) -> void:
	_ensure_noise()
	var quads: int = int(round(tile_size / CELL))
	var n: int = quads + 1
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	for j in range(n):
		for i in range(n):
			heights[j * n + i] = height_at(origin.x + float(i) * CELL, origin.y + float(j) * CELL)
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	for j in range(n):
		for i in range(n):
			var x: float = origin.x + float(i) * CELL
			var z: float = origin.y + float(j) * CELL
			var h: float = heights[j * n + i]
			var hl: float = heights[j * n + maxi(i - 1, 0)]
			var hr: float = heights[j * n + mini(i + 1, n - 1)]
			var hd: float = heights[maxi(j - 1, 0) * n + i]
			var hu: float = heights[mini(j + 1, n - 1) * n + i]
			var nrm: Vector3 = Vector3(hl - hr, 2.0 * CELL, hd - hu).normalized()
			var idx: int = j * n + i
			verts[idx] = Vector3(x, h, z)
			norms[idx] = nrm
			cols[idx] = splat_at(x, z, h, nrm)
	var indices: PackedInt32Array = PackedInt32Array()
	for j in range(quads):
		for i in range(quads):
			var a: int = j * n + i
			var b: int = a + 1
			var c: int = a + n + 1
			var d: int = a + n
			# Clockwise (front-facing, normal +Y) winding for Godot.
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(a)
			indices.append(c)
			indices.append(d)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, GameMaterials.terrain())
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Tile_" + tile_id
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision_" + tile_id
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
