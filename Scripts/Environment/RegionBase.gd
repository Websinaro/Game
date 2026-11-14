class_name RegionBase
extends Node3D
## Base class for every world region (Coast, Forest, AncientRuins, Village, and all
## future phases). WorldManager calls build(data) with the region's JSON entry.
## Subclasses override _populate() and use the scatter helpers below.

var region_id: String = ""
var region_center: Vector2 = Vector2.ZERO
var region_radius: float = 30.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func build(data: Dictionary) -> void:
	region_id = str(data.get("id", ""))
	var c: Array = data.get("center", [0.0, 0.0]) as Array
	region_center = Vector2(float(c[0]), float(c[1]))
	region_radius = float(data.get("radius", 30.0))
	rng.seed = hash(region_id)
	_populate()

func _populate() -> void:
	pass

func ground(x: float, z: float) -> float:
	return TerrainGenerator.height_at(x, z)

func in_region(x: float, z: float, extra: float = 0.0) -> bool:
	return Vector2(x - region_center.x, z - region_center.y).length() <= region_radius + extra

## True when (x,z) is a sensible place for vegetation.
func is_placeable(x: float, z: float, min_height: float, max_slope: float, path_clear: float) -> bool:
	if WorldRegistry.is_excluded(x, z):
		return false
	var h: float = TerrainGenerator.height_at(x, z)
	if h < min_height:
		return false
	if 1.0 - TerrainGenerator.normal_at(x, z).y > max_slope:
		return false
	if path_clear > 0.0 and TerrainGenerator.distance_to_paths(x, z) < path_clear:
		return false
	return true

## Jittered grid of candidate points inside a rectangle, each kept with probability keep.
func grid_points(min_x: float, max_x: float, min_z: float, max_z: float, step: float, jitter: float, keep: float, circle_only: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var x: float = min_x
	while x <= max_x:
		var z: float = min_z
		while z <= max_z:
			var px: float = x + rng.randf_range(-jitter, jitter)
			var pz: float = z + rng.randf_range(-jitter, jitter)
			if rng.randf() <= keep and (not circle_only or in_region(px, pz)):
				out.append(Vector2(px, pz))
			z += step
		x += step
	return out

## Natural scatter: random "dart throwing" with a minimum distance between points (so tree crowns
## never overlap) and a slow noise field that makes clumps and clearings (so it never looks like a
## grid). clump 0 = even spread, 1 = strong patches. Deterministic (uses this region's rng).
func scatter_points(min_x: float, max_x: float, min_z: float, max_z: float, min_dist: float, clump: float, circle_only: bool) -> Array[Vector2]:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.03
	var out: Array[Vector2] = []
	var cells: Dictionary = {}
	var attempts: int = mini(int((max_x - min_x) * (max_z - min_z) / (min_dist * min_dist) * 4.0), 60000)
	for i in range(attempts):
		var x: float = rng.randf_range(min_x, max_x)
		var z: float = rng.randf_range(min_z, max_z)
		if circle_only and not in_region(x, z):
			continue
		var density: float = clampf((0.5 + 0.5 * noise.get_noise_2d(x, z)) * 1.5, 0.05, 1.0)
		if rng.randf() > lerpf(1.0, density, clump):
			continue
		var cx: int = floori(x / min_dist)
		var cz: int = floori(z / min_dist)
		var p: Vector2 = Vector2(x, z)
		var free: bool = true
		for ox in range(-1, 2):
			for oz in range(-1, 2):
				var key: Vector2i = Vector2i(cx + ox, cz + oz)
				if not cells.has(key):
					continue
				for q: Vector2 in cells[key] as Array:
					if q.distance_squared_to(p) < min_dist * min_dist:
						free = false
						break
				if not free:
					break
			if not free:
				break
		if not free:
			continue
		var home: Vector2i = Vector2i(cx, cz)
		if not cells.has(home):
			cells[home] = []
		(cells[home] as Array).append(p)
		out.append(p)
	return out

func make_xform(x: float, z: float, yaw: float, uniform_scale: float, y_scale: float, y_offset: float) -> Transform3D:
	var bas: Basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(uniform_scale, uniform_scale * y_scale, uniform_scale))
	return Transform3D(bas, Vector3(x, TerrainGenerator.height_at(x, z) + y_offset, z))

# --- reusable scatter helpers -------------------------------------------------

