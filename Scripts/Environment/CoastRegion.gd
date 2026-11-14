class_name CoastRegion
extends RegionBase
## Ocean shore: beach, palms leaning over the sand, rocks, driftwood, an old fishing
## boat, sea stacks, and the first story clue (drag marks in the sand).

func _populate() -> void:
	WorldRegistry.add_exclusion(0.0, 47.0, 7.0)    # player spawn
	WorldRegistry.add_exclusion(-14.0, 47.0, 5.0)  # beach marks
	WorldRegistry.add_exclusion(26.0, 49.0, 6.0)   # boat
	WorldRegistry.add_exclusion(-38.0, 42.0, 6.0)  # beach hut
	_hero_palms()
	var palm_pts: Array[Vector2] = grid_points(-105.0, 105.0, 28.0, 45.0, 7.0, 3.0, 0.5, false)
	add_palms(filter_placeable(palm_pts, 1.3, 0.45, 3.5))
	var bush_pts: Array[Vector2] = grid_points(-100.0, 100.0, 33.0, 44.0, 5.0, 2.0, 0.5, false)
	add_bushes(filter_placeable(bush_pts, 1.5, 0.5, 3.0))
	var tuft_pts: Array[Vector2] = scatter_points(-100.0, 100.0, 30.0, 41.0, 3.2, 0.9, false)
	add_tufts(filter_placeable(tuft_pts, 1.5, 0.5, 2.5))
	var banana_pts: Array[Vector2] = grid_points(-95.0, 95.0, 30.0, 40.0, 18.0, 5.0, 0.4, false)
	add_bananas(filter_placeable(banana_pts, 1.5, 0.4, 3.5))
	var rock_pts: Array[Vector2] = grid_points(-100.0, 100.0, 49.0, 58.0, 13.0, 5.0, 0.55, false)
	add_rocks(filter_placeable(rock_pts, -0.4, 0.8, 0.0), 0.6, 1.5, false)
	_driftwood()
	_boat()
	_beach_hut()
	_sea_stacks()
	_beach_marks()

func _hero_palms() -> void:
	var packed: PackedScene = load("res://Scenes/Objects/PalmTree.tscn") as PackedScene
	var spots: Array[Vector3] = [Vector3(-9.0, 2.0, 44.0), Vector3(9.0, 3.0, 43.0), Vector3(15.0, 4.0, 51.0), Vector3(-24.0, 5.0, 50.0)]
	for s: Vector3 in spots:
		var palm: PalmTree = packed.instantiate() as PalmTree
		palm.seed_value = int(s.y) * 7 + 3
		palm.trunk_height = 9.0
		palm.trunk_lean = s.y * 0.6
		palm.position = world_pos(s.x, s.z, -0.05)
		add_child(palm)
		WorldRegistry.add_exclusion(s.x, s.z, 1.6)

func _driftwood() -> void:
	var mb: MeshBuilder = MeshBuilder.new()
	for i in range(5):
		var cx: float = rng.randf_range(-60.0, 60.0)
		var cz: float = rng.randf_range(44.0, 52.0)
		if WorldRegistry.is_excluded(cx, cz, 1.0):
			continue
		var yaw: float = rng.randf() * PI
		var dir: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var base: Vector3 = world_pos(cx, cz, 0.12)
		var pts: PackedVector3Array = PackedVector3Array()
		var rad: PackedFloat32Array = PackedFloat32Array()
		for k in range(5):
			var t: float = float(k) / 4.0 - 0.5
			pts.append(base + dir * (t * 3.0) + Vector3(0.0, sin(t * 3.0) * 0.1, 0.0))
			rad.append(0.13 - absf(t) * 0.08)
		mb.add_tube(pts, rad, 5, Color(0.50, 0.45, 0.38), Color(0.62, 0.57, 0.48))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Driftwood"
	mi.mesh = mb.build(GameMaterials.vertex_color())
	add_child(mi)

