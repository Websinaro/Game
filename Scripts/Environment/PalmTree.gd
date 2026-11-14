class_name PalmTree
extends Node3D
## Procedural coconut palm: curved ringed trunk, individual arching fronds with visible
## leaflets, and a coconut cluster. One mesh = one draw call. Two LOD levels.
## PalmTree.tscn is the reusable single-tree scene; large groves use MultiMesh
## (see RegionBase.add_palms) with PalmTree.get_variant_mesh().

@export var seed_value: int = 1
@export var trunk_height: float = 8.0
@export var trunk_lean: float = 1.4
@export var frond_count: int = 11
@export var with_collision: bool = true

const TRUNK_DARK: Color = Color(0.33, 0.25, 0.17)
const TRUNK_LIGHT: Color = Color(0.50, 0.41, 0.30)
const FROND_BASE: Color = Color(0.10, 0.30, 0.08)
const FROND_TIP: Color = Color(0.34, 0.56, 0.14)
const FROND_OLD: Color = Color(0.45, 0.50, 0.16)
const RIB: Color = Color(0.35, 0.42, 0.16)
const NUT_GREEN: Color = Color(0.40, 0.50, 0.14)
const NUT_BROWN: Color = Color(0.42, 0.28, 0.10)

## Real coconut palm model (low poly, textured). If it is missing the procedural palm is used.
const PALM_GLB: String = "res://Assets/Models/coconut_tree_low_poly.glb"

static var _cache: Dictionary = {}

static func get_variant_mesh(variant: int, detail: int) -> ArrayMesh:
	var key: String = "palm_%d_%d" % [variant, detail]
	if not _cache.has(key):
		var glb: ArrayMesh = GlbMesh.load_mesh(PALM_GLB, 9.0 + float(variant) * 1.2)
		if glb != null:
			_cache[key] = glb
		else:
			_cache[key] = build_mesh(11 + variant * 31, 7.0 + float(variant) * 1.2, 1.0 + float(variant) * 0.5, 10 + variant, detail)
	return _cache[key] as ArrayMesh

## detail: 1 = full (leaflets, coconuts), 0 = distant LOD.
static func build_mesh(seed_in: int, height: float, lean: float, fronds: int, detail: int) -> ArrayMesh:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_in
	var mb: MeshBuilder = MeshBuilder.new()
	var lean_angle: float = rng.randf() * TAU
	var top: Vector3 = Vector3(cos(lean_angle) * lean, height, sin(lean_angle) * lean)
	var side_dir: Vector3 = Vector3(-sin(lean_angle), 0.0, cos(lean_angle))
	var p0: Vector3 = Vector3(0.0, -0.3, 0.0)
	var p1: Vector3 = Vector3(top.x * 0.1, height * 0.55, top.z * 0.1) + side_dir * lean * rng.randf_range(-0.3, 0.3)
	var ring_count: int = 18 if detail > 0 else 8
	var path: PackedVector3Array = PackedVector3Array()
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i in range(ring_count):
		var t: float = float(i) / float(ring_count - 1)
		var omt: float = 1.0 - t
		path.append(p0 * (omt * omt) + p1 * (2.0 * omt * t) + top * (t * t))
		var r: float = lerpf(0.30, 0.15, t)
		if i == 0:
			r *= 1.4
		elif i % 2 == 1 and detail > 0:
			r *= 1.07
		radii.append(r)
	mb.add_tube(path, radii, 7 if detail > 0 else 5, TRUNK_DARK, TRUNK_LIGHT)
	var crown: Vector3 = top + Vector3(0.0, 0.1, 0.0)
	mb.add_sphere(Transform3D(Basis.IDENTITY, crown), Vector3(0.3, 0.22, 0.3), 3, 6, NUT_BROWN, NUT_GREEN)
	for f in range(fronds):
		var yaw: float = TAU * float(f) / float(fronds) + rng.randf_range(-0.2, 0.2)
		var elev: float = (0.75 if f % 2 == 0 else 0.25) + rng.randf_range(-0.15, 0.15)
		var length: float = rng.randf_range(3.4, 4.5)
		var droop: float = rng.randf_range(0.65, 0.95)
		var old: bool = rng.randf() < 0.15
		_add_frond(mb, crown + Vector3(0.0, 0.1, 0.0), yaw, elev, length, droop, detail, old)
	if detail > 0:
		var nuts: int = rng.randi_range(5, 8)
		for i in range(nuts):
			var a: float = rng.randf() * TAU
			var pn: Vector3 = crown + Vector3(cos(a) * 0.30, -0.28 - rng.randf() * 0.12, sin(a) * 0.30)
			var colr: Color = NUT_GREEN if rng.randf() < 0.6 else NUT_BROWN
			mb.add_sphere(Transform3D(Basis.IDENTITY, pn), Vector3(0.17, 0.2, 0.17), 4, 6, colr.darkened(0.15), colr)
	return mb.build(GameMaterials.foliage())

