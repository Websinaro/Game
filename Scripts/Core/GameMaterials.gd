class_name GameMaterials
extends RefCounted
## Central, cached material access. Every material used by the world comes from here,
## so swapping the look of the game means editing the .tres files in Assets/Materials.

static var _cache: Dictionary = {}

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
	_cache["grass"] = m
	return m

static func terrain() -> ShaderMaterial:
	return _load_shader_material("terrain", "res://Assets/Materials/terrain_material.tres")

static func ocean() -> ShaderMaterial:
	return _load_shader_material("ocean", "res://Assets/Materials/ocean_material.tres")
