class_name GlbMesh
extends RefCounted
## Turns an imported .glb into ONE ArrayMesh (node transforms baked, one surface per material,
## original materials/textures kept) so it can be used by MultiMesh and Scatter.
## Returns null when the file is missing / not imported, so callers can use their procedural fallback.
## opts: only_node (String, keep only mesh nodes whose name starts with it), skip_materials (Array of names), clip_center (Vector2 xz) + clip_radius (keep only parts
## near that point), scale_mult (float).
## target_height > 0 rescales the result to that height; the base is placed at y = 0.

static var _cache: Dictionary = {}

static func load_mesh(path: String, target_height: float, opts: Dictionary = {}) -> ArrayMesh:
	var key: String = "%s|%s|%s" % [path, str(target_height), str(opts)]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var built: ArrayMesh = _build(path, target_height, opts)
	_cache[key] = built
	return built

static func _collect(node: Node, parent_xf: Transform3D, out: Array) -> void:
	var xf: Transform3D = parent_xf
	var n3: Node3D = node as Node3D
	if n3 != null:
		xf = parent_xf * n3.transform
	var mi: MeshInstance3D = node as MeshInstance3D
	if mi != null:
		out.append([mi, xf])
	for child: Node in node.get_children():
		_collect(child, xf, out)

static func _build(path: String, target_height: float, opts: Dictionary) -> ArrayMesh:
	if not ResourceLoader.exists(path):
		push_warning("GlbMesh: '%s' not found or not imported yet - using procedural fallback." % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	var items: Array = []
	_collect(root, Transform3D.IDENTITY, items)
	var skip: Array = opts.get("skip_materials", []) as Array
	var only: String = str(opts.get("only_node", ""))
	var clip_r: float = float(opts.get("clip_radius", 0.0))
	var clip_c: Vector2 = opts.get("clip_center", Vector2.ZERO) as Vector2
	var groups: Dictionary = {}
	var vmin: Vector3 = Vector3(INF, INF, INF)
	var vmax: Vector3 = Vector3(-INF, -INF, -INF)
	for item: Variant in items:
		var pair: Array = item as Array
		var mi: MeshInstance3D = pair[0] as MeshInstance3D
		var xf: Transform3D = pair[1] as Transform3D
		var src: Mesh = mi.mesh
		if src == null:
			continue
		if only != "" and not String(mi.name).begins_with(only):
			continue
		if clip_r > 0.0:
			var c: Vector3 = xf * src.get_aabb().get_center()
			if Vector2(c.x, c.z).distance_to(clip_c) > clip_r:
				continue
		var nb: Basis = xf.basis.inverse().transposed()
		for s in range(src.get_surface_count()):
			var mat: Material = src.surface_get_material(s)
			var mname: String = mat.resource_name if mat != null else ""
			if skip.has(mname):
				continue
			var arr: Array = src.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if verts.is_empty():
				continue
			var mkey: int = mat.get_instance_id() if mat != null else 0
			if not groups.has(mkey):
				groups[mkey] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "t": PackedFloat32Array(), "i": PackedInt32Array()}
			var g: Dictionary = groups[mkey] as Dictionary
			var gv: PackedVector3Array = g["v"] as PackedVector3Array
			var gn: PackedVector3Array = g["n"] as PackedVector3Array
			var guv: PackedVector2Array = g["uv"] as PackedVector2Array
			var gt: PackedFloat32Array = g["t"] as PackedFloat32Array
			var gi: PackedInt32Array = g["i"] as PackedInt32Array
			var base: int = gv.size()
			var norms: PackedVector3Array = PackedVector3Array()
			if arr[Mesh.ARRAY_NORMAL] != null:
				norms = arr[Mesh.ARRAY_NORMAL] as PackedVector3Array
			var uvs: PackedVector2Array = PackedVector2Array()
			if arr[Mesh.ARRAY_TEX_UV] != null:
				uvs = arr[Mesh.ARRAY_TEX_UV] as PackedVector2Array
			var tans: PackedFloat32Array = PackedFloat32Array()
			if arr[Mesh.ARRAY_TANGENT] != null:
				tans = arr[Mesh.ARRAY_TANGENT] as PackedFloat32Array
			for k in range(verts.size()):
				var p: Vector3 = xf * verts[k]
				gv.append(p)
				vmin = vmin.min(p)
				vmax = vmax.max(p)
				gn.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
				guv.append(uvs[k] if k < uvs.size() else Vector2.ZERO)
				if tans.size() >= (k + 1) * 4:
					var td: Vector3 = (xf.basis * Vector3(tans[k * 4], tans[k * 4 + 1], tans[k * 4 + 2])).normalized()
					gt.append(td.x)
					gt.append(td.y)
					gt.append(td.z)
					gt.append(tans[k * 4 + 3])
				else:
					gt.append(1.0)
					gt.append(0.0)
					gt.append(0.0)
					gt.append(1.0)
			var idx: PackedInt32Array = PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null:
				idx = arr[Mesh.ARRAY_INDEX] as PackedInt32Array
			if idx.is_empty():
				for k in range(verts.size()):
					gi.append(base + k)
			else:
				for k in range(idx.size()):
					gi.append(base + idx[k])
			g["v"] = gv
			g["n"] = gn
			g["uv"] = guv
			g["t"] = gt
			g["i"] = gi
	root.free()
	if groups.is_empty():
		push_warning("GlbMesh: nothing usable in '%s' - using procedural fallback." % path)
		return null
	var size: Vector3 = vmax - vmin
	var sc: float = 1.0
	if target_height > 0.0 and size.y > 0.0001:
		sc = target_height / size.y
	sc *= float(opts.get("scale_mult", 1.0))
	var cx: float = clip_c.x
	var cz: float = clip_c.y
	if clip_r <= 0.0:
		var sx: float = 0.0
		var sz: float = 0.0
		var cnt: int = 0
		for gk: Variant in groups.keys():
			var gv2: PackedVector3Array = (groups[gk] as Dictionary)["v"] as PackedVector3Array
			for p2: Vector3 in gv2:
				if p2.y < vmin.y + size.y * 0.04:
					sx += p2.x
					sz += p2.z
					cnt += 1
		if cnt > 0:
			cx = sx / float(cnt)
			cz = sz / float(cnt)
	var origin: Vector3 = Vector3(cx, vmin.y, cz)
	var out: ArrayMesh = ArrayMesh.new()
	for gk2: Variant in groups.keys():
		var gd: Dictionary = groups[gk2] as Dictionary
		var vv: PackedVector3Array = gd["v"] as PackedVector3Array
		for k in range(vv.size()):
			vv[k] = (vv[k] - origin) * sc
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = vv
		a[Mesh.ARRAY_NORMAL] = gd["n"]
		a[Mesh.ARRAY_TEX_UV] = gd["uv"]
		a[Mesh.ARRAY_TANGENT] = gd["t"]
		a[Mesh.ARRAY_INDEX] = gd["i"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var mt: Material = gd["mat"] as Material
		if mt != null:
			out.surface_set_material(out.get_surface_count() - 1, mt)
	return out
