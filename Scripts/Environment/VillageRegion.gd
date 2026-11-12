class_name VillageRegion
extends RegionBase
## Kadalkara Village (Phase 1 placeholder): traditional houses around an open space with a
## well and lamp, mud paths (from the terrain), coconut palms and banana plants.
## Phase 3 will extend this region with paddy fields, temples and NPCs.

const HOUSES: Array[Vector3] = [
	Vector3(-15.0, -5.0, 0.0), Vector3(-11.0, 13.0, 1.0), Vector3(4.0, 17.0, 0.0),
	Vector3(15.0, 8.0, 1.0), Vector3(14.0, -10.0, 0.0), Vector3(-2.0, -16.0, 1.0)
]

func _populate() -> void:
	for h: Vector3 in HOUSES:
		_house(region_center.x + h.x, region_center.y + h.y, int(h.z))
	_well()
	_lamp()
	var palm_pts: Array[Vector2] = grid_points(region_center.x - 28.0, region_center.x + 28.0, region_center.y - 28.0, region_center.y + 28.0, 7.0, 2.5, 0.55, true)
	add_palms(filter_placeable(palm_pts, 1.5, 0.4, 3.0))
	var banana_pts: Array[Vector2] = []
	for h2: Vector3 in HOUSES:
		var hp: Vector2 = Vector2(region_center.x + h2.x, region_center.y + h2.y)
		var back: Vector2 = (hp - region_center).normalized()
		var side: Vector2 = back.orthogonal()
		banana_pts.append(hp + back * 6.5 + side * 2.5)
		banana_pts.append(hp + back * 6.8 - side * 2.0)
	add_bananas(filter_placeable(banana_pts, 1.5, 0.5, 2.0))
	var bush_pts: Array[Vector2] = grid_points(region_center.x - 28.0, region_center.x + 28.0, region_center.y - 28.0, region_center.y + 28.0, 6.0, 2.0, 0.35, true)
	add_bushes(filter_placeable(bush_pts, 1.5, 0.5, 2.5))
	var tuft_pts: Array[Vector2] = grid_points(region_center.x - 28.0, region_center.x + 28.0, region_center.y - 28.0, region_center.y + 28.0, 2.6, 1.0, 0.4, true)
	add_tufts(filter_placeable(tuft_pts, 1.5, 0.5, 2.4))

func _house(x: float, z: float, variant: int) -> void:
	var to_centre: Vector2 = region_center - Vector2(x, z)
	var node: Node3D = Node3D.new()
	node.name = "House_%d_%d" % [int(x), int(z)]
	node.position = world_pos(x, z, 0.0)
	node.rotation.y = atan2(to_centre.x, to_centre.y)
	add_child(node)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = KeralaHouse.get_mesh(variant)
	node.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(7.8, 4.6, 7.2)
	cs.shape = shape
	cs.position = Vector3(0.0, 2.3, 0.5)
	body.add_child(cs)
	node.add_child(body)
	WorldRegistry.add_exclusion(x, z, 6.2)

func _well() -> void:
	var mb: MeshBuilder = MeshBuilder.new()
	var stone: Color = Color(0.50, 0.47, 0.42)
	var id: Basis = Basis.IDENTITY
	mb.add_cylinder(Transform3D(id, Vector3.ZERO), 1.1, 1.0, 0.9, 12, stone.darkened(0.1), stone, true, false)
	mb.add_cylinder(Transform3D(id, Vector3(0.0, 0.92, 0.0)), 0.8, 0.8, 0.02, 12, Color(0.05, 0.12, 0.18), Color(0.05, 0.12, 0.18))
	mb.add_cylinder(Transform3D(id, Vector3(-0.95, 0.0, 0.0)), 0.07, 0.07, 2.3, 6, Color(0.36, 0.21, 0.11), Color(0.36, 0.21, 0.11))
	mb.add_cylinder(Transform3D(id, Vector3(0.95, 0.0, 0.0)), 0.07, 0.07, 2.3, 6, Color(0.36, 0.21, 0.11), Color(0.36, 0.21, 0.11))
	mb.add_cylinder(Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0.0, 2.2, 0.0)), 1.8, 0.1, 0.7, 4, Color(0.54, 0.22, 0.14), Color(0.62, 0.27, 0.18))
	var node: Node3D = Node3D.new()
	node.name = "Well"
	node.position = world_pos(region_center.x, region_center.y, 0.0)
	add_child(node)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mb.build(GameMaterials.vertex_color())
	node.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.1
	shape.height = 0.9
	cs.shape = shape
	cs.position = Vector3(0.0, 0.45, 0.0)
	body.add_child(cs)
	node.add_child(body)
	WorldRegistry.add_exclusion(region_center.x, region_center.y, 3.0)

## Brass standing lamp (nilavilakku), a Kerala household icon.
func _lamp() -> void:
	var brass: Color = Color(0.80, 0.58, 0.18)
	var mb: MeshBuilder = MeshBuilder.new()
	var id: Basis = Basis.IDENTITY
	mb.add_cylinder(Transform3D(id, Vector3.ZERO), 0.35, 0.2, 0.3, 10, brass.darkened(0.2), brass)
	mb.add_cylinder(Transform3D(id, Vector3(0.0, 0.3, 0.0)), 0.07, 0.06, 1.0, 8, brass, brass)
	for i in range(3):
		mb.add_cylinder(Transform3D(id, Vector3(0.0, 1.3 + float(i) * 0.12, 0.0)), 0.32 - float(i) * 0.06, 0.08, 0.1, 10, brass.darkened(0.1), brass.lightened(0.1))
	var fb: MeshBuilder = MeshBuilder.new()
	fb.add_sphere(Transform3D(id, Vector3(0.0, 1.8, 0.0)), Vector3(0.06, 0.1, 0.06), 3, 5, Color(1.0, 0.6, 0.2), Color(1.0, 0.85, 0.5))
	var node: Node3D = Node3D.new()
	node.name = "BrassLamp"
	node.position = world_pos(region_center.x + 5.0, region_center.y + 4.0, 0.0)
	add_child(node)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mb.build(GameMaterials.vertex_color())
	node.add_child(mi)
	var fmi: MeshInstance3D = MeshInstance3D.new()
	fmi.mesh = fb.build(GameMaterials.emissive(Color(1.0, 0.6, 0.2), 3.0))
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(fmi)
	WorldRegistry.add_exclusion(region_center.x + 5.0, region_center.y + 4.0, 1.2)
