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
var _atmosphere_current: Dictionary = {}
var _atmosphere_target: Dictionary = {}
var _atmosphere_region: String = ""
var _fog_density_mult: float = 1.0
var _fog_density_target: float = 1.0
var _fog_detail_mult: float = 1.0
var _fog_detail_target: float = 1.0
var _apply_serial: int = 0

@onready var terrain: TerrainGenerator = $Terrain
@onready var regions_root: Node3D = $Regions
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var ocean: MeshInstance3D = $Ocean

func _ready() -> void:
	GraphicsManager.preset_applied.connect(_on_preset_applied)
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
	# World-wide trees / grass / coconuts: fills all land the hand-built regions do not dress.
	var vegetation: WorldVegetation = WorldVegetation.new()
	vegetation.name = "WorldVegetation"
	regions_root.add_child(vegetation)
	vegetation.build({"id": "world_vegetation", "center": [0.0, -30.0], "radius": 400.0})
	_apply_quality(true)
	world_built.emit()

func get_spawn_position() -> Vector3:
	var sp: Array = data.get("player_spawn", [0.0, 47.0]) as Array
	var x: float = float(sp[0])
	var z: float = float(sp[1])
	return Vector3(x, TerrainGenerator.height_at(x, z), z)

# ---- look / quality tuning (visual values are untested on device: adjust freely) -----------------
const SKY_TOP: Color = Color(0.16, 0.38, 0.76)
const SKY_HORIZON: Color = Color(0.72, 0.84, 0.93)
const GROUND_HORIZON: Color = Color(0.72, 0.82, 0.88)
const GROUND_BOTTOM: Color = Color(0.28, 0.40, 0.46)
const FOG_COLOR: Color = Color(0.72, 0.84, 0.92)
const FOG_DENSITY_HIGH: float = 0.0030
const SUN_ENERGY: float = 1.25
const SHADOW_DISTANCE_HIGH: float = 75.0
const ATMOSPHERE_PROFILES: Dictionary = {
	"coast": {
		"density": 0.0018, "height": -1.5, "height_density": 0.008,
		"sun_scatter": 0.12, "aerial": 0.22, "sky_affect": 0.18,
		"tint": Color(0.94, 0.98, 1.0, 1.0)
	},
	"forest": {
		"density": 0.0032, "height": 1.0, "height_density": 0.045,
		"sun_scatter": 0.42, "aerial": 0.16, "sky_affect": 0.22,
		"tint": Color(0.86, 0.96, 0.84, 1.0)
	},
	"village": {
		"density": 0.0020, "height": -0.5, "height_density": 0.012,
		"sun_scatter": 0.16, "aerial": 0.20, "sky_affect": 0.16,
		"tint": Color(1.0, 0.96, 0.88, 1.0)
	},
	"ancient_ruins": {
		"density": 0.0026, "height": 0.0, "height_density": 0.024,
		"sun_scatter": 0.28, "aerial": 0.26, "sky_affect": 0.20,
		"tint": Color(1.0, 0.91, 0.80, 1.0)
	},
	"ancient_cave": {
		"density": 0.0030, "height": 0.0, "height_density": 0.030,
		"sun_scatter": 0.22, "aerial": 0.28, "sky_affect": 0.22,
		"tint": Color(0.94, 0.88, 0.80, 1.0)
	},
	"default": {
		"density": 0.0022, "height": 0.0, "height_density": 0.012,
		"sun_scatter": 0.16, "aerial": 0.18, "sky_affect": 0.18,
		"tint": Color(0.96, 0.98, 1.0, 1.0)
	}
}
const ATMOSPHERE_BLEND_SPEED: float = 0.45

func _setup_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sm: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sm.sky_top_color = SKY_TOP
	sm.sky_horizon_color = SKY_HORIZON
	sm.ground_horizon_color = GROUND_HORIZON
	sm.ground_bottom_color = GROUND_BOTTOM
	sm.sky_curve = 0.16
	sm.ground_curve = 0.04
	sm.sun_angle_max = 30.0
	sm.sun_curve = 0.12
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = FOG_DENSITY_HIGH
	env.fog_height = 0.0
	env.fog_height_density = 0.012
	env.fog_sun_scatter = 0.16
	env.fog_aerial_perspective = 0.18
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY_HIGH
	env.fog_sky_affect = 0.25
	env.fog_sun_scatter = 0.15
	world_env.environment = env
	DayNightCycle.register_lighting(sun, env)
	_set_atmosphere_profile("coast")
	sun.rotation_degrees = Vector3(-38.0, -40.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.80)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = SHADOW_DISTANCE_HIGH
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.3

func _on_preset_applied(_preset: int, immediate: bool) -> void:
	_apply_quality(immediate)

