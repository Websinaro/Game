class_name PanthamTorch
extends Node3D
## The pantham (torch) once the player has taken it. Added under the player's ModelRoot.
## A flickering OmniLight plus a small flame. No shadows (mobile friendly).

var _light: OmniLight3D = null
var _flame: MeshInstance3D = null
var _t: float = 0.0
var _energy: float = 2.2

func _ready() -> void:
	var wood: Color = Color(0.34, 0.21, 0.10)
	var shaft: MeshBuilder = MeshBuilder.new()
	shaft.add_cylinder(Transform3D.IDENTITY, 0.05, 0.04, 0.95, 6, wood.darkened(0.2), wood)
	shaft.add_cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.95, 0.0)), 0.07, 0.11, 0.22, 7, Color(0.14, 0.09, 0.06), Color(0.26, 0.16, 0.08))
	var shaft_mi: MeshInstance3D = MeshInstance3D.new()
	shaft_mi.name = "Shaft"
	shaft_mi.mesh = shaft.build(GameMaterials.vertex_color())
	add_child(shaft_mi)
	var fb: MeshBuilder = MeshBuilder.new()
	fb.add_sphere(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.3, 0.0)), Vector3(0.12, 0.24, 0.12), 3, 6, Color(1.0, 0.5, 0.1), Color(1.0, 0.85, 0.4))
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = fb.build(GameMaterials.emissive(Color(1.0, 0.6, 0.2), 3.4))
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.name = "Light"
	_light.position = Vector3(0.0, 1.45, 0.0)
	_light.light_color = Color(1.0, 0.72, 0.42)
	_light.omni_range = GameSettings.pick_f(Tuning.CAVE_TORCH_RANGE_NORMAL, Tuning.CAVE_TORCH_RANGE_HARD)
	_energy = GameSettings.pick_f(Tuning.CAVE_TORCH_ENERGY_NORMAL, Tuning.CAVE_TORCH_ENERGY_HARD)
	_light.light_energy = _energy
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_t += delta
	var flick: float = 0.90 + 0.06 * sin(_t * 13.0) + 0.04 * sin(_t * 31.0 + 1.3)
	_light.light_energy = _energy * flick
	_flame.scale = Vector3(1.0, 0.9 + 0.2 * flick, 1.0)
