class_name Scatter
extends RefCounted
## MultiMesh helpers: chunked instancing with distance culling + shared colliders.

## Splits transforms into spatial chunks (one MultiMeshInstance3D each) so that
## whole chunks are frustum / distance culled. Use two calls with different
## meshes and ranges for LOD (near: 0..A, far: A..B).
static func add_multimesh(parent: Node3D, mesh: Mesh, xforms: Array, chunk_size: float, vis_begin: float, vis_end: float, cast_shadow: bool, base_name: String) -> void:
	var buckets: Dictionary = {}
	for item: Variant in xforms:
		var xf: Transform3D = item as Transform3D
		var key: Vector2i = Vector2i(floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size))
		if not buckets.has(key):
			buckets[key] = []
		var list: Array = buckets[key] as Array
		list.append(xf)
	for key_variant: Variant in buckets.keys():
		var list2: Array = buckets[key_variant] as Array
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list2.size()
		for i in range(list2.size()):
			mm.set_instance_transform(i, list2[i] as Transform3D)
		var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
		var k: Vector2i = key_variant as Vector2i
		inst.name = "%s_%d_%d" % [base_name, k.x, k.y]
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_begin = vis_begin
		inst.visibility_range_end = vis_end
		parent.add_child(inst)

## One StaticBody3D holding many shapes that share a single Shape3D resource.
## offset is added to each position (e.g. half the shape height).
static func add_colliders(parent: Node3D, positions: Array, shape: Shape3D, offset: Vector3, body_name: String) -> void:
	if positions.is_empty():
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	for item: Variant in positions:
		var p: Vector3 = item as Vector3
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.shape = shape
		cs.position = p + offset
		body.add_child(cs)
	parent.add_child(body)