func add_palms(points: Array[Vector2], min_height: float = 1.2) -> void:
	var buckets: Array = [[], [], []]
	var cols: Array = []
	for p: Vector2 in points:
		var y: float = ground(p.x, p.y)
		if y < min_height:
			continue
		var v: int = rng.randi() % 3
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.25), rng.randf_range(0.9, 1.15), -0.05))
		cols.append(Vector3(p.x, y, p.y))
		WorldRegistry.add_exclusion(p.x, p.y, 1.4)
	for v in range(3):
		var xf_list: Array = buckets[v] as Array
		if xf_list.is_empty():
			continue
		Scatter.add_multimesh(self, PalmTree.get_variant_mesh(v, 1), xf_list, 48.0, 0.0, 90.0, true, "PalmsHi%d" % v)
		Scatter.add_multimesh(self, PalmTree.get_variant_mesh(v, 0), xf_list, 48.0, 90.0, 190.0, false, "PalmsLo%d" % v)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 4.0
	Scatter.add_colliders(self, cols, shape, Vector3(0.0, 2.0, 0.0), "PalmColliders")

func add_trees(points: Array[Vector2]) -> void:
	var buckets: Array = [[], [], []]
	var cols: Array = []
	for p: Vector2 in points:
		var y: float = ground(p.x, p.y)
		var v: int = rng.randi() % 3
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.85, 1.35), rng.randf_range(0.9, 1.2), -0.1))
		cols.append(Vector3(p.x, y, p.y))
		WorldRegistry.add_exclusion(p.x, p.y, 1.8)
	for v in range(3):
		var xf_list: Array = buckets[v] as Array
		if xf_list.is_empty():
			continue
		Scatter.add_multimesh(self, Vegetation.get_tree_mesh(v, 1), xf_list, 48.0, 0.0, 95.0, true, "TreesHi%d" % v)
		Scatter.add_multimesh(self, Vegetation.get_tree_mesh(v, 0), xf_list, 48.0, 95.0, 200.0, false, "TreesLo%d" % v)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 3.0
	Scatter.add_colliders(self, cols, shape, Vector3(0.0, 1.5, 0.0), "TreeColliders")

func add_bushes(points: Array[Vector2]) -> void:
	var buckets: Array = [[], [], []]
	for p: Vector2 in points:
		var v: int = rng.randi() % 3
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.4), rng.randf_range(0.8, 1.1), -0.05))
	for v in range(3):
		var xf_list: Array = buckets[v] as Array
		if not xf_list.is_empty():
			Scatter.add_multimesh(self, Vegetation.get_bush_mesh(v), xf_list, 40.0, 0.0, 110.0, false, "Bushes%d" % v)

func add_tufts(points: Array[Vector2]) -> void:
	var buckets: Array = [[], [], []]
	for p: Vector2 in points:
		var v: int = rng.randi() % 3
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.7, 1.4), 1.0, 0.0))
	for v in range(3):
		var xf_list: Array = buckets[v] as Array
		if not xf_list.is_empty():
			Scatter.add_multimesh(self, Vegetation.get_tuft_mesh(v), xf_list, 32.0, 0.0, 55.0, false, "Tufts%d" % v)

func add_bananas(points: Array[Vector2]) -> void:
	var buckets: Array = [[], []]
	for p: Vector2 in points:
		var v: int = rng.randi() % 2
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.9, 1.3), 1.0, -0.05))
		WorldRegistry.add_exclusion(p.x, p.y, 1.0)
	for v in range(2):
		var xf_list: Array = buckets[v] as Array
		if not xf_list.is_empty():
			Scatter.add_multimesh(self, Vegetation.get_banana_mesh(v), xf_list, 40.0, 0.0, 100.0, false, "Bananas%d" % v)

## Rocks: size range in metres (radius). Adds simple sphere colliders.
func add_rocks(points: Array[Vector2], size_min: float, size_max: float, mossy: bool) -> void:
	var buckets: Array = [[], [], [], []]
	var cols: Array = []
	for p: Vector2 in points:
		var v: int = rng.randi() % 4
		var s: float = rng.randf_range(size_min, size_max)
		var list: Array = buckets[v] as Array
		list.append(make_xform(p.x, p.y, rng.randf() * TAU, s, 1.0, 0.0))
		cols.append(Vector3(p.x, ground(p.x, p.y), p.y))
		WorldRegistry.add_exclusion(p.x, p.y, s * 0.9)
	for v in range(4):
		var xf_list: Array = buckets[v] as Array
		if not xf_list.is_empty():
			Scatter.add_multimesh(self, Rock.get_variant_mesh(v, mossy), xf_list, 48.0, 0.0, 130.0, true, "Rocks%d" % v)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = maxf(size_min * 0.75, 0.4)
	Scatter.add_colliders(self, cols, shape, Vector3(0.0, 0.2, 0.0), "RockColliders")

## Keeps only points that pass is_placeable().
func filter_placeable(points: Array[Vector2], min_height: float, max_slope: float, path_clear: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in points:
		if is_placeable(p.x, p.y, min_height, max_slope, path_clear):
			out.append(p)
	return out

func world_pos(x: float, z: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x, TerrainGenerator.height_at(x, z) + y_offset, z)
