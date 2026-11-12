class_name MeshBuilder
extends RefCounted
## Procedural geometry helper. Builds ONE ArrayMesh with vertex colours, so a whole
## palm tree / house / character body is a single draw call.
## Colours are given in sRGB (as you would pick them) and converted to linear.
## Triangle winding is auto-oriented from the supplied vertex normals.

var _verts: PackedVector3Array = PackedVector3Array()
var _norms: PackedVector3Array = PackedVector3Array()
var _cols: PackedColorArray = PackedColorArray()
var _uvs: PackedVector2Array = PackedVector2Array()
var _idx: PackedInt32Array = PackedInt32Array()

func vertex_count() -> int:
	return _verts.size()

func add_vertex(p: Vector3, n: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> int:
	_verts.append(p)
	_norms.append(n)
	_cols.append(c.srgb_to_linear())
	_uvs.append(uv)
	return _verts.size() - 1

func _tri(a: int, b: int, c: int) -> void:
	var geo: Vector3 = (_verts[c] - _verts[a]).cross(_verts[b] - _verts[a])
	var avg: Vector3 = _norms[a] + _norms[b] + _norms[c]
	if geo.dot(avg) >= 0.0:
		_idx.append(a)
		_idx.append(b)
		_idx.append(c)
	else:
		_idx.append(a)
		_idx.append(c)
		_idx.append(b)

## Flat shaded triangle. normal_hint decides which side is the front.
func add_tri(a: Vector3, b: Vector3, c: Vector3, col: Color, normal_hint: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	if n.dot(normal_hint) < 0.0:
		n = -n
	var i0: int = add_vertex(a, n, col)
	var i1: int = add_vertex(b, n, col)
	var i2: int = add_vertex(c, n, col)
	_tri(i0, i1, i2)

func add_tri_vc(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
	var i0: int = add_vertex(a, n, ca)
	var i1: int = add_vertex(b, n, cb)
	var i2: int = add_vertex(c, n, cc)
	_tri(i0, i1, i2)

## Flat shaded quad (a,b,c,d in loop order). normal_hint picks the front side.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, normal_hint: Vector3) -> void:
	var n: Vector3 = (c - a).cross(d - b)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	if n.dot(normal_hint) < 0.0:
		n = -n
	var i0: int = add_vertex(a, n, col)
	var i1: int = add_vertex(b, n, col)
	var i2: int = add_vertex(c, n, col)
	var i3: int = add_vertex(d, n, col)
	_tri(i0, i1, i2)
	_tri(i0, i2, i3)

## Quad with explicit normal and per-corner colours (leaves, blades).
func add_quad_vc(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color, n: Vector3) -> void:
	var i0: int = add_vertex(a, n, ca)
	var i1: int = add_vertex(b, n, cb)
	var i2: int = add_vertex(c, n, cc)
	var i3: int = add_vertex(d, n, cd)
	_tri(i0, i1, i2)
	_tri(i0, i2, i3)

func _box_face(xf: Transform3D, h: Vector3, n: Vector3, u: Vector3, v: Vector3, col: Color) -> void:
	var c: Vector3 = n * h
	var uu: Vector3 = u * h
	var vv: Vector3 = v * h
	add_quad(xf * (c - uu - vv), xf * (c + uu - vv), xf * (c + uu + vv), xf * (c - uu + vv), col, xf.basis * n)

## Box centred on xf.origin. top_col.a < 0 means "same as col".
func add_box(xf: Transform3D, size: Vector3, col: Color, top_col: Color = Color(-1.0, -1.0, -1.0, -1.0)) -> void:
	var h: Vector3 = size * 0.5
	var tc: Color = col if top_col.a < 0.0 else top_col
	_box_face(xf, h, Vector3.UP, Vector3.RIGHT, Vector3.BACK, tc)
	_box_face(xf, h, Vector3.DOWN, Vector3.RIGHT, Vector3.BACK, col)
	_box_face(xf, h, Vector3.RIGHT, Vector3.BACK, Vector3.UP, col)
	_box_face(xf, h, Vector3.LEFT, Vector3.BACK, Vector3.UP, col)
	_box_face(xf, h, Vector3.BACK, Vector3.RIGHT, Vector3.UP, col)
	_box_face(xf, h, Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, col)

func _add_cap(xf: Transform3D, y: float, radius: float, segs: int, col: Color, n_local: Vector3) -> void:
	var n: Vector3 = (xf.basis * n_local).normalized()
	var centre: int = add_vertex(xf * Vector3(0.0, y, 0.0), n, col)
	var first: int = _verts.size()
	for s in range(segs + 1):
		var a: float = TAU * float(s) / float(segs)
		add_vertex(xf * Vector3(cos(a) * radius, y, sin(a) * radius), n, col)
	for s in range(segs):
		_tri(centre, first + s, first + s + 1)

## Cylinder / cone / pyramid (segs=4) standing on xf.origin, extending along local +Y.
func add_cylinder(xf: Transform3D, r_bottom: float, r_top: float, height: float, segs: int, col_bottom: Color, col_top: Color, cap_top: bool = true, cap_bottom: bool = false) -> void:
	var base: int = _verts.size()
	for ring in range(2):
		var y: float = 0.0 if ring == 0 else height
		var r: float = r_bottom if ring == 0 else r_top
		var col: Color = col_bottom if ring == 0 else col_top
		for s in range(segs + 1):
			var a: float = TAU * float(s) / float(segs)
			var d: Vector3 = Vector3(cos(a), 0.0, sin(a))
			var nl: Vector3 = Vector3(d.x * height, r_bottom - r_top, d.z * height).normalized()
			add_vertex(xf * (d * r + Vector3(0.0, y, 0.0)), (xf.basis * nl).normalized(), col, Vector2(float(s) / float(segs), float(ring)))
	var stride: int = segs + 1
	for s in range(segs):
		var i0: int = base + s
		var i1: int = i0 + 1
		var i2: int = i0 + stride + 1
		var i3: int = i0 + stride
		_tri(i0, i1, i2)
		_tri(i0, i2, i3)
	if cap_top and r_top > 0.001:
		_add_cap(xf, height, r_top, segs, col_top, Vector3.UP)
	if cap_bottom:
		_add_cap(xf, 0.0, r_bottom, segs, col_bottom, Vector3.DOWN)

func _noise3(d: Vector3, s: float) -> float:
	return sin(d.x * 5.3 + s * 1.7) * cos(d.y * 4.1 + s * 2.3) * 0.6 + sin(d.z * 6.7 + d.x * 2.0 + s) * 0.4

## Ellipsoid with optional lumpy displacement. Colour blends bottom -> top by height.
func add_sphere(xf: Transform3D, radii: Vector3, rings: int, segs: int, col_bottom: Color, col_top: Color, jitter: float = 0.0, jitter_seed: float = 0.0) -> void:
	var base: int = _verts.size()
	for r in range(rings + 1):
		var phi: float = PI * float(r) / float(rings)
		var y: float = cos(phi)
		var rr: float = sin(phi)
		for s in range(segs + 1):
			var a: float = TAU * float(s) / float(segs)
			var d: Vector3 = Vector3(rr * cos(a), y, rr * sin(a))
			var jit: float = 1.0 + jitter * _noise3(d, jitter_seed)
			var nl: Vector3 = (d / radii).normalized()
			add_vertex(xf * (d * radii * jit), (xf.basis * nl).normalized(), col_bottom.lerp(col_top, d.y * 0.5 + 0.5), Vector2(float(s) / float(segs), float(r) / float(rings)))
	var stride: int = segs + 1
	for r in range(rings):
		for s in range(segs):
			var i0: int = base + r * stride + s
			var i1: int = i0 + 1
			var i2: int = i0 + stride + 1
			var i3: int = i0 + stride
			_tri(i0, i1, i2)
			_tri(i0, i2, i3)

## Tube along a polyline with per-point radius (trunks, branches, vines, hair).
func add_tube(path: PackedVector3Array, radii: PackedFloat32Array, segs: int, col_a: Color, col_b: Color, cap_end: bool = false) -> void:
	var n: int = path.size()
	if n < 2:
		return
	var tangents: Array[Vector3] = []
	for i in range(n):
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		if t == Vector3.ZERO:
			t = Vector3.UP
		tangents.append(t)
	var helper: Vector3 = Vector3.UP if absf(tangents[0].y) < 0.95 else Vector3.RIGHT
	var u: Vector3 = tangents[0].cross(helper).normalized()
	var base: int = _verts.size()
	for i in range(n):
		var t2: Vector3 = tangents[i]
		u = (u - t2 * u.dot(t2)).normalized()
		var v: Vector3 = t2.cross(u)
		var col: Color = col_a.lerp(col_b, float(i) / float(maxi(n - 1, 1)))
		for s in range(segs + 1):
			var a: float = TAU * float(s) / float(segs)
			var dirv: Vector3 = u * cos(a) + v * sin(a)
			add_vertex(path[i] + dirv * radii[i], dirv, col, Vector2(float(s) / float(segs), float(i) / float(maxi(n - 1, 1))))
	var stride: int = segs + 1
	for i in range(n - 1):
		for s in range(segs):
			var i0: int = base + i * stride + s
			var i1: int = i0 + 1
			var i2: int = i0 + stride + 1
			var i3: int = i0 + stride
			_tri(i0, i1, i2)
			_tri(i0, i2, i3)
	if cap_end:
		var tl: Vector3 = tangents[n - 1]
		var centre: int = add_vertex(path[n - 1], tl, col_b)
		var first: int = _verts.size()
		var last_u: Vector3 = (u - tl * u.dot(tl)).normalized()
		var last_v: Vector3 = tl.cross(last_u)
		for s in range(segs + 1):
			var a2: float = TAU * float(s) / float(segs)
			add_vertex(path[n - 1] + (last_u * cos(a2) + last_v * sin(a2)) * radii[n - 1], tl, col_b)
		for s in range(segs):
			_tri(centre, first + s, first + s + 1)

func build(material: Material = null) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	if _verts.is_empty() or _idx.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh
