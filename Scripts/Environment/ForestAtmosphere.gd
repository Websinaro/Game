extends Node3D
## Lightweight forest-only atmospheric layers for the Mobile renderer.
## Mist cards and shaft cards are visual approximations, not volumetric effects.

const MIST_SHADER: Shader = preload("res://Assets/Materials/forest_mist.gdshader")
const SHAFT_SHADER: Shader = preload("res://Assets/Materials/forest_light_shafts.gdshader")

const MIST_PUFF_COUNT: int = 44

var _mist_instances: Array[MeshInstance3D] = []
var _mist_materials: Array[ShaderMaterial] = []
var _shaft_instances: Array[MeshInstance3D] = []
var _shaft_materials: Array[ShaderMaterial] = []
var _update_timer: float = 0.0
var _built: bool = false


func _ready() -> void:
	if not GraphicsManager.preset_applied.is_connected(_on_preset_applied):
		GraphicsManager.preset_applied.connect(_on_preset_applied)
	_apply_quality(GraphicsManager.current_preset)


func build(center: Vector2, radius: float) -> void:
	if _built:
		return
	_built = true

	# Soft, low-lying mist puffs scattered near the ground. They are camera-facing
	# and fade out around geometry, so they read as real haze instead of flat planes.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(center.x * 73.0 + center.y * 131.0) + 7
	var shared_mat: ShaderMaterial = ShaderMaterial.new()
	shared_mat.shader = MIST_SHADER
	shared_mat.set_shader_parameter("mist_color", Color(0.78, 0.85, 0.80, 1.0))
	shared_mat.set_shader_parameter("strength", 0.10)
	shared_mat.set_shader_parameter("drift_speed", 0.03)
	for i in range(MIST_PUFF_COUNT):
		var angle: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * radius * 0.85
		var x: float = center.x + cos(angle) * dist
		var z: float = center.y + sin(angle) * dist
		var puff: MeshInstance3D = MeshInstance3D.new()
		puff.name = "MistPuff_%02d" % i
		var quad: QuadMesh = QuadMesh.new()
		var w: float = rng.randf_range(7.0, 13.0)
		quad.size = Vector2(w, w * rng.randf_range(0.35, 0.55))
		puff.mesh = quad
		puff.position = Vector3(x, TerrainGenerator.height_at(x, z) + rng.randf_range(0.5, 2.0), z)
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.material_override = shared_mat
		puff.set_instance_shader_parameter("seed", rng.randf() * 10.0)
		add_child(puff)
		_mist_instances.append(puff)
	_mist_materials.append(shared_mat)

	# A few soft directional sheets suggest sunbeams through canopy gaps.
	# These are deliberately limited to MEDIUM/HIGH and never cast shadows.
	var shaft_offsets: Array[Vector2] = [
		Vector2(-17.0, -3.0),
		Vector2(4.0, -13.0),
		Vector2(16.0, 11.0)
	]
	for i in range(shaft_offsets.size()):
		var offset2: Vector2 = shaft_offsets[i]
		var sx: float = center.x + offset2.x
		var sz: float = center.y + offset2.y
		var beam: MeshInstance3D = MeshInstance3D.new()
		beam.name = "SunShaft_%02d" % i
		var beam_mesh: QuadMesh = QuadMesh.new()
		beam_mesh.size = Vector2(2.8, 11.0)
		beam.mesh = beam_mesh
		beam.position = Vector3(sx, TerrainGenerator.height_at(sx, sz) + 6.0, sz)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var beam_mat: ShaderMaterial = ShaderMaterial.new()
		beam_mat.shader = SHAFT_SHADER
		beam_mat.set_shader_parameter("shaft_color", Color(1.0, 0.82, 0.53, 1.0))
		beam_mat.set_shader_parameter("opacity", 0.10)
		beam.material_override = beam_mat
		add_child(beam)
		_shaft_instances.append(beam)
		_shaft_materials.append(beam_mat)

	_apply_quality(GraphicsManager.current_preset)
	_update_sun_alignment()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < 0.25:
		return
	_update_timer = 0.0
	_update_sun_alignment()


func _on_preset_applied(preset: int, _immediate: bool) -> void:
	_apply_quality(preset)


func _apply_quality(preset: int) -> void:
	var mist_count: int = 14
	var mist_strength: float = 0.08
	var shaft_count: int = 0
	var shaft_opacity: float = 0.0

	if preset == GraphicsManager.MEDIUM:
		mist_count = 28
		mist_strength = 0.09
		shaft_count = 1
		shaft_opacity = 0.055
	elif preset == GraphicsManager.HIGH:
		mist_count = 44
		mist_strength = 0.10
		shaft_count = 3
		shaft_opacity = 0.095

	for i in range(_mist_instances.size()):
		_mist_instances[i].visible = i < mist_count
	for m in _mist_materials:
		m.set_shader_parameter("strength", mist_strength)

	for j in range(_shaft_instances.size()):
		_shaft_instances[j].visible = j < shaft_count
		_shaft_materials[j].set_shader_parameter("opacity", shaft_opacity)


func _update_sun_alignment() -> void:
	if _shaft_instances.is_empty():
		return
	var hour: float = DayNightCycle.time_of_day_hours
	var daylight_progress: float = clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var sun_strength: float = 0.0
	if hour >= 6.0 and hour <= 18.0:
		sun_strength = sin(daylight_progress * PI)
	var sunrise_fade: float = _smooth01((hour - 5.5) / 1.5)
	var sunset_fade: float = 1.0 - _smooth01((hour - 17.0) / 1.5)
	sun_strength *= minf(sunrise_fade, sunset_fade)
	var azimuth: float = lerpf(-105.0, 105.0, daylight_progress)
	for i in range(_shaft_instances.size()):
		_shaft_instances[i].rotation.y = deg_to_rad(azimuth + float(i) * 7.0)
		var opacity: float = float(_shaft_materials[i].get_shader_parameter("opacity"))
		_shaft_materials[i].set_shader_parameter("sun_factor", sun_strength)
		_shaft_materials[i].set_shader_parameter("opacity", opacity)


func _smooth01(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
