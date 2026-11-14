class_name GameMaterials
extends RefCounted
## Central, cached material access. Every material used by the world comes from here,
## so swapping the look of the game means editing the .tres files in Assets/Materials.

static var _cache: Dictionary = {}
static var _low_quality: bool = false

## Grass blades sink into the ground between these distances (metres). Low quality shrinks them.
const GRASS_FADE_START: float = 36.0
const GRASS_FADE_END: float = 52.0
const GRASS_FADE_START_LOW: float = 20.0
const GRASS_FADE_END_LOW: float = 30.0

## Plain vertex-colour material (stone, houses, bushes, character).
static func vertex_color() -> StandardMaterial3D:
	if _cache.has("vc"):
		return _cache["vc"] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	m.metallic_specular = 0.2
	_cache["vc"] = m
	return m

## Emissive glow for story objects.
static func emissive(col: Color, energy: float = 1.6) -> StandardMaterial3D:
	var key: String = "em_%s_%.2f" % [col.to_html(), energy]
	if _cache.has(key):
		return _cache[key] as StandardMaterial3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col.darkened(0.5)
	m.roughness = 0.6
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m

static func _load_shader_material(key: String, path: String) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var m: ShaderMaterial = load(path) as ShaderMaterial
	if m == null:
		push_error("GameMaterials: cannot load " + path)
		m = ShaderMaterial.new()
	m.set_shader_parameter("quality", 0.0 if _low_quality else 1.0)
	_cache[key] = m
	return m

static func foliage() -> ShaderMaterial:
	return _load_shader_material("foliage", "res://Assets/Materials/foliage_material.tres")

## Same shader, calmer sway reference for short grass.
static func grass() -> ShaderMaterial:
	if _cache.has("grass"):
		return _cache["grass"] as ShaderMaterial
	var m: ShaderMaterial = foliage().duplicate() as ShaderMaterial
	m.set_shader_parameter("wind_strength", 0.16)
	m.set_shader_parameter("sway_ref_height", 0.7)
	m.set_shader_parameter("fade_start", GRASS_FADE_START)
	m.set_shader_parameter("fade_end", GRASS_FADE_END)
	_cache["grass"] = m
	return m

static func terrain() -> ShaderMaterial:
	return _load_shader_material("terrain", "res://Assets/Materials/terrain_material.tres")

static func ocean() -> ShaderMaterial:
	return _load_shader_material("ocean", "res://Assets/Materials/ocean_material.tres")

## Called by WorldManager whenever the graphics setting changes (and after the world is built).
static func apply_quality(low: bool) -> void:
	_low_quality = low
	for key: Variant in _cache.keys():
		var m: ShaderMaterial = _cache[key] as ShaderMaterial
		if m == null:
			continue
		m.set_shader_parameter("quality", 0.0 if low else 1.0)
	if _cache.has("grass"):
		var g: ShaderMaterial = _cache["grass"] as ShaderMaterial
		g.set_shader_parameter("fade_start", GRASS_FADE_START_LOW if low else GRASS_FADE_START)
		g.set_shader_parameter("fade_end", GRASS_FADE_END_LOW if low else GRASS_FADE_END)
