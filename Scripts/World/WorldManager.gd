class_name WorldManager
extends Node3D
## Builds the world from res://Data/world_regions.json: environment, ocean, terrain tiles,
## boundary walls and every ENABLED region scene. Adding a future region = adding a JSON
## entry + a scene whose root script extends RegionBase. Nothing here needs rewriting.

signal world_built
signal region_changed(region_id: String, region_name: String)

@export var auto_build: bool = true
@export var regions_file: String = "res://Data/world_regions.json"

var data: Dictionary = {}
var _tracked: Node3D = null
var _current_region: String = ""
var _check_timer: float = 0.0

@onready var terrain: TerrainGenerator = $Terrain
@onready var regions_root: Node3D = $Regions
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var ocean: MeshInstance3D = $Ocean

func _ready() -> void:
	if auto_build:
		build_world()

func set_tracked(node: Node3D) -> void:
	_tracked = node

func build_world() -> void:
	WorldRegistry.clear()
	data = GameData.load_json(regions_file)
	TerrainGenerator.configure(data)
	_setup_environment()
	ocean.material_override = GameMaterials.ocean()
	for tile_entry: Variant in (data.get("terrain_tiles", []) as Array):
		var tile: Dictionary = tile_entry as Dictionary
		var o: Array = tile.get("origin", [0.0, 0.0]) as Array
		terrain.build_tile(str(tile.get("id", "tile")), Vector2(float(o[0]), float(o[1])), float(tile.get("size", 240.0)))
	_build_boundaries()
	for entry: Variant in (data.get("regions", []) as Array):
		var r: Dictionary = entry as Dictionary
		if not bool(r.get("enabled", false)):
			continue
		var scene_path: String = str(r.get("scene", ""))
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			push_warning("WorldManager: region scene missing: " + scene_path)
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		var node: Node = packed.instantiate()
		regions_root.add_child(node)
		if node is RegionBase:
			(node as RegionBase).build(r)
	world_built.emit()

func get_spawn_position() -> Vector3:
	var sp: Array = data.get("player_spawn", [0.0, 47.0]) as Array
	var x: float = float(sp[0])
	var z: float = float(sp[1])
	return Vector3(x, TerrainGenerator.height_at(x, z), z)

func _setup_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.45, 0.80)
	sm.sky_horizon_color = Color(0.74, 0.86, 0.93)
	sm.ground_horizon_color = Color(0.74, 0.86, 0.93)
	sm.ground_bottom_color = Color(0.30, 0.42, 0.48)
	sm.sky_curve = 0.18
	sm.sun_angle_max = 25.0
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.86, 0.93)
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.25
	world_env.environment = env
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_normal_bias = 1.2

## Pause-menu quality switch: shadows + 3D resolution.
func set_low_quality(low: bool) -> void:
	sun.shadow_enabled = not low
	get_viewport().scaling_3d_scale = 0.7 if low else 1.0

func _build_boundaries() -> void:
	var t: Dictionary = data.get("terrain", {}) as Dictionary
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Boundaries"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var sea_z: float = float(t.get("sea_wall_z", 61.0))
	_add_wall(body, Vector3(0.0, 0.0, sea_z + 2.0), Vector3(1000.0, 60.0, 4.0))
	var b: Dictionary = t.get("bounds", {}) as Dictionary
	if b.has("west"):
		_add_wall(body, Vector3(float(b["west"]) + 8.0 - 2.0, 0.0, 0.0), Vector3(4.0, 120.0, 1000.0))
	if b.has("east"):
		_add_wall(body, Vector3(float(b["east"]) - 8.0 + 2.0, 0.0, 0.0), Vector3(4.0, 120.0, 1000.0))
	if b.has("north"):
		_add_wall(body, Vector3(0.0, 0.0, float(b["north"]) + 8.0 - 2.0), Vector3(1000.0, 120.0, 4.0))

func _add_wall(body: StaticBody3D, centre: Vector3, size: Vector3) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = centre
	body.add_child(cs)

func _process(delta: float) -> void:
	if _tracked == null:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.5
	var p: Vector3 = _tracked.global_position
	var found_id: String = ""
	var found_name: String = ""
	var best: float = 1.0e9
	for entry: Variant in (data.get("regions", []) as Array):
		var r: Dictionary = entry as Dictionary
		if not bool(r.get("enabled", false)):
			continue
		var c: Array = r.get("center", [0.0, 0.0]) as Array
		var d: float = Vector2(p.x - float(c[0]), p.z - float(c[1])).length()
		var rad: float = float(r.get("radius", 20.0))
		if d < rad and d / rad < best:
			best = d / rad
			found_id = str(r.get("id", ""))
			found_name = str(r.get("name", ""))
	if found_id != "" and found_id != _current_region:
		_current_region = found_id
		region_changed.emit(found_id, found_name)