## Applies the current GraphicsManager preset (values live in GraphicsManager.PRESETS).
## Not immediate = one small step per frame (materials/range -> fog/ambient -> viewport ->
## shadows -> resolution ramp) so a runtime change never causes one big hitch.
## A newer call cancels an older unfinished one (_apply_serial).
func _apply_quality(immediate: bool = false) -> void:
	if world_env == null or world_env.environment == null:
		return
	_apply_serial += 1
	var serial: int = _apply_serial
	var p: Dictionary = GraphicsManager.params()
	var env: Environment = world_env.environment
	var vp: Viewport = get_viewport()
	var low_shaders: bool = bool(p["low_shaders"])
	# 1) materials + vegetation distance
	GameMaterials.apply_quality(low_shaders)
	_apply_vegetation_range(float(p["veg_range"]), float(p["grass_range"]))
	if not immediate:
		await get_tree().process_frame
		if serial != _apply_serial:
			return
	# 2) fog / ambient / environment (fog multipliers blend smoothly in _blend_atmosphere)
	_fog_density_target = float(p["fog_density"])
	_fog_detail_target = float(p["fog_detail"])
	DayNightCycle.quality_ambient_scale = float(p["ambient"])
	env.adjustment_enabled = bool(p["adjust"])
	if immediate:
		_fog_density_mult = _fog_density_target
		_fog_detail_mult = _fog_detail_target
		_blend_atmosphere(0.0)
	if env.sky != null:
		env.sky.radiance_size = int(p["sky_radiance"]) as Sky.RadianceSize
	if not immediate:
		await get_tree().process_frame
		if serial != _apply_serial:
			return
	# 3) viewport quality
	vp.msaa_3d = int(p["msaa"]) as Viewport.MSAA
	vp.mesh_lod_threshold = float(p["mesh_lod"])
	vp.set("texture_mipmap_bias", float(p["mip_bias"])) # dynamic: harmless if a build lacks it
	if not immediate:
		await get_tree().process_frame
		if serial != _apply_serial:
			return
	# 4) shadows
	sun.shadow_enabled = bool(p["shadows"])
	sun.directional_shadow_mode = int(p["shadow_mode"]) as DirectionalLight3D.ShadowMode
	sun.directional_shadow_max_distance = float(p["shadow_distance"])
	sun.shadow_blur = float(p["shadow_blur"])
	RenderingServer.directional_shadow_atlas_set_size(int(p["shadow_atlas"]), true)
	# 5) render resolution (ramped)
	var target_scale: float = float(p["scale3d"])
	if immediate:
		vp.scaling_3d_scale = target_scale
		return
	while not is_equal_approx(vp.scaling_3d_scale, target_scale):
		await get_tree().process_frame
		if serial != _apply_serial:
			return
		vp.scaling_3d_scale = move_toward(vp.scaling_3d_scale, target_scale, 0.05)

func _apply_vegetation_range(factor: float, grass_factor: float) -> void:
	for group_name: String in ["scatter_chunks", "scatter_grass"]:
		var f: float = grass_factor if group_name == "scatter_grass" else factor
		for n: Node in get_tree().get_nodes_in_group(group_name):
			var gi: GeometryInstance3D = n as GeometryInstance3D
			if gi == null:
				continue
			gi.visibility_range_begin = float(gi.get_meta("vis_begin_high", 0.0)) * f
			gi.visibility_range_end = float(gi.get_meta("vis_end_high", 0.0)) * f

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
	_blend_atmosphere(delta)
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
		_set_atmosphere_profile(found_id)
		region_changed.emit(found_id, found_name)


func _set_atmosphere_profile(region_id: String) -> void:
	if _atmosphere_region == region_id:
		return
	_atmosphere_region = region_id
	var profile: Dictionary = ATMOSPHERE_PROFILES.get(region_id, ATMOSPHERE_PROFILES["default"])
	_atmosphere_target = profile.duplicate(true)
	if _atmosphere_current.is_empty():
		_atmosphere_current = _atmosphere_target.duplicate(true)


func _blend_atmosphere(delta: float) -> void:
	if world_env == null or world_env.environment == null or _atmosphere_target.is_empty():
		return
	if _atmosphere_current.is_empty():
		_atmosphere_current = _atmosphere_target.duplicate(true)
	var env: Environment = world_env.environment
	var weight: float = clampf(delta * ATMOSPHERE_BLEND_SPEED, 0.0, 1.0)
	var q_weight: float = clampf(delta * 1.5, 0.0, 1.0)
	_fog_density_mult = lerpf(_fog_density_mult, _fog_density_target, q_weight)
	_fog_detail_mult = lerpf(_fog_detail_mult, _fog_detail_target, q_weight)
	for key: String in ["density", "height", "height_density", "sun_scatter", "aerial", "sky_affect"]:
		var current_value: float = float(_atmosphere_current.get(key, _atmosphere_target.get(key, 0.0)))
		var target_value: float = float(_atmosphere_target.get(key, current_value))
		var next_value: float = lerpf(current_value, target_value, weight)
		_atmosphere_current[key] = next_value
	var density: float = float(_atmosphere_current.get("density", FOG_DENSITY_HIGH))
	env.fog_density = density * _fog_density_mult
	env.fog_height = float(_atmosphere_current.get("height", 0.0))
	env.fog_height_density = float(_atmosphere_current.get("height_density", 0.0)) * _fog_detail_mult
	env.fog_sun_scatter = float(_atmosphere_current.get("sun_scatter", 0.0)) * _fog_detail_mult
	env.fog_aerial_perspective = float(_atmosphere_current.get("aerial", 0.0)) * _fog_detail_mult
	env.fog_sky_affect = float(_atmosphere_current.get("sky_affect", 0.2))
	var current_tint: Color = _atmosphere_current.get("tint", Color.WHITE) as Color
	var target_tint: Color = _atmosphere_target.get("tint", current_tint) as Color
	var next_tint: Color = current_tint.lerp(target_tint, weight)
	_atmosphere_current["tint"] = next_tint
	DayNightCycle.set_atmosphere_fog_tint(next_tint)
