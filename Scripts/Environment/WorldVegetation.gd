class_name WorldVegetation
extends RegionBase
## World-wide vegetation pass. Runs once, after every hand-built region, and fills the REST of the
## land so trees are no longer limited to the forest / coast / village circles.
## Uses your real models only: coconut_tree_low_poly.glb (palms), forest_trees.glb (broadleaf trees),
## realtime_grass.glb (grass clumps). Fallen coconuts are tiny procedural meshes lying under palms.
## Every number you may want to tweak is a constant right below.

# ---- land that gets vegetation (x = east, z = south; beach starts near z = 46) ----------------------
const LAND_MIN_X: float = -108.0
const LAND_MAX_X: float = 108.0
const LAND_MIN_Z: float = -108.0
const LAND_MAX_Z: float = 46.0

# ---- density knobs ---------------------------------------------------------------------------------
const TREE_SPACING: float = 8.5            # metres between tree trunks (bigger = fewer trees)
const TREE_CLUMP: float = 0.65             # 0 = even spread, 1 = strong groves and clearings
const PALM_COMPANION_CHANCE: float = 0.45  # chance that a palm gets 1-2 neighbours (natural groups)
const GRASS_SPACING: float = 2.0           # metres between grass clumps (bigger = less grass, faster load)
const GRASS_CLUMP: float = 0.8
const MIN_GRASS_WEIGHT: float = 0.45       # terrain must be at least this "grassy" (not sand / rock / path)
const BUSH_SPACING: float = 7.0
const COCONUTS_PER_PALM_MIN: int = 2
const COCONUTS_PER_PALM_MAX: int = 4

# ---- draw distances (metres). Low graphics scales them down automatically ----------------------------
const TREE_VIS_END: float = 130.0
const PALM_VIS_END: float = 170.0
const COCONUT_VIS_END: float = 45.0

## Areas that other regions already dress by hand: (x, z, radius). Trees skip them.
const DRESSED_VILLAGE: Vector3 = Vector3(70.0, 10.0, 31.0)
const DRESSED_RUINS: Vector3 = Vector3(-38.0, -72.0, 31.0)
const DRESSED_FOREST: Vector3 = Vector3(-45.0, -2.0, 44.0)   # only for z between -26 and 36

var _coconut_spots: Array = []

func _populate() -> void:
	_reserve_story_corridor()
	var raw: Array[Vector2] = scatter_points(LAND_MIN_X, LAND_MAX_X, LAND_MIN_Z, LAND_MAX_Z, TREE_SPACING, TREE_CLUMP, false)
	var palms: Array[Vector2] = []
	var broad: Array[Vector2] = []
	for p: Vector2 in raw:
		if _is_hand_dressed(p.x, p.y):
			continue
		if not is_placeable(p.x, p.y, 2.0, 0.40, 3.5):
			continue
		if WorldRegistry.is_excluded(p.x, p.y, 3.0):
			continue
		var coastal: float = clampf((p.y - 5.0) / 30.0, 0.0, 1.0)         # 0 far inland ... 1 near the beach
		var lowland: float = clampf((9.0 - ground(p.x, p.y)) / 7.0, 0.0, 1.0)
		var palm_chance: float = clampf(0.14 + coastal * 0.70 + lowland * 0.15, 0.0, 0.92)
		if rng.randf() < palm_chance:
			palms.append(p)
		else:
			broad.append(p)
	_add_palm_groves(palms)
	_add_broadleaf_trees(broad)
	_add_fallen_coconuts()
	_add_bushes_everywhere()
	_add_grass_everywhere()

# ---- helpers -----------------------------------------------------------------------------------------
func _is_hand_dressed(x: float, z: float) -> bool:
	if Vector2(x - DRESSED_VILLAGE.x, z - DRESSED_VILLAGE.y).length() < DRESSED_VILLAGE.z:
		return true
	if Vector2(x - DRESSED_RUINS.x, z - DRESSED_RUINS.y).length() < DRESSED_RUINS.z:
		return true
	if z > -26.0 and z < 36.0 and Vector2(x - DRESSED_FOREST.x, z - DRESSED_FOREST.y).length() < DRESSED_FOREST.z:
		return true
	return false