static func _frond_pos(origin: Vector3, hdir: Vector3, length: float, elev: float, droop: float, t: float) -> Vector3:
	return origin + hdir * (length * cos(elev) * t) + Vector3.UP * (length * sin(elev) * t - droop * length * t * t)

static func _add_frond(mb: MeshBuilder, origin: Vector3, yaw: float, elev: float, length: float, droop: float, detail: int, old: bool) -> void:
	var hdir: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
	var c_base: Color = FROND_OLD.darkened(0.2) if old else FROND_BASE
	var c_tip: Color = FROND_OLD if old else FROND_TIP
	if detail <= 0:
		var widths: Array[float] = [0.5, 0.8, 0.55, 0.05]
		var prev_l: Vector3 = Vector3.ZERO
		var prev_r: Vector3 = Vector3.ZERO
		for i in range(4):
			var t: float = float(i) / 3.0
			var p: Vector3 = _frond_pos(origin, hdir, length, elev, droop, t)
			var side: Vector3 = hdir.cross(Vector3.UP).normalized()
			var l: Vector3 = p - side * widths[i]
			var r: Vector3 = p + side * widths[i]
			if i > 0:
				var c0: Color = c_base.lerp(c_tip, float(i - 1) / 3.0)
				var c1: Color = c_base.lerp(c_tip, t)
				mb.add_quad_vc(prev_l, prev_r, r, l, c0, c0, c1, c1, Vector3.UP)
			prev_l = l
			prev_r = r
		return
	var steps: int = 8
	var pts: PackedVector3Array = PackedVector3Array()
	var rad: PackedFloat32Array = PackedFloat32Array()
	for i in range(steps + 1):
		var t2: float = float(i) / float(steps)
		pts.append(_frond_pos(origin, hdir, length, elev, droop, t2))
		rad.append(lerpf(0.05, 0.012, t2))
	mb.add_tube(pts, rad, 3, RIB, RIB.lightened(0.15))
	var pairs: int = 12
	for k in range(pairs):
		var tk: float = 0.10 + 0.88 * float(k) / float(pairs - 1)
		var pp: Vector3 = _frond_pos(origin, hdir, length, elev, droop, tk)
		var ahead: Vector3 = _frond_pos(origin, hdir, length, elev, droop, minf(tk + 0.03, 1.0))
		var behind: Vector3 = _frond_pos(origin, hdir, length, elev, droop, maxf(tk - 0.03, 0.0))
		var tang: Vector3 = (ahead - behind).normalized()
		var side2: Vector3 = tang.cross(Vector3.UP)
		if side2.length_squared() < 0.0001:
			continue
		side2 = side2.normalized()
		var ll: float = 0.30 + 0.95 * sin(PI * tk) * (length / 4.0)
		var cb: Color = c_base.lerp(c_tip, tk * 0.5)
		var ct: Color = c_base.lerp(c_tip, 0.4 + tk * 0.6)
		for si in range(2):
			var sgn: float = -1.0 if si == 0 else 1.0
			var dirl: Vector3 = (side2 * sgn * 0.85 + Vector3.DOWN * 0.55 + tang * 0.30).normalized()
			var tip: Vector3 = pp + dirl * ll + Vector3.DOWN * (ll * 0.18)
			var w: float = 0.20
			var a0: Vector3 = pp - tang * (w * 0.5)
			var a1: Vector3 = pp + tang * (w * 0.5)
			var b0: Vector3 = tip - tang * (w * 0.12)
			var b1: Vector3 = tip + tang * (w * 0.12)
			var n: Vector3 = (a1 - a0).cross(b0 - a0).normalized()
			if n.y < 0.0:
				n = -n
			mb.add_quad_vc(a0, a1, b1, b0, cb, cb, ct, ct, n)

func _ready() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	var glb: ArrayMesh = GlbMesh.load_mesh(PALM_GLB, trunk_height + 1.0)
	mi.mesh = glb if glb != null else build_mesh(seed_value, trunk_height, trunk_lean, frond_count, 1)
	add_child(mi)
	if with_collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		var cs: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 0.35
		shape.height = 4.0
		cs.shape = shape
		cs.position = Vector3(0.0, 2.0, 0.0)
		body.add_child(cs)
		add_child(body)
