class_name KeralaHouse
extends RefCounted
## Procedural traditional Kerala house: laterite plinth, whitewashed walls, wooden veranda
## pillars, steep gabled roof (terracotta tiles or palm thatch). Faces local +Z.

static var _cache: Dictionary = {}

static func get_mesh(variant: int) -> ArrayMesh:
	var key: String = "house_%d" % variant
	if not _cache.has(key):
		_cache[key] = build_mesh(variant)
	return _cache[key] as ArrayMesh

static func build_mesh(variant: int) -> ArrayMesh:
	var mb: MeshBuilder = MeshBuilder.new()
	var id: Basis = Basis.IDENTITY
	var laterite: Color = Color(0.58, 0.34, 0.22)
	var wall: Color = Color(0.93, 0.88, 0.76) if variant == 0 else Color(0.88, 0.78, 0.60)
	var wood: Color = Color(0.36, 0.21, 0.11)
	var thatch: bool = variant == 1
	mb.add_box(Transform3D(id, Vector3(0.0, 0.15, 0.5)), Vector3(7.8, 1.5, 7.2), laterite, laterite.lightened(0.12))
	mb.add_box(Transform3D(id, Vector3(0.0, 2.2, -0.2)), Vector3(6.4, 2.6, 5.4), wall)
	mb.add_box(Transform3D(id, Vector3(0.0, 1.9, 2.54)), Vector3(1.0, 2.0, 0.12), wood)
	mb.add_box(Transform3D(id, Vector3(0.0, 1.9, 2.5)), Vector3(1.25, 2.2, 0.08), wood.lightened(0.25))
	for sx in [-2.2, 2.2]:
		mb.add_box(Transform3D(id, Vector3(float(sx), 2.5, 2.52)), Vector3(1.0, 1.0, 0.1), wood.lightened(0.25))
		mb.add_box(Transform3D(id, Vector3(float(sx), 2.5, 2.56)), Vector3(0.8, 0.8, 0.1), Color(0.15, 0.10, 0.07))
	for px in [-3.0, -1.0, 1.0, 3.0]:
		mb.add_cylinder(Transform3D(id, Vector3(float(px), 0.9, 3.7)), 0.11, 0.1, 2.6, 7, wood, wood.lightened(0.1))
	mb.add_box(Transform3D(id, Vector3(0.0, 3.55, 3.7)), Vector3(7.0, 0.2, 0.26), wood)
	mb.add_box(Transform3D(id, Vector3(0.0, 0.225, 4.6)), Vector3(2.2, 0.45, 0.9), laterite.lightened(0.1))
	mb.add_box(Transform3D(id, Vector3(0.0, 0.675, 4.25)), Vector3(1.8, 0.45, 0.5), laterite.lightened(0.15))
	# roof
	var eave_y: float = 3.5
	var ridge_y: float = 6.4 if thatch else 5.9
	var zf: float = 4.3
	var zb: float = -3.4
	var zr: float = (zf + zb) * 0.5
	var c_a: Color = Color(0.62, 0.50, 0.28) if thatch else Color(0.62, 0.27, 0.18)
	var c_b: Color = Color(0.54, 0.42, 0.22) if thatch else Color(0.54, 0.22, 0.14)
	var strips: int = 6
	for i in range(strips):
		var x0: float = -4.1 + 8.2 * float(i) / float(strips)
		var x1: float = -4.1 + 8.2 * float(i + 1) / float(strips)
		var col: Color = c_a if i % 2 == 0 else c_b
		var hint_f: Vector3 = Vector3(0.0, 0.6, 1.0)
		var hint_b: Vector3 = Vector3(0.0, 0.6, -1.0)
		mb.add_quad(Vector3(x0, eave_y, zf), Vector3(x1, eave_y, zf), Vector3(x1, ridge_y, zr), Vector3(x0, ridge_y, zr), col, hint_f)
		mb.add_quad(Vector3(x0, eave_y, zf), Vector3(x1, eave_y, zf), Vector3(x1, ridge_y, zr), Vector3(x0, ridge_y, zr), wood.darkened(0.2), -hint_f)
		mb.add_quad(Vector3(x0, eave_y, zb), Vector3(x1, eave_y, zb), Vector3(x1, ridge_y, zr), Vector3(x0, ridge_y, zr), col, hint_b)
		mb.add_quad(Vector3(x0, eave_y, zb), Vector3(x1, eave_y, zb), Vector3(x1, ridge_y, zr), Vector3(x0, ridge_y, zr), wood.darkened(0.2), -hint_b)
	for gx in [-4.1, 4.1]:
		var dir: Vector3 = Vector3(signf(float(gx)), 0.0, 0.0)
		mb.add_tri(Vector3(float(gx), eave_y, zb), Vector3(float(gx), eave_y, zf), Vector3(float(gx), ridge_y, zr), wall.darkened(0.08), dir)
	mb.add_box(Transform3D(id, Vector3(0.0, ridge_y + 0.04, zr)), Vector3(8.5, 0.2, 0.32), c_b.darkened(0.15))
	return mb.build(GameMaterials.vertex_color())