## Keeps the hidden path from the vine gap to the sanctum free of trunks.
func _reserve_story_corridor() -> void:
	var a: Vector2 = Vector2(-45.0, -33.0)
	var b: Vector2 = Vector2(-38.0, -58.0)
	for i in range(8):
		var q: Vector2 = a.lerp(b, float(i) / 7.0)
		WorldRegistry.add_exclusion(q.x, q.y, 4.5)

# ---- coconut palms (coconut_tree_low_poly.glb) --------------------------------------------------------
func _add_palm_groves(points: Array[Vector2]) -> void:
	var all_points: Array[Vector2] = []
	for p: Vector2 in points:
		all_points.append(p)
		if rng.randf() < PALM_COMPANION_CHANCE:
			var extra: int = 1 + rng.randi() % 2
			for k in range(extra):
				var ang: float = rng.randf() * TAU
				var dist: float = rng.randf_range(3.0, 5.5)
				var c: Vector2 = Vector2(p.x + cos(ang) * dist, p.y + sin(ang) * dist)
				if c.y > LAND_MAX_Z or _is_hand_dressed(c.x, c.y):
					continue
				if not is_placeable(c.x, c.y, 1.6, 0.40, 3.5):
					continue
				all_points.append(c)
				WorldRegistry.add_exclusion(c.x, c.y, 1.4)
	var buckets: Array = [[], [], []]
	var cols: Array = []
	for q: Vector2 in all_points:
		var y: float = ground(q.x, q.y)
		var v: int = rng.randi() % 3
		var xf: Transform3D = make_xform(q.x, q.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3), rng.randf_range(0.9, 1.15), -0.05)
		# a slight lean makes a grove look natural instead of planted in rows
		var lean_axis: Vector3 = Vector3(cos(rng.randf() * TAU), 0.0, sin(rng.randf() * TAU)).normalized()
		xf.basis = Basis(lean_axis, rng.randf_range(-0.07, 0.07)) * xf.basis
		(buckets[v] as Array).append(xf)
		cols.append(Vector3(q.x, y, q.y))
		WorldRegistry.add_exclusion(q.x, q.y, 1.4)
		# remember spots for fallen coconuts
		_remember_coconut_spot(q, y)
	for v2 in range(3):
		var list: Array = buckets[v2] as Array
		if list.is_empty():
			continue
		Scatter.add_multimesh(self, PalmTree.get_variant_mesh(v2, 1), list, 48.0, 0.0, PALM_VIS_END, true, "WorldPalms%d" % v2)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.35
	shape.height = 4.0
	Scatter.add_colliders(self, cols, shape, Vector3(0.0, 2.0, 0.0), "WorldPalmColliders")

# ---- broadleaf forest trees (forest_trees.glb) -----------------------------------------------------------
func _add_broadleaf_trees(points: Array[Vector2]) -> void:
	var buckets: Array = [[], [], []]
	var cols: Array = []
	for p: Vector2 in points:
		var v: int = rng.randi() % 3
		(buckets[v] as Array).append(make_xform(p.x, p.y, rng.randf() * TAU, rng.randf_range(0.8, 1.3), rng.randf_range(0.9, 1.2), -0.1))
		cols.append(Vector3(p.x, ground(p.x, p.y), p.y))
		WorldRegistry.add_exclusion(p.x, p.y, 1.8)
	for v2 in range(3):
		var list: Array = buckets[v2] as Array
		if list.is_empty():
			continue
		Scatter.add_multimesh(self, Vegetation.get_tree_mesh(v2, 1), list, 48.0, 0.0, TREE_VIS_END, true, "WorldTrees%d" % v2)
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.4
	shape.height = 3.0
	Scatter.add_colliders(self, cols, shape, Vector3(0.0, 1.5, 0.0), "WorldTreeColliders")