func _boat() -> void:
	var mb: MeshBuilder = MeshBuilder.new()
	var wood: Color = Color(0.42, 0.28, 0.15)
	var wood_in: Color = Color(0.55, 0.38, 0.20)
	var stations: int = 9
	var length: float = 7.0
	var rings: Array = []
	for i in range(stations):
		var t: float = float(i) / float(stations - 1)
		var z: float = (t - 0.5) * length
		var e: float = absf(t - 0.5) * 2.0
		var half_w: float = 0.65 * (1.0 - pow(e, 3.0) * 0.85)
		var gun_y: float = 0.9 + e * e * 0.9
		var keel_y: float = 0.15 + pow(e, 3.0) * 0.6
		var mid_y: float = (gun_y + keel_y) * 0.5
		rings.append(PackedVector3Array([Vector3(-half_w, gun_y, z), Vector3(-half_w * 0.85, mid_y, z), Vector3(0.0, keel_y, z), Vector3(half_w * 0.85, mid_y, z), Vector3(half_w, gun_y, z)]))
	for i in range(stations - 1):
		var a: PackedVector3Array = rings[i] as PackedVector3Array
		var b: PackedVector3Array = rings[i + 1] as PackedVector3Array
		for k in range(4):
			var mid: Vector3 = (a[k] + a[k + 1] + b[k] + b[k + 1]) * 0.25
			var hint: Vector3 = Vector3(mid.x, mid.y - 0.7, 0.0)
			mb.add_quad(a[k], a[k + 1], b[k + 1], b[k], wood, hint)
			mb.add_quad(a[k], a[k + 1], b[k + 1], b[k], wood_in, -hint)
	for z in [-1.8, 0.0, 1.8]:
		mb.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.7, float(z))), Vector3(1.25, 0.07, 0.26), wood_in.lightened(0.1))
	var boat: Node3D = Node3D.new()
	boat.name = "FishingBoat"
	boat.position = world_pos(26.0, 49.0, -0.05)
	boat.rotation.y = 0.45
	add_child(boat)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mb.build(GameMaterials.vertex_color())
	boat.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.4, 1.0, 6.6)
	cs.shape = shape
	cs.position = Vector3(0.0, 0.6, 0.0)
	body.add_child(cs)
	boat.add_child(body)

## Beach hut on the sand (your Point Reyes scan: driftwood shelter on a sand pad, reduced to
## about 26k triangles and a 2048 texture). Without the file the thatched Kerala house is used.
const HUT_GLB: String = "res://Assets/Models/beach_hut.glb"

func _beach_hut() -> void:
	var hut: Node3D = Node3D.new()
	hut.name = "BeachHut"
	# The sand pad is flat but the beach slopes: sit on the average height and tilt to the slope.
	var hx: float = -38.0
	var hz: float = 42.0
	var ring: float = 0.0
	for k in range(8):
		var ang: float = TAU * float(k) / 8.0
		ring += TerrainGenerator.height_at(hx + cos(ang) * 2.6, hz + sin(ang) * 2.6)
	var gy: float = (ring / 8.0 + TerrainGenerator.height_at(hx, hz)) * 0.5
	var nrm: Vector3 = Vector3(TerrainGenerator.height_at(hx - 1.5, hz) - TerrainGenerator.height_at(hx + 1.5, hz), 3.0, TerrainGenerator.height_at(hx, hz - 1.5) - TerrainGenerator.height_at(hx, hz + 1.5)).normalized()
	hut.position = Vector3(hx, gy - 0.22, hz)
	hut.basis = Basis(Quaternion(Vector3.UP, nrm)) * Basis(Vector3.UP, 0.25)
	add_child(hut)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var glb: ArrayMesh = GlbMesh.load_mesh(HUT_GLB, 2.8)
	var half: Vector3 = Vector3(2.4, 1.6, 2.2)
	if glb != null:
		mi.mesh = glb
		half = glb.get_aabb().size * Vector3(0.25, 0.35, 0.25)
	else:
		mi.mesh = KeralaHouse.get_mesh(1)
		mi.scale = Vector3(0.6, 0.6, 0.6)
		half = Vector3(2.4, 2.0, 2.2)
	hut.add_child(mi)
	var body: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(half.x * 2.0, half.y * 2.0, half.z * 2.0)
	cs.shape = shape
	cs.position = Vector3(0.0, half.y, 0.0)
	body.add_child(cs)
	hut.add_child(body)

func _sea_stacks() -> void:
	var spots: Array[Vector3] = [Vector3(-30.0, 8.0, 74.0), Vector3(45.0, 6.0, 82.0), Vector3(-72.0, 9.0, 90.0), Vector3(78.0, 7.0, 76.0), Vector3(5.0, 10.0, 105.0)]
	for i in range(spots.size()):
		var s: Vector3 = spots[i]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "SeaStack%d" % i
		mi.mesh = Rock.get_variant_mesh(i % 4, false)
		mi.position = world_pos(s.x, s.z, 0.5)
		mi.scale = Vector3(s.y * 0.8, s.y * 1.1, s.y * 0.8)
		mi.rotation.y = float(i)
		add_child(mi)

func _beach_marks() -> void:
	var marks: StoryInteractable = StoryInteractable.new()
	marks.name = "BeachMarks"
	marks.style = "marks"
	marks.lore_id = "beach_marks"
	marks.objective_id = "find_marks"
	marks.prompt_text = "Examine the marks"
	marks.interact_radius = 3.4
	marks.position = world_pos(-14.0, 47.0, 0.08)
	marks.rotation.y = atan2(10.0, 15.0)
	add_child(marks)