# ---- fallen coconuts lying on the ground under palms ---------------------------------------------------

func _remember_coconut_spot(p: Vector2, _y: float) -> void:
	_coconut_spots.append(p)

func _coconut_mesh() -> ArrayMesh:
	var mb: MeshBuilder = MeshBuilder.new()
	var husk_dark: Color = Color(0.30, 0.20, 0.10)
	var husk_light: Color = Color(0.46, 0.32, 0.17)
	mb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.09, 0.0)), Vector3(0.11, 0.09, 0.14), 4, 7, husk_dark, husk_light, 0.12, 3.0)
	return mb.build(GameMaterials.vertex_color())

func _add_fallen_coconuts() -> void:
	var xforms: Array = []
	for item: Variant in _coconut_spots:
		var base: Vector2 = item as Vector2
		var count: int = rng.randi_range(COCONUTS_PER_PALM_MIN, COCONUTS_PER_PALM_MAX)
		for k in range(count):
			var ang: float = rng.randf() * TAU
			var dist: float = rng.randf_range(0.9, 3.4)
			var x: float = base.x + cos(ang) * dist
			var z: float = base.y + sin(ang) * dist
			if ground(x, z) < 1.2 or z > 44.0:
				continue
			if 1.0 - TerrainGenerator.normal_at(x, z).y > 0.35:
				continue
			var s: float = rng.randf_range(0.8, 1.25)
			var bas: Basis = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s, s))
			xforms.append(Transform3D(bas, Vector3(x, ground(x, z) - 0.02, z)))
	if xforms.is_empty():
		return
	Scatter.add_multimesh(self, _coconut_mesh(), xforms, 32.0, 0.0, COCONUT_VIS_END, false, "WorldCoconuts")

# ---- undergrowth ---------------------------------------------------------------------------------------
func _add_bushes_everywhere() -> void:
	var raw: Array[Vector2] = scatter_points(LAND_MIN_X, LAND_MAX_X, LAND_MIN_Z, LAND_MAX_Z, BUSH_SPACING, 0.7, false)
	var keep: Array[Vector2] = []
	for p: Vector2 in raw:
		if _is_hand_dressed(p.x, p.y):
			continue
		if is_placeable(p.x, p.y, 1.8, 0.45, 2.5) and not WorldRegistry.is_excluded(p.x, p.y, 1.5):
			keep.append(p)
	add_bushes(keep)

## Grass clumps (cut from realtime_grass.glb) over every grassy part of the land: not on sand, rock,
## steep slopes, the mud trails or inside the village / ruins which dress themselves.
func _add_grass_everywhere() -> void:
	var raw: Array[Vector2] = scatter_points(LAND_MIN_X, LAND_MAX_X, LAND_MIN_Z, LAND_MAX_Z, GRASS_SPACING, GRASS_CLUMP, false)
	var keep: Array[Vector2] = []
	for p: Vector2 in raw:
		var x: float = p.x
		var z: float = p.y
		if Vector2(x - DRESSED_VILLAGE.x, z - DRESSED_VILLAGE.y).length() < DRESSED_VILLAGE.z - 6.0:
			continue
		if Vector2(x - DRESSED_RUINS.x, z - DRESSED_RUINS.y).length() < 21.0:
			continue
		var h: float = ground(x, z)
		if h < 1.6:
			continue
		var nrm: Vector3 = TerrainGenerator.normal_at(x, z)
		if 1.0 - nrm.y > 0.5:
			continue
		if TerrainGenerator.splat_at(x, z, h, nrm).r < MIN_GRASS_WEIGHT:
			continue
		if TerrainGenerator.distance_to_paths(x, z) < 1.5:
			continue
		keep.append(p)
	add_tufts(keep)
